# Mùa Gió Về

Game phiêu lưu kể chuyện 2D cuộn ngang (slice-of-life, có minigame) làm bằng **Godot 4.7**. Minh, cậu bé 13 tuổi, về quê sống cùng Ông Nội ở Làng Cỏ; cùng bé Na khám phá làng, giúp dân làng và dần hồi phục sau những tổn thương ở trường cũ.

```text
Khám phá map ─▶ Gặp NPC, soi đồ vật ─▶ Hội thoại, nhận việc ─▶ Tìm đồ / chơi minigame
      ▲                                                                │
      └──── Thế giới thay đổi (NPC, cảnh vật, hội thoại, đường mới) ◀──┘
```

## Tài liệu

| File | Nội dung |
|---|---|
| [docs/HE_THONG.md](docs/HE_THONG.md) | Mô tả đầy đủ 12 hệ thống cốt lõi: thành phần, dữ liệu, API, cách dùng, điều kiện xong |
| [docs/KE_HOACH.md](docs/KE_HOACH.md) | Phạm vi MVP Chương 1, thứ tự làm, phân công Tuấn · Uyên · Trí, Git, Definition of Done |
| [docs/KIEN_TRUC.md](docs/KIEN_TRUC.md) | Kiến trúc, cấu trúc thư mục, quy ước đặt tên, cờ, signal, API, autoload |
| [REQUIREMENTS.md](REQUIREMENTS.md) | Yêu cầu chạy dự án |
| `report.pdf` (GDD) | Thiết kế game đầy đủ |

## Chạy dự án

1. Cài **Godot 4.7.2+** (bản *Standard*, renderer *Compatibility*).
2. Cài **Aseprite** và trỏ đường dẫn trong *Editor → Editor Settings → Aseprite → General → Command Path* (AsepriteWizard cần để import file `.aseprite`).
3. Mở `project.godot`, đợi import xong, bấm **F5**.

**Điều khiển:** A/D hoặc ←/→ đi · giữ Shift chạy · E tương tác / sang câu thoại · ↑/↓ chọn câu trả lời. Có hỗ trợ tay cầm (bố cục Xbox).

## Cấu trúc thư mục

```text
core/        nền tảng dùng chung: autoload (GameState, EventBus…), component, scene Main
gameplay/    player, tương tác, túi đồ, minigame
narrative/   NPC, hộp thoại, quest, chương, cutscene
world/       các map (areas/), cửa và mép map (transitions/), vật thể trong map (objects/)
ui/          HUD, Sổ, menu, cài đặt
data/        NỘI DUNG: npcs/*.tres, dialogues/*.dialogue, quests/, items/, chapters/
assets/      hình, âm thanh, font (.aseprite import qua AsepriteWizard)
addons/      AsepriteWizard, Dialogue Manager
docs/        tài liệu kỹ thuật và kế hoạch
```

Chi tiết từng thư mục, đặt file ở đâu và quy ước đặt tên: [docs/KIEN_TRUC.md](docs/KIEN_TRUC.md) mục 4–5.

## Quy tắc nhanh

- Thêm nội dung (NPC, câu thoại, quest, vật phẩm) bằng **file trong `data/`**, không sửa code.
- Mọi tiến trình nằm trong **`GameState`**; sự kiện đi qua **`EventBus`**.
- Tên file, thư mục: `snake_case`, **không dấu, không khoảng trắng**.
- **Đổi tên / di chuyển file trong Godot editor**, không làm bằng Explorer.
- Không hai người cùng sửa một `.tscn` một lúc. Làm trên nhánh `feature/*`, PR vào `develop`.

## Nhóm

| Thành viên | Vai trò |
|---|---|
| Lê Minh Trí | World & State: player, map, chuyển map, trạng thái thế giới, lưu game, tương tác · minigame Câu cá |
| Trần Hoàng Uyên | Narrative: NPC, hội thoại, quest, chương, cutscene · quest Sửa vòi nước |
| Nguyễn Minh Tuấn | Gameplay & UI: túi đồ, khung minigame, bé Na, HUD, Sổ, menu, âm thanh · minigame Trộm dưa |

## Addon & asset bên thứ ba

- [AsepriteWizard](https://github.com/viniciusgerevini/godot-aseprite-wizard) – MIT
- [Dialogue Manager](https://github.com/nathanhoad/godot_dialogue_manager) 4.2.0 – MIT
- Font [VT323](https://fonts.google.com/specimen/VT323) – SIL Open Font License (`assets/fonts/OFL.txt`)
- `assets/_reference/` chỉ để tham khảo, Godot bỏ qua (`.gdignore`) — **không dùng trong bản phát hành**.
