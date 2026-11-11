"""Xuất art từ file .aseprite (art_source/) ra PNG + SpriteFrames cho Godot (assets/).

Chỉ NGƯỜI VẼ cần chạy (cần Aseprite + Python 3). Người khác chỉ cần clone repo là chạy game.

    python tools/export_art.py                       # xuất tất cả
    python tools/export_art.py art_source/maps/yard.aseprite   # xuất 1 file

Quy tắc theo thư mục:
    art_source/maps/<map>.aseprite            -> assets/maps/<map>/<layer>.png        (mỗi layer 1 ảnh)
    art_source/characters/<id>/<ten>.aseprite -> assets/characters/<id>/<ten>.png     (spritesheet ngang)
                                                + assets/characters/<id>/<ten>_frames.tres (SpriteFrames, mỗi tag 1 animation)
    art_source/ui/<ten>.aseprite              -> assets/ui/<ten>.png                  (frame đầu)
    art_source/palette/…                      -> không xuất

Đường dẫn Aseprite: biến môi trường ASEPRITE, hoặc mặc định bản Steam.
"""
import json, os, re, shutil, subprocess, sys, tempfile

# Cửa sổ dòng lệnh Windows mặc định không in được tiếng Việt
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "art_source")
DST = os.path.join(ROOT, "assets")
ASEPRITE = os.environ.get("ASEPRITE", r"C:\Program Files (x86)\Steam\steamapps\common\Aseprite\Aseprite.exe")


def ase(*args):
    """Chạy Aseprite ở chế độ batch. Bỏ các dòng lỗi Lua do extension (vd PixelLab) in ra."""
    out = subprocess.run([ASEPRITE, "-b", *args], capture_output=True, text=True, encoding="utf-8", errors="replace")
    return [l for l in out.stdout.splitlines() if ".lua:" not in l]


def safe(name):
    """Tên layer -> tên file: bỏ khoảng trắng / ký tự lạ."""
    return re.sub(r"[^A-Za-z0-9_\-]", "_", name.strip())


def res_path(abs_path):
    return "res://" + os.path.relpath(abs_path, ROOT).replace("\\", "/")


def sync_dir(tmp, out_dir, ext):
    """Chép file mới từ tmp sang out_dir; xoá file cũ không còn (kèm .import). Giữ .import của file còn lại (giữ uid)."""
    os.makedirs(out_dir, exist_ok=True)
    new = {f for f in os.listdir(tmp) if f.endswith(ext)}
    for f in os.listdir(out_dir):
        if f.endswith(ext) and f not in new:
            os.remove(os.path.join(out_dir, f))
            if os.path.exists(os.path.join(out_dir, f + ".import")):
                os.remove(os.path.join(out_dir, f + ".import"))
            print(f"    xoá {f} (layer không còn)")
    for f in new:
        shutil.copyfile(os.path.join(tmp, f), os.path.join(out_dir, f))
    return sorted(new)


# ---------------------------------------------------------------- map

def export_map(src):
    name = os.path.splitext(os.path.basename(src))[0]
    out_dir = os.path.join(DST, "maps", name)
    with tempfile.TemporaryDirectory() as tmp:
        # Danh sách layer (gồm cả layer ẩn, layer trong nhóm)
        leaves = []
        for line in ase("--all-layers", "--list-layer-hierarchy", src):
            if line.strip() and not line.rstrip().endswith("/"):
                leaves.append(line.strip())
        # Mỗi tên layer 1 ảnh; layer trùng tên được gộp chung 1 ảnh
        for layer in dict.fromkeys(leaves):
            ase("--all-layers", "--layer", layer, src, "--save-as", os.path.join(tmp, safe(layer) + ".png"))
        files = sync_dir(tmp, out_dir, ".png")
    dup = {l for l in leaves if leaves.count(l) > 1}
    print(f"  map {name}: {len(files)} layer -> assets/maps/{name}/" + (f"  (gộp layer trùng tên: {sorted(dup)})" if dup else ""))


# ---------------------------------------------------------------- nhân vật

def export_character(src):
    rel = os.path.relpath(os.path.dirname(src), os.path.join(SRC, "characters"))
    name = os.path.splitext(os.path.basename(src))[0]
    out_dir = os.path.join(DST, "characters", rel)
    os.makedirs(out_dir, exist_ok=True)
    png = os.path.join(out_dir, name + ".png")
    with tempfile.TemporaryDirectory() as tmp:
        data_json = os.path.join(tmp, "data.json")
        ase("--all-layers", src, "--sheet-type", "horizontal", "--sheet", png,
            "--data", data_json, "--format", "json-array", "--list-tags")
        data = json.load(open(data_json, encoding="utf-8"))
    frames = data["frames"]
    tags = data["meta"].get("frameTags") or [{"name": "Idle", "from": 0, "to": len(frames) - 1, "direction": "forward"}]

    # SpriteFrames: speed 10 fps, duration = ms/100  ->  đúng thời gian từng frame như trong Aseprite
    lines = ['[gd_resource type="SpriteFrames" format=3]', "",
             f'[ext_resource type="Texture2D" path="{res_path(png)}" id="1_sheet"]', ""]
    for i, f in enumerate(frames):
        r = f["frame"]
        lines += [f'[sub_resource type="AtlasTexture" id="f{i}"]', 'atlas = ExtResource("1_sheet")',
                  f'region = Rect2({r["x"]}, {r["y"]}, {r["w"]}, {r["h"]})', ""]
    anims = []
    for t in tags:
        idx = list(range(t["from"], t["to"] + 1))
        if t.get("direction") == "reverse":
            idx.reverse()
        elif t.get("direction") == "pingpong":
            idx = idx + idx[-2:0:-1]
        fr = ", ".join('{\n"duration": %s,\n"texture": SubResource("f%d")\n}' % (frames[i]["duration"] / 100.0, i) for i in idx)
        anims.append('{\n"frames": [%s],\n"loop": true,\n"name": &"%s",\n"speed": 10.0\n}' % (fr, t["name"]))
    lines += ["[resource]", "animations = [" + ", ".join(anims) + "]", ""]
    open(os.path.join(out_dir, name + "_frames.tres"), "w", encoding="utf-8", newline="\n").write("\n".join(lines))
    print(f"  nhân vật {rel}/{name}: {len(frames)} frame, animation {[t['name'] for t in tags]}")


# ---------------------------------------------------------------- UI

def export_ui(src):
    name = os.path.splitext(os.path.basename(src))[0]
    out_dir = os.path.join(DST, "ui")
    os.makedirs(out_dir, exist_ok=True)
    ase("--all-layers", src, "--frame-range", "0,0", "--save-as", os.path.join(out_dir, name + ".png"))
    print(f"  ui {name}")


def export(src):
    src = os.path.abspath(src)
    kind = os.path.relpath(src, SRC).replace("\\", "/").split("/")[0]
    {"maps": export_map, "characters": export_character, "ui": export_ui}.get(kind, lambda s: None)(src)


def main():
    if not os.path.exists(ASEPRITE):
        sys.exit(f"Không tìm thấy Aseprite: {ASEPRITE}\nĐặt biến môi trường ASEPRITE trỏ tới Aseprite.exe")
    targets = sys.argv[1:] or [os.path.join(dp, f) for dp, _, fs in os.walk(SRC) for f in fs if f.endswith((".aseprite", ".ase"))]
    for t in sorted(targets):
        export(t)
    print("Xong. Mở Godot để import PNG mới, rồi commit cả art_source/ lẫn assets/.")


if __name__ == "__main__":
    main()
