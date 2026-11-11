# Hệ thống cốt lõi – Mùa Gió Về

Mô tả đầy đủ **12 hệ thống cốt lõi**: mục đích, thành phần, dữ liệu, API, signal, luồng chạy, cách dùng khi làm nội dung, điều kiện "xong".

- Kiến trúc, thư mục, quy ước: [KIEN_TRUC.md](KIEN_TRUC.md)
- Thứ tự làm, phân công: [KE_HOACH.md](KE_HOACH.md)

**Ký hiệu:** ✅ xong · 🟡 một phần · ⬜ chưa làm

| # | Hệ thống | Trạng thái | Phụ trách |
|---|---|---|---|
| 1 | [Player & Camera](#1-player--camera) | ✅ | Trí |
| 2 | [World & Chuyển map](#2-world--chuyển-map) | ✅ đổi map, cửa, mép map | Trí |
| 3 | [World State – trạng thái thế giới](#3-world-state--trạng-thái-thế-giới) | 🟡 | Trí |
| 4 | [Lưu & Tải game](#4-lưu--tải-game) | ⬜ | Trí |
| 5 | [Tương tác](#5-tương-tác) | 🟡 | Trí |
| 6 | [NPC & Hội thoại](#6-npc--hội-thoại) | ✅ khung | Uyên |
| 7 | [Nhiệm vụ & Chương](#7-nhiệm-vụ--chương) | ⬜ | Uyên |
| 8 | [Cutscene](#8-cutscene) | ⬜ | Uyên |
| 9 | [Túi đồ & Vật phẩm](#9-túi-đồ--vật-phẩm) | ⬜ | Tuấn |
| 10 | [Khung Minigame](#10-khung-minigame) | ⬜ | Tuấn |
| 11 | [Bạn đồng hành – Bé Na](#11-bạn-đồng-hành--bé-na) | 🟡 An đi theo (chưa có lịch, "Nhờ Na") | Tuấn |
| 12 | [Giao diện & Âm thanh](#12-giao-diện--âm-thanh) | 🟡 có hộp thoại | Tuấn |

Cách đọc mỗi mục:
- **Dùng thế nào** = phần người làm nội dung cần biết, không cần đọc code.
- **Xong khi** = điều kiện để đánh dấu ✅.

---

## 1. Player & Camera

**Mục đích:** Minh đi lại trong map, chọn đối tượng để tương tác, camera đi theo trong giới hạn map.

**Thành phần**

| File | Vai trò |
|---|---|
| `gameplay/player/player.tscn` | `CharacterBody2D` + `AnimatedSprite2D` (Idle/Walk/Run: `assets/characters/minh/minh_regular_frames.tres`) + `CollisionShape2D` + `InteractionArea` + `Camera2D` + `InteractionPrompt` |
| `gameplay/player/player.gd` | Di chuyển, animation, chọn vật tương tác, khoá điều khiển |
| `data/npcs/minh.tres` | Tên + màu khung thoại của Minh |

**Hành vi**
- A/D (←/→, cần analog) đi, giữ Shift (RB) chạy. Có gia tốc / giảm tốc. Không nhảy (Space dành cho "Nhờ Na").
- Gốc toạ độ ở giữa thân, **chân cách gốc 56 px**.
- `InteractionArea` (bán kính 48) quét layer 4 *interactable*; mỗi frame chọn vật **gần nhất**, phát `interactable_changed(target)`; bấm E → `EventBus.interacted` + `target.interact(self)`.
- Camera: zoom 3.5, giới hạn do map đặt (`GameMap.place_player`).

**Cần bổ sung ⬜**
- [ ] **Khoá theo lý do** thay cho một biến `can_move`: `lock(reason)` / `unlock(reason)`, Minh chỉ đi được khi không còn lý do nào (`"dialogue"`, `"cutscene"`, `"minigame"`, `"menu"`, `"transition"`). Tránh lỗi hội thoại kết thúc giữa cutscene làm Minh đi được.
- [ ] `face(direction)` cho cutscene; `walk_to(x)` tự đi tới điểm (dùng cho cutscene).
- [ ] Phát `footstep` theo frame animation Walk/Run (cho âm thanh bước chân).
- [ ] Trang phục: `set_outfit("regular" | "uniform")` đổi SpriteFrames (cho Chương 0).

**API**
```gdscript
player.lock("cutscene") / player.unlock("cutscene") / player.is_locked()
player.face(-1)                    # -1 trái, 1 phải
await player.walk_to(320.0)        # cutscene
player.get_speech_anchor()         # điểm đuôi khung thoại
```

**Xong khi:** đi / chạy / đứng đúng animation; không đi được khi đang thoại, cutscene, minigame, menu, chuyển map; tay cầm dùng được.

---

## 2. World & Chuyển map

**Mục đích:** thế giới gồm nhiều map nối nhau; đi hết mép map hoặc vào cửa thì sang map khác có hiệu ứng mờ dần, Minh xuất hiện đúng chỗ.

**Thành phần**

| File | Vai trò | Trạng thái |
|---|---|---|
| `world/areas/map_base.gd` (`GameMap`) | Lớp cơ sở mọi map: `map_id`, `map_size`, đặt Player, giới hạn camera | ✅ |
| `world/areas/<map_id>/<map_id>.tscn` | Từng map (`garden/garden.tscn`, `village/village.tscn`…) | 🟡 Vườn rau |
| `core/autoload/scene_manager.gd` (`SceneManager`) | Đổi map, fade, đặt Player (Na: chưa) | ✅ |
| `world/transitions/map_exit.gd` | Vùng ở mép map, đi vào (đúng hướng) là chuyển | ✅ |
| `world/transitions/door.gd` | Cửa / cổng / cầu thang, bấm E mới chuyển | ✅ |
| (trong `SceneManager`) | Lớp đen mờ dần 0,25 s | ✅ |

**Cấu trúc một map**
```text
<MapName> (Node2D, script map_base.gd)   map_id = "garden", map_size = (640, 384)
├── Background (z -10)    các layer Aseprite: Sprite2D, hoặc Parallax2D cho layer trôi
├── Bounds (StaticBody2D) mặt đất + 2 tường
├── Spawns
│   ├── PlayerSpawn       chỗ mặc định (đặt ở CHÂN)
│   ├── from_village      vào từ làng
│   └── from_house        ra từ nhà
├── Markers               chỗ đứng NPC, điểm cutscene: porch, garden_bed, fence…
├── NPCs                  instance narrative/npc/characters/*
├── Objects               vật tương tác, vật đổi trạng thái
├── Collectibles          pickup, Hạt Gió
├── Exits                 map_exit, door
└── Foreground (z 50)     layer tiền cảnh
```

**Luồng `SceneManager.change_map(map_id, spawn)`**
1. `player.lock("transition")`, fade đen 0,3 s.
2. Lưu `Persistent` của map cũ (hệ thống 3), xoá map cũ.
3. Nạp `res://world/areas/<map_id>/<map_id>.tscn`, thêm vào `Main/World`.
4. Đặt Minh ở `Spawns/<spawn>` (không có thì `PlayerSpawn`), Na ngay sau lưng nếu đang đi theo.
5. Map tự dựng trạng thái: NPC theo lịch, vật theo điều kiện, `Persistent` khôi phục.
6. `GameState.current_map = map_id`, `EventBus.map_changed`, `AudioManager` đổi nhạc theo map.
7. Fade sáng, `player.unlock("transition")`, `SaveManager.autosave()`.

**MapExit / Door – thuộc tính**

| Thuộc tính | Ý nghĩa |
|---|---|
| `target_map` | `map_id` đích, vd `"village"` |
| `target_spawn` | tên spawn ở map đích, vd `"from_garden"` |
| `condition` | biểu thức, rỗng = luôn đi được. Vd `"has_flag('ch1.village_unlocked')"` |
| `locked_dialogue` + `locked_cue` | câu Minh nói khi chưa đi được (MapExit đẩy Minh lùi lại) |
| `prompt_text` (Door) | "Vào nhà", "Ra vườn" |

**Sơ đồ nối map hiện tại** (mỗi lối đi hai chiều; spawn đích tên `from_<map nguồn>`)

| Map | Lối đi |
|---|---|
| `living_room` | cửa phòng ngủ (E) → `phong_ngu_minh` · mép trái → `yard` |
| `phong_ngu_minh` | mép trái → `living_room` |
| `yard` | cửa nhà "Vào nhà" (E) → `living_room` · khe hàng rào "Ra ngõ" (E) → `nha_minh_va_an` · mép trái → `garden` |
| `garden` | mép phải → `yard` |
| `nha_minh_va_an` | cửa nhà bên phải "Vào sân" (E) → `yard` · cổng làng "Ra đồng" (E) → `field` · mép phải → `goc_cay_da` |
| `goc_cay_da` | mép trái → `nha_minh_va_an` |
| `field` | cổng làng "Vào xóm" (E) → `nha_minh_va_an` · cầu thang "Xuống bờ mương" (E) → `bo_muong_chan_de` · mép phải → `bo_de_hoang_hon` · mép trái → `cong_truong_thpt` |
| `bo_de_hoang_hon` | mép trái → `field` |
| `bo_muong_chan_de` | cầu thang "Lên đồng" (E) → `field` |
| `cong_truong_thpt` | mép phải → `field` · mép trái → `pho_truoc_truong` · cổng "Vào trường" (E) → `lop_hoc` |
| `pho_truoc_truong` | mép phải → `cong_truong_thpt` |
| `lop_hoc` | cửa "Ra cổng trường" (E) → `cong_truong_thpt` |

Map riêng cho minigame / sự kiện (không nối): `phong_minh_o_thanh_pho`, `ruong_sau_nha_na`.

**Thêm một lối đi bằng tay:** trong `Exits/` thêm `Area2D` gắn `world/transitions/map_exit.gd` (mép) hoặc `door.gd` (cửa) + `CollisionShape2D`; điền `target_map`, `target_spawn`, (`direction` cho mép, `prompt_text` cho cửa); ở map đích thêm `Marker2D` tên đúng `target_spawn` trong `Spawns/`, đặt ở CHÂN. Vùng mép phải nằm sát tường, chỗ xuất hiện cách mép ≥ 110 px để không bị đẩy ngược lại.

**Parallax:** layer trôi dùng node `Parallax2D` (`scroll_scale`, `repeat_size`, `autoscroll`), chỉnh trong Inspector, không viết script.

**Dùng thế nào (dựng một map)**
1. Vẽ map trong Aseprite, layer đặt tên `NN_Ten_layer`, lưu ở `art_source/maps/<map_id>.aseprite`.
2. Chạy `python tools/export_art.py art_source/maps/<map_id>.aseprite` → mỗi layer thành `assets/maps/<map_id>/<layer>.png`.
3. Tạo scene mới **theo cấu trúc như trên**, kéo PNG vào `Background` / `Foreground` (`centered` tắt, vị trí `(0, 0)`).
4. Thêm `Bounds`, `Spawns`, `Exits`. Đặt `map_id` trùng tên thư mục.

**Xong khi:** đi qua lại giữa 2 map bằng mép map và cửa, đúng chỗ xuất hiện, có fade, cửa có điều kiện chặn đúng, camera không lộ ra ngoài map.

---

## 3. World State – trạng thái thế giới

**Mục đích:** làm xong việc thì thế giới **thay đổi và nhớ mãi**: vòi nước hết rò, rau xanh lại, NPC đổi chỗ, đổi câu thoại, mở đường mới. Rời map hay thoát game vào lại vẫn đúng.

**Nguyên tắc:** thế giới được **dựng lại từ trạng thái** mỗi khi vào map và mỗi khi `GameState.changed`, không phải "khi sự kiện vừa xảy ra thì đổi hình".

**Thành phần**

| File | Vai trò | Trạng thái |
|---|---|---|
| `core/autoload/game_state.gd` (`GameState`) | Nguồn dữ liệu duy nhất: chương, ngày, buổi, map, cờ, quest, túi đồ, Hạt Gió | ✅ (thiếu `inventory`) |
| `core/autoload/event_bus.gd` (`EventBus`) | Signal sự kiện dùng chung | ✅ |
| `core/components/conditional_visibility.gd` | Hiện / ẩn node theo điều kiện | ⬜ |
| `core/components/state_switch.gd` | Đổi hình / animation / bật tắt node con theo danh sách điều kiện | ⬜ |
| `narrative/npc/npc_schedule.gd` (`NpcSchedule`) | NPC đứng ở map / marker nào theo điều kiện | ⬜ |
| `core/components/persistent.gd` | Nhớ property của vật thể khó diễn tả bằng cờ | ⬜ |

**Biểu thức điều kiện** – dùng ở mọi nơi (`GameState.check()`):
```text
is_quest_done('fix_pipe')
has_flag('ch1.pipe_fixed') and not has_flag('ch1.garden_watered')
chapter >= 2 or time == 'evening'
npc_talks('ong_noi') >= 3
```

**ConditionalVisibility**
- `visible_when: String`. Sai → ẩn node, tắt va chạm và mọi `Interactable` con.
- Ví dụ: tia nước rò `visible_when = "not has_flag('ch1.pipe_fixed')"`.

**StateSwitch** – một vật nhiều trạng thái
```text
states = [
  { when = "has_flag('ch1.garden_watered')", show = "Green" },
  { when = "",                               show = "Dry"   },   # mặc định
]
```
Bật node con tên `show`, ẩn các node con còn lại (hoặc đổi `animation` của AnimatedSprite2D). Dòng khớp đầu tiên thắng.

**NpcSchedule** – NPC đứng đâu
```text
entries = [
  { when = "time == 'evening'",           map = "house",  marker = "porch" },
  { when = "is_quest_active('fix_pipe')", map = "garden", marker = "garden_bed" },
  { when = "",                            map = "garden", marker = "garden_bed" },
]
```
- Khi vào map, map hỏi lịch từng NPC có lịch: trỏ tới map này → đặt NPC ở `Markers/<marker>`, không thì NPC vắng mặt.
- Kịch bản dời chỗ: `npc_set("na", "location", "canal/sitting_spot")`, ưu tiên hơn lịch.
- Đi lại tạm thời (đang bước tới đâu đó) **không lưu**.

**Persistent**
- `persist_id`, `properties = ["position", "visible"]`. Rời map ghi vào cờ `world.<map_id>.<persist_id>`; vào map khôi phục.
- Chỉ dùng cho thứ cờ không diễn tả được (thùng bị đẩy lệch, diều mắc cành nào). Đồ đã nhặt, cửa đã mở → dùng cờ.

**Thứ tự khi vào map:** đặt Minh → NPC theo lịch / ghi đè → `Persistent` khôi phục → mọi `ConditionalVisibility` / `StateSwitch` tự cập nhật.

**Dùng thế nào:** chọn node trong map → gắn component → gõ điều kiện trong Inspector. Không viết code.

**Xong khi:** trên map thử: xong quest thử → một vật đổi hình, một NPC đổi chỗ, một cửa mở; rời map quay lại và lưu / tải vẫn đúng.

---

## 4. Lưu & Tải game

**Mục đích:** thoát game vào lại tiếp tục đúng chỗ.

**Thành phần:** `core/autoload/save_manager.gd` (`SaveManager`) ⬜

**Lưu gì:** toàn bộ `GameState` + vị trí Minh. Không lưu gì khác (vì mọi thứ khác dựng lại từ `GameState`).

```json
{
  "version": 1,
  "saved_at": "2026-11-10T21:03:00",
  "chapter": 1, "day": 1, "time": "morning",
  "player": { "map": "garden", "spawn": "from_village", "pos": [412, 264] },
  "flags": { "ch1.pipe_fixed": true, "npc.ong_noi.talks": 4, "seed.garden_01": true },
  "quests": { "fix_pipe": "done", "fishing": "active" },
  "inventory": { "pipe_clamp": 1 },
  "wind_seeds": 3
}
```

**API**
```gdscript
SaveManager.save_game()        # ghi user://save.json
SaveManager.load_game()        # đọc → GameState → SceneManager.change_map(player.map, ...) → đặt pos
SaveManager.has_save()
SaveManager.autosave()         # gọi khi đổi map, xong quest / minigame, thoát game
SaveManager.new_game()         # xoá GameState về mặc định, vào chương đầu
```

**Quy tắc**
- Ghi ra `save.tmp` rồi đổi tên thành `save.json` (tắt máy giữa chừng không hỏng file).
- `version` + hàm nâng cấp khi đổi cấu trúc / tên cờ.
- JSON: số nguyên đọc lên thành số thực → ép `int()` cho bộ đếm; `Vector2` lưu thành `[x, y]`.
- Không lưu khi đang cutscene / minigame / chuyển map (đợi xong).
- Cài đặt (âm lượng, toàn màn hình) lưu riêng `user://settings.cfg`.
- Một slot + tự lưu là đủ cho MVP.

**Xong khi:** đang làm dở quest, có đồ trong túi, NPC đã đổi chỗ → thoát → Tiếp tục: mọi thứ đúng y như trước.

---

## 5. Tương tác

**Mục đích:** mọi thứ người chơi bấm E vào (NPC, đồ để soi, đồ nhặt, chỗ cần dùng đồ, cửa) dùng **chung một cơ chế**.

**Thành phần**

| File | Loại | Trạng thái |
|---|---|---|
| `core/components/interactable.gd` (`Interactable`) | Area2D cơ sở: `prompt_text`, `prompt_offset`, `enabled`, signal `interacted(player)` | ✅ |
| `gameplay/interaction/interaction_prompt.tscn` | Icon dấu hỏi trên vật gần nhất | ✅ |
| `world/objects/inspect/inspect.tscn` | **Soi đồ**: Minh nói một câu | ⬜ |
| `gameplay/inventory/pickup.tscn` | **Nhặt đồ** (hệ thống 9) | ⬜ |
| `world/objects/use_item/use_item_target.tscn` | **Chỗ cần dùng đồ**: ống rò, ổ khoá… | ⬜ |
| `world/transitions/door.tscn` | **Cửa** (hệ thống 2) | ⬜ |
| `narrative/npc/npc.tscn` | **NPC** (hệ thống 6) | ✅ |

**Quy ước chung:** đối tượng tương tác = Area2D trong nhóm `interactable`, layer 4, có hàm `interact(player)`. Player tự tìm, không cần đăng ký.

**Inspect – soi đồ**

| Thuộc tính | Ý nghĩa |
|---|---|
| `inspect_id` | id, vd `mango_tree` → cờ `seen.mango_tree` |
| `dialogue` + `cue` | đoạn thoại khi soi lần đầu |
| `cue_again` | đoạn khi soi lại (rỗng = dùng `cue`) |
| `visible_when` | chỉ soi được khi… (rỗng = luôn) |

**UseItemTarget – chỗ cần dùng đồ**

| Thuộc tính | Ý nghĩa |
|---|---|
| `required_items` | `{"pipe_connector": 1, "rubber_ring": 1, "pipe_clamp": 1}` |
| `consume` | dùng xong thì bỏ khỏi túi |
| `missing_cue` | đoạn thoại khi thiếu đồ (trong `.dialogue` dùng `has_item()` để nói đúng món còn thiếu) |
| `success_cue` | đoạn thoại / cutscene khi đủ đồ |
| `set_flags` | cờ bật khi thành công, vd `["ch1.pipe_fixed"]` |
| `active_when` | chỉ dùng được khi… (vd `"is_quest_active('fix_pipe')"`) |

**Dùng thế nào (quest sửa vòi):** đặt `UseItemTarget` lên ống rò trong map, điền 3 món + cờ `ch1.pipe_fixed` + cue thoại. Không viết code.

**Xong khi:** soi, nhặt, dùng đồ (đủ / thiếu), mở cửa, nói chuyện đều chạy bằng E và nút A tay cầm; icon hiện đúng vật gần nhất.

---

## 6. NPC & Hội thoại

**Mục đích:** nhân vật có mặt đúng lúc, nói đúng câu theo tiến trình; khung thoại đẹp, rõ ai đang nói.

**Thành phần**

| File | Vai trò | Trạng thái |
|---|---|---|
| `narrative/npc/npc_data.gd` (`NpcData`) | Dữ liệu nhân vật: `id`, `display_name`, `dialogue_color`, `sprite_frames`, `dialogue`, `dialogue_cue`, `speech_height` | ✅ |
| `data/npcs/<id>.tres` | Một file mỗi nhân vật (`ong_noi.tres`, `minh.tres`) | ✅ |
| `narrative/npc/npc.tscn` / `npc.gd` | NPC dùng chung: gán `data` + `appear_condition`; tự đếm `npc.<id>.talks`; quay mặt về Minh | ✅ |
| `narrative/npc/characters/<id>/<id>.tscn` | Instance NPC đã gán `data` | ✅ Ông Nội |
| `addons/dialogue_manager/` | Chạy file `.dialogue`: điều kiện, lựa chọn, lệnh `do` | ✅ |
| `narrative/dialogue/dialogue_balloon.tscn` | Khung `assets/ui/dialogue_box.png`, tên + lời, chữ chạy, đuôi chỉ người nói, viền đổi màu, mũi tên ▼ | ✅ |
| `data/dialogues/<id>.dialogue` | Lời thoại | 🟡 Ông Nội |

**Quy ước file `.dialogue`**
```text
~ start                         # cue mặc định – BỘ CHỌN, chỉ có if/elif + =>
if is_quest_new("fix_pipe") and current_map == "garden":
	=> intro_pipe
elif is_quest_active("fix_pipe"):
	=> pipe_waiting
else:
	=> idle

~ intro_pipe                    # mỗi đoạn một cue, tên snake_case
Ông Nội: Minh dậy rồi đó hả con?
- Dạ, con phải làm gì ông?      # lựa chọn
	Ông Nội: ...
do start_quest("fix_pipe")      # đổi trạng thái
Minh: (câu nội tâm để trong ngoặc)
=> END
```
- **Tên người nói** phải trùng `display_name` trong `data/npcs/*.tres`.
- Thứ tự `if / elif` = độ ưu tiên.
- Gọi được mọi hàm / biến của `GameState` không cần tiền tố (`has_flag`, `npc_talks`, `time`…), sau này cả `InventoryManager.has_item`, `Cutscene.*`.
- Nhớ đoạn đã nghe: `do npc_set("ong_noi", "heard_intro", true)`.

**Thêm một NPC mới (không code)**
1. Aseprite: `art_source/characters/<id>/<id>_idle.aseprite`, tag `Idle` → `python tools/export_art.py` → được `assets/characters/<id>/<id>_idle_frames.tres`.
2. `data/npcs/<id>.tres` (New Resource → NpcData): tên, màu, sprite (`…_frames.tres`), file hội thoại.
3. `data/dialogues/<id>.dialogue` có cue `start`.
4. Chuột phải `narrative/npc/npc.tscn` → *New Inherited Scene* → gán `data` → lưu `narrative/npc/characters/<id>/<id>.tscn`.
5. Kéo vào `NPCs` của map, đặt `appear_condition` (hoặc lịch – hệ thống 3).

**Xong khi:** ✅ đã đạt cho Ông Nội. Còn: Na, 1–2 dân làng; lịch NPC.

---

## 7. Nhiệm vụ & Chương

**Mục đích:** người chơi luôn biết "làm gì tiếp"; xong việc thì có thưởng; đủ việc thì sang chương mới.

### 7.1. Quest

**Thành phần (⬜):** `narrative/quest/quest_data.gd` (`QuestData`), `quest_objective.gd` (`QuestObjective`), `quest_manager.gd` (`QuestManager`, autoload), `data/quests/<id>.tres`.

**QuestData**

| Trường | Ví dụ (`fix_pipe`) |
|---|---|
| `id`, `title`, `description` | `fix_pipe`, "Sửa vòi nước cho ông", "Cái vòi ngoài vườn rau lại rỉ nước…" |
| `giver` | `ong_noi` |
| `objectives` | xem dưới |
| `reward_wind_seeds`, `reward_items`, `reward_flags` | `3`, `{}`, `["ch1.village_unlocked"]` |
| `auto_complete` | `false` = phải báo NPC mới xong (NPC gọi `complete_quest` trong `.dialogue`) |

**QuestObjective**

| Trường | Ví dụ |
|---|---|
| `id` | `find_parts` |
| `text` | "Tìm bộ phận sửa vòi ({count}/{required})" |
| `done_when` | `"InventoryManager.count_of(['pipe_connector','rubber_ring','pipe_clamp']) >= 3"` hoặc `"has_flag('ch1.pipe_fixed')"` |
| `required` | `3` (cho chữ x/3) |
| `hidden_until` | hiện bước này khi… (rỗng = khi bước trước xong) |

Quest `fix_pipe` gồm 3 bước: *Tìm bộ phận (x/3)* → *Sửa chỗ ống bị rò* → *Tưới rau rồi báo ông*.

**Hoạt động**
- Trạng thái quest: `GameState.quests[id] = "active" | "done"` (đã có).
- Bước tự kiểm tra mỗi khi `GameState.changed` / `EventBus.item_collected`: biểu thức `done_when` đúng → bước xong → `EventBus.quest_changed` → HUD cập nhật.
- `complete_quest`: phát thưởng, bật `reward_flags`, `EventBus.quest_changed(id, "done")`, toast "Hoàn thành: …".

**API**
```gdscript
QuestManager.start_quest("fix_pipe")
QuestManager.get_current_objective("fix_pipe")   # → QuestObjective (cho HUD)
QuestManager.update_objective("fix_pipe", "find_parts")   # đánh dấu tay (hiếm khi cần)
QuestManager.can_complete("fix_pipe")
QuestManager.complete_quest("fix_pipe")
QuestManager.get_active() / get_done()           # cho Sổ
```

### 7.2. Chương

**Thành phần (⬜):** `narrative/chapter/chapter_data.gd` (`ChapterData`), `chapter_manager.gd` (`ChapterManager`), `ui/chapter_title/chapter_title.tscn`, `data/chapters/chapter_01.tres`.

**ChapterData**

| Trường | Ví dụ Chương 1 |
|---|---|
| `id`, `title`, `subtitle` | `1`, "Chương 1", "Mùa hè ở Làng Cỏ" |
| `start_map`, `start_spawn` | `garden`, `PlayerSpawn` |
| `start_dialogue`, `start_cue` | `ch1_story.dialogue`, `opening` |
| `objectives` | `["is_quest_done('fix_pipe')", "is_quest_done('fishing')", "is_quest_done('melon')"]` |
| `end_dialogue`, `end_cue` | `ch1_story.dialogue`, `ending` |
| `next_chapter` | `2` |

**Luồng:** `start_chapter(1)` → màn hình tên chương (nền đen, chữ hiện dần 2–3 s) → `change_map(start_map)` → chạy `start_cue`. Mỗi khi `GameState.changed`: đủ `objectives` → chạy `end_cue` → `ch1.complete` → `start_chapter(next)`.

**Dùng thế nào:** tạo `.tres` trong Inspector; quest mới = file mới.

**Xong khi:** quest thử 2 bước nhận từ NPC, HUD cập nhật đúng từng bước, xong có thưởng; xong objective chương thử → màn hình tên chương mới.

---

## 8. Cutscene

**Mục đích:** dàn cảnh kể chuyện (nhân vật tự đi, camera lia, màn hình tối, đổi map) **viết ngay trong file `.dialogue`**, không cần code từng cảnh.

**Thành phần (⬜):** `narrative/cutscene/cutscene.gd` (autoload `Cutscene`).

**Lệnh** (mọi lệnh có thời gian đều `await` được; Dialogue Manager tự chờ xong mới sang dòng sau):

| Lệnh | Tác dụng |
|---|---|
| `do Cutscene.begin()` / `do Cutscene.end()` | Khoá Minh, ẩn HUD + icon tương tác / mở lại |
| `do Cutscene.fade_out(0.5)` / `fade_in(0.5)` | Tối / sáng dần |
| `do Cutscene.wait(1.0)` | Chờ |
| `do Cutscene.walk("Na", "fence")` | Nhân vật đi tới `Markers/fence` của map hiện tại |
| `do Cutscene.face("Ông Nội", "left")` | Quay mặt |
| `do Cutscene.play_anim("Na", "Wave")` | Chạy animation |
| `do Cutscene.show_npc("Na", "fence")` / `hide_npc("Na")` | Hiện / ẩn nhân vật (ở marker) |
| `do Cutscene.camera_to("pipe", 1.0)` / `camera_reset(1.0)` | Lia camera tới marker / về Minh |
| `do Cutscene.change_map("village", "from_garden")` | Đổi map giữa cảnh |
| `do Cutscene.play_sfx("water_burst")` | Âm thanh |

- Nhân vật tìm theo `display_name` hoặc `id` (`"Na"`, `"na"`, `"Minh"`).
- Marker tìm trong `Markers/` của map hiện tại.
- Cảnh cần chuyển động phức tạp: làm scene riêng có `AnimationPlayer` trong `narrative/cutscene/<ten_canh>/`, gọi bằng `do Cutscene.play_scene("bus_ride")`.

**Ví dụ – Na xuất hiện**
```text
~ meet_na
do Cutscene.begin()
do Cutscene.show_npc("Na", "fence_far")
do Cutscene.walk("Na", "fence")
Na: Ê! Bạn là cháu ông Tư hả?
do set_flag("ch1.met_na")
do Cutscene.end()
=> END
```

**Xong khi:** cảnh thử trên map thử nghiệm chạy đủ fade, walk, face, camera, show/hide, đổi map; Minh không đi được trong lúc chạy; HUD ẩn / hiện đúng.

---

## 9. Túi đồ & Vật phẩm

**Mục đích:** nhặt đồ, xem đồ, đưa / dùng đồ để mở việc mới; Hạt Gió để sưu tầm.

**Thành phần (⬜)**

| File | Vai trò |
|---|---|
| `gameplay/inventory/item_data.gd` (`ItemData`) | `id`, `display_name`, `description`, `icon`, `stackable`, `key_item` (đồ nhiệm vụ, không bỏ được) |
| `data/items/<id>.tres` | `pipe_connector`, `rubber_ring`, `pipe_clamp`, `fish`, `watermelon` |
| `gameplay/inventory/inventory_manager.gd` (`InventoryManager`) | Thêm / bớt / kiểm tra. **Dữ liệu ghi vào `GameState.inventory`** |
| `gameplay/inventory/pickup.tscn` | Vật nhặt trên map |
| `gameplay/inventory/wind_seed.tscn` | Hạt Gió (pickup đặc biệt, lấp lánh) |

**API**
```gdscript
InventoryManager.add_item("pipe_clamp", 1)     # → EventBus.item_collected + toast "Đã nhận: Cái kẹp"
InventoryManager.remove_item("pipe_clamp", 1)  # → EventBus.item_removed
InventoryManager.has_item("pipe_clamp", 1)
InventoryManager.count_of(["pipe_connector", "rubber_ring", "pipe_clamp"])   # tổng số loại đang có
InventoryManager.get_all()                      # cho Sổ
InventoryManager.get_data("pipe_clamp")         # → ItemData
```

**Pickup**

| Thuộc tính | Ý nghĩa |
|---|---|
| `item` | `ItemData` |
| `amount` | số lượng |
| `pickup_id` | id duy nhất trong game, vd `garden_connector` → cờ `picked.garden_connector`; đã nhặt thì không hiện lại |
| `visible_when` | chỉ xuất hiện khi… (vd `"is_quest_active('fix_pipe')"`) |
| `pickup_cue` | câu Minh nói khi nhặt (tuỳ chọn) |

**Hạt Gió:** `seed_id` (`garden_01`) → cờ `seed.garden_01`, `GameState.add_wind_seeds(1)`, toast "+1 Hạt Gió". Chỉ để sưu tầm, không chặn tiến trình (luật R8).

**Xong khi:** nhặt đồ có toast, thấy trong Sổ, vào lại map không còn; đưa đồ cho NPC qua `.dialogue`; `UseItemTarget` dùng đồ được; Hạt Gió đếm đúng.

---

## 10. Khung Minigame

**Mục đích:** mỗi minigame là một scene độc lập (làm và test riêng được), mở ra từ thế giới, chơi xong trả kết quả và quay về đúng chỗ.

**Thành phần (⬜)**

| File | Vai trò |
|---|---|
| `gameplay/minigame/minigame_manager.gd` (`MinigameManager`) | Mở / đóng minigame, khoá thế giới, nhận kết quả |
| `gameplay/minigame/minigame_base.gd` (`MinigameBase`) | Lớp cơ sở mọi minigame kế thừa |
| `gameplay/minigame/minigame_spot.tscn` | Điểm trên map, bấm E để chơi (Interactable) |
| `gameplay/minigame/<id>/<id>.tscn` | Từng minigame: `fishing`, `melon_stealth` |

**Luồng**
```text
MinigameSpot (E) hoặc .dialogue: do MinigameManager.start("fishing", {"target": 3})
  → khoá Minh, ẩn HUD, dừng World (process_mode = DISABLED), mở minigame trên CanvasLayer riêng
  → minigame chạy … phát finished(result)
  → MinigameManager: cờ minigame.<id>.won / best_score, EventBus.minigame_finished, đóng, mở lại World
  → quest / hội thoại tự phản ứng qua cờ (vd objective done_when = "has_flag('minigame.fishing.won')")
```
**Minigame chỉ trả kết quả**: không tự xong quest, không tự đổi chương, không sửa `GameState` ngoài cờ của chính nó.

**MinigameBase cung cấp**

| Thành phần | Ý nghĩa |
|---|---|
| `signal finished(result: Dictionary)` | `{"success": true, "score": 80, "item_id": "fish", "amount": 3}` |
| `func setup(params: Dictionary)` | Nhận tham số (số cá cần câu, độ khó…) |
| `func restart()` | Giữ R 0,5 s → tái lập ≤ 2 giây, không mất gì (luật R2) |
| `func report_fail()` | Gọi khi người chơi hụt → tăng `fail_count` |
| Chỉ số bực bội **F = fail_count + stuck_seconds / 30** | F ≥ 3 → Na nhắc; F ≥ 6 → Ông Nội gợi ý; F ≥ 9 → hiện hình minh hoạ; sau mỗi gợi ý F − 3 (luật R6) |
| `func request_hint()` | H: xem lại hướng dẫn |
| "Nhờ Na" | `can_call_na`, `na_cooldown = 15.0`; Space / X gọi `_on_na_help()` (minigame tự định nghĩa Na giúp gì) |
| `hint_lines` | các câu gợi ý theo mức F |
| Chạy riêng (F6) | Không có `MinigameManager` → tự `setup()` với tham số mặc định, in kết quả ra Output |

**Minigame Chương 1**

| Minigame | Người làm | Tóm tắt (GDD) |
|---|---|---|
| `fishing` – Câu cá bên mương | Trí | Quan sát gợn sóng / bóng cá, thả cần đúng chỗ, bấm đúng lúc. Hụt → tái lập lượt ≤ 2 s. "Nhờ Na": Na chỉ chỗ có cá (hồi 15 s). Đủ số cá → thắng |
| `melon_stealth` – Trộm dưa | Tuấn | Nấp sau bó rơm, canh hướng nhìn người trông ruộng, hái dưa khi có cơ hội. Bị phát hiện khi chưa đủ dưa → về bó rơm gần nhất ≤ 2 s, giữ số dưa. Đủ dưa → kết quả `success` (cảnh bị phát hiện + chạy trốn do cutscene làm) |

**Xong khi:** minigame thử mở từ map, thắng → về đúng chỗ, cờ bật; chơi lại ≤ 2 s; F tăng và gợi ý hiện đúng mức; chạy riêng bằng F6 được; bàn phím + tay cầm.

---

## 11. Bạn đồng hành – Bé Na

> **Đã làm (bản đầu):** nhân vật **An** (`art_source/characters/an/an.aseprite` → `assets/characters/an/an_frames.tres`) đi theo Minh.
> - Bật / tắt bằng cờ **`npc.an.following`**: trong `.dialogue` viết `do npc_set("an", "following", true)` / `false`. Bản debug: phím **F2** bật / tắt nhanh.
> - Scene `gameplay/companion/an_companion.tscn` (kế thừa `npc.tscn`, `appear_condition = "npc_get('an', 'following', false)"`) + component `gameplay/companion/follower.gd`; dữ liệu `data/npcs/an.tres`, thoại tạm `data/dialogues/an.dialogue`.
> - `Main` tạo An làm con của `World` nên đổi map vẫn còn; sau mỗi lần đổi map An đứng ngay sau lưng Minh.
> - Đi sau lưng ~40 px, chạy khi Minh chạy hoặc bị bỏ xa > 110 px, dịch chuyển ngầm khi xa > 280 px, đứng yên khi Minh bị khoá, không ra ngoài map.
> - Vùng tương tác của An đang tắt (không hiện dấu hỏi suốt lúc đi theo).
>
> Các mục bên dưới là thiết kế đầy đủ (tên "Na" theo GDD).


**Mục đích:** Na đi cùng Minh, làm thế giới bớt cô đơn, giúp trong minigame.

**Thành phần (⬜)**

| File | Vai trò |
|---|---|
| `data/npcs/na.tres` | Tên "Na", màu thoại, sprite, `na.dialogue` |
| `narrative/npc/characters/na/na.tscn` | Kế thừa `npc.tscn` + component đi theo |
| `gameplay/companion/follower.gd` | Hành vi đi theo |

**Hành vi**
- Bật khi `has_flag('ch1.na_joined')`; trước đó Na là NPC bình thường (đứng ở marker theo lịch).
- Khi đi theo: là con của `Main/World` (không phải con của map) nên **đổi map vẫn còn**; SceneManager đặt Na ngay sau lưng Minh.
- Giữ khoảng cách ~40 px sau lưng Minh; Minh dừng thì Na dừng; cùng animation Walk/Run/Idle.
- Cách quá xa (> 200 px) hoặc ra khỏi màn hình → **dịch chuyển ngầm** về sau lưng Minh.
- Không chặn đường Minh (không va chạm với Player).
- Đứng yên khi cutscene (Cutscene điều khiển), khi minigame thì ẩn hoặc minigame tự dùng Na.
- Vẫn nói chuyện được (bấm E vào Na) → `na.dialogue` cue `start`.
- Cài đặt "Na đứng yên": Na không đi theo, chỉ xuất hiện khi cần.

**Xong khi:** Na đi theo qua 2 map, không kẹt, không chặn Minh, dịch chuyển khi bị bỏ xa, đứng đúng chỗ khi cutscene, lưu / tải vẫn đang đi theo.

---

## 12. Giao diện & Âm thanh

### 12.1. Giao diện

**Nguyên tắc:** UI chỉ **nghe signal và đọc trạng thái**, không chứa logic gameplay. Mọi UI dùng chung theme `ui/theme/main_theme.tres` (font VT323, màu, khung). Điều khiển được bằng bàn phím và tay cầm (focus).

| Màn hình | File | Mô tả | Trạng thái |
|---|---|---|---|
| Hộp thoại | `narrative/dialogue/` | (hệ thống 6) | ✅ |
| Icon tương tác | `gameplay/interaction/` | Dấu hỏi trên vật gần nhất | ✅ |
| Fade chuyển cảnh | `ui/transition/` | Lớp đen, `fade_out() / fade_in()` | ⬜ |
| HUD quest | `ui/hud/quest_tracker.tscn` | Góc trên: tên quest + bước hiện tại "Tìm bộ phận (1/3)". Hiện khi nhận / cập nhật, tự mờ sau 4 s; Tab xem lại | ⬜ |
| Toast | `ui/hud/toast.tscn` | Góc phải: "Đã nhận: Cái kẹp", "+1 Hạt Gió", "Hoàn thành: Sửa vòi nước". Hàng đợi, mỗi cái 2,5 s | ⬜ |
| Sổ kỷ vật (Tab / Y) | `ui/journal/journal.tscn` | Tab **Nhiệm vụ** (đang làm / đã xong gạch ngang) · **Túi đồ** (icon + mô tả) · **Hạt Gió** (đếm theo map) · **Nhật ký** (đoạn ngắn mở sau mỗi việc lớn) | ⬜ |
| Tên chương | `ui/chapter_title/` | (hệ thống 7) | ⬜ |
| Menu chính | `ui/menu/main_menu.tscn` | Tiếp tục (ẩn nếu chưa có save) · Chơi mới · Cài đặt · Thoát | ⬜ |
| Tạm dừng (Esc / Start) | `ui/menu/pause_menu.tscn` | Tiếp tục · Cài đặt · Về menu chính. Dừng game (`get_tree().paused`) | ⬜ |
| Cài đặt | `ui/settings/settings.tscn` | Âm lượng Nhạc / Hiệu ứng / Môi trường · Toàn màn hình · Chế độ "Nhẹ nhàng" · "Na đứng yên". Lưu `user://settings.cfg` | ⬜ |

**Cây UI trong Main**
```text
UI (CanvasLayer, layer 10)
├── QuestTracker   ├── Toast   ├── Journal (ẩn)   └── PauseMenu (ẩn)
Transition (CanvasLayer, layer 90)   ← trên cùng
(hộp thoại: CanvasLayer 100, do Dialogue Manager tạo)
```

### 12.2. Âm thanh

**Thành phần (⬜):** `core/autoload/audio_manager.gd` (`AudioManager`), `assets/audio/bgm/`, `assets/audio/sfx/`.

| Bus | Dùng cho |
|---|---|
| `Music` | Nhạc nền (đàn tranh, sáo trúc – GDD mục 3.4.2) |
| `Ambience` | Ve sầu, gió, nước chảy (lặp theo map) |
| `SFX` | Bước chân, nhặt đồ, tương tác, UI, chữ chạy trong hộp thoại |

```gdscript
AudioManager.play_music(stream, fade = 1.0)     # chuyển mượt
AudioManager.play_ambience(stream)
AudioManager.play_sfx("pickup")                 # tên file trong assets/audio/sfx/
AudioManager.set_volume("Music", 0.8)
```
- Mỗi map khai báo `music`, `ambience` trong `GameMap` → SceneManager tự đổi khi vào map.
- Nghe `EventBus.item_collected` → tiếng nhặt; `Player.footstep` → bước chân.

**Xong khi:** đổi map đổi nhạc mượt; có tiếng nhặt đồ, bước chân, chữ chạy; chỉnh âm lượng trong Cài đặt có tác dụng và được nhớ.

---

## Phụ lục: hệ thống nào cần hệ thống nào

```text
Player ─┬─▶ Tương tác ─┬─▶ NPC & Hội thoại ─┬─▶ Quest & Chương ─▶ Cutscene
        │              ├─▶ Túi đồ ──────────┘
        │              └─▶ Khung Minigame ─▶ (fishing, melon_stealth)
        └─▶ World & Chuyển map ─▶ Bé Na
World State (GameState + EventBus) ◀── mọi hệ thống đọc / ghi
Lưu & Tải ◀── chỉ cần World State
UI & Âm thanh ◀── chỉ nghe signal
```

Thứ tự nên làm để không ai phải chờ:
- **Trí:** map thử nghiệm → `lock/unlock` → `ConditionalVisibility` / `StateSwitch` → `Inspect` / `UseItemTarget` → `SceneManager` → `NpcSchedule` / `Persistent` → `SaveManager`.
- **Uyên:** `QuestManager` (Uyên cần cho quest sửa vòi, Tuấn cần cho HUD) → `ChapterManager` → `Cutscene`.
- **Tuấn:** `InventoryManager` + `Pickup` (Uyên cần cho quest sửa vòi) → `MinigameManager` / `MinigameBase` (Trí cần cho câu cá) → toast / HUD / Sổ → Na → menu → `AudioManager`.
