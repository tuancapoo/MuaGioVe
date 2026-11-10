# Kế hoạch – Mùa Gió Về (MVP Chương 1)

- Mô tả đầy đủ 12 hệ thống cốt lõi: [HE_THONG.md](HE_THONG.md)
- Kiến trúc, thư mục, quy ước, API: [KIEN_TRUC.md](KIEN_TRUC.md)

**Ký hiệu:** ✅ xong · 🟡 một phần · ⬜ chưa làm

---

## 1. Phạm vi MVP Chương 1

Một vòng chơi hoàn chỉnh khoảng 15–20 phút, gồm **1 quest tìm đồ + 2 minigame**:

```text
Vườn rau ─ Ông Nội giao việc sửa vòi nước                       [QUEST – Uyên]
   ↓  tìm 3 bộ phận trong vườn và làng, sửa ống rò, tưới rau, báo ông → +Hạt Gió
   ↓  mở đường sang Làng quê
   ↓  gặp Bé Na → Na đi theo Minh
   ↓  Bờ mương: Na rủ câu cá                                    [MINIGAME – Trí]
   ↓  Ruộng sau nhà Na: rủ nhau trộm dưa                         [MINIGAME – Tuấn]
   ↓  bị phát hiện → cutscene chạy trốn
   ↓  kết thúc Chương 1 (cảnh nội tâm của Minh)
```

| Hạng mục | Nội dung |
|---|---|
| Map | Vườn rau ✅, Làng quê, Bờ mương, Ruộng sau nhà Na (+ 2 map thử nghiệm) |
| NPC | Ông Nội ✅, Bé Na (đi theo), người trông ruộng, 1–2 dân làng |
| Quest | `fix_pipe` (tìm đồ), `fishing`, `melon` |
| Minigame | `fishing` (câu cá), `melon_stealth` (trộm dưa) |
| Hệ thống | 12 hệ thống cốt lõi ([HE_THONG.md](HE_THONG.md)) |

### 1.1. Cờ & nhiệm vụ Chương 1

| Cờ / quest | Bật khi |
|---|---|
| quest `fix_pipe` = active | Ông Nội giao việc (đã có trong `ong_noi.dialogue`) |
| túi đồ: `pipe_connector`, `rubber_ring`, `pipe_clamp` | Nhặt từng bộ phận |
| `ch1.pipe_fixed` | Dùng đủ 3 món lên ống rò |
| `ch1.garden_watered` | Mở van tưới rau |
| quest `fix_pipe` = done, `ch1.village_unlocked` | Báo Ông Nội |
| `ch1.met_na`, `ch1.na_joined` | Gặp Na ở làng / Na bắt đầu đi theo |
| quest `fishing` = active → done, `minigame.fishing.won` | Na rủ câu → thắng minigame |
| quest `melon` = active → done, `minigame.melon_stealth.won` | Rủ trộm dưa → thắng minigame → cutscene chạy trốn |
| `ch1.complete` | Xong cả 3 quest (objectives của `chapter_01.tres`) |

**Người giữ danh sách cờ: Uyên.** Thêm cờ mới phải báo Uyên để cập nhật bảng này.

---

## 2. Phân công

Mỗi người **làm chính một nhóm hệ thống** và **một quest / minigame** của Chương 1 (quest / minigame chia đều).

| Người | Vai trò | Hệ thống ([HE_THONG.md](HE_THONG.md)) | Quest / Minigame | Sở hữu thư mục |
|---|---|---|---|---|
| **Trí** | World & State | 1 Player & Camera · 2 World & Chuyển map · 3 World State · 4 Lưu & Tải · 5 Tương tác; dựng và nối map | Minigame **Câu cá** (`fishing`) | `core/`, `world/`, `gameplay/player/`, `gameplay/interaction/`, `gameplay/minigame/fishing/`, `project.godot` |
| **Uyên** | Narrative | 6 NPC & Hội thoại · 7 Nhiệm vụ & Chương · 8 Cutscene; toàn bộ hội thoại, danh sách cờ | Quest **Sửa vòi nước** (`fix_pipe`) | `narrative/`, `data/dialogues/`, `data/quests/`, `data/chapters/`, `data/npcs/` |
| **Tuấn** | Gameplay & UI | 9 Túi đồ & Vật phẩm · 10 Khung Minigame · 11 Bé Na · 12 Giao diện & Âm thanh | Minigame **Trộm dưa** (`melon_stealth`) | `gameplay/inventory/`, `gameplay/minigame/` (khung + `melon_stealth/`), `gameplay/companion/`, `ui/`, `data/items/` |

- "Sở hữu" = chịu trách nhiệm chính và review. Người khác vẫn được sửa nhưng phải báo trước.
- File chung (`project.godot`, `core/autoload/game_state.gd`, `core/autoload/event_bus.gd`, `core/main/main.tscn`): **Trí giữ**. Cần thêm autoload, signal, hàm trong GameState thì báo Trí.
- `assets/`: ai vẽ / import asset nào thì đặt vào đúng thư mục theo quy ước tên ([KIEN_TRUC.md](KIEN_TRUC.md) mục 5).
- **Cả 3 cùng chịu trách nhiệm:** kiến trúc chung, tích hợp hằng tuần, chơi thử, sửa lỗi.

### 2.1. Đã có (dùng chung)

Player, `Interactable`, icon tương tác, NPC dùng chung + `NpcData`, hộp thoại (Dialogue Manager + khung riêng), `GameState`, `EventBus`, `GameMap`, map Vườn rau (11 layer, `Parallax2D`), hội thoại Ông Nội mở quest `fix_pipe`.

---

## 3. Thứ tự làm

```text
Phase 0  Thống nhất (cả nhóm, 1 buổi)
Phase 1  CORE      – mỗi người làm nhóm hệ thống của mình, test trên map thử nghiệm bằng đồ tạm
Phase 2  NỘI DUNG  – mỗi người ráp quest / minigame của mình + nội dung Chương 1
Phase 3  HOÀN THIỆN – âm thanh, hiệu ứng, sửa lỗi, build
```

### Phase 0 – Thống nhất
- [ ] Cả nhóm đọc [HE_THONG.md](HE_THONG.md) + [KIEN_TRUC.md](KIEN_TRUC.md), chốt tên autoload, signal, API.
- [ ] Uyên chốt danh sách cờ, quest Chương 1 (mục 1.1); Tuấn chốt danh sách vật phẩm.
- [ ] Trí chốt sơ đồ nối map Chương 1 và tên marker / spawn.
- [ ] Mỗi người tạo **khung API rỗng** cho autoload của mình (`SceneManager` – Trí, `QuestManager` / `Cutscene` – Uyên, `InventoryManager` / `MinigameManager` – Tuấn) để người khác gọi ngay, rồi lấp dần.
- [ ] Tạo nhánh `develop` và các nhánh `feature/*` (mục 5).

### Phase 1 – Core (làm song song)

| Trí – World & State | Uyên – Narrative | Tuấn – Gameplay & UI |
|---|---|---|
| Map thử nghiệm `test_a`, `test_b` (làm đầu tiên, cả nhóm dùng) | `QuestData`, `QuestObjective`, `QuestManager` (nhiều bước, tự kiểm tra `done_when`) | `ItemData`, `InventoryManager` (dữ liệu trong `GameState`) |
| Player `lock / unlock` theo lý do, `walk_to`, `face` | `ChapterData`, `ChapterManager`, màn hình tên chương | `Pickup`, Hạt Gió |
| `SceneManager`, `MapExit`, `Door`, fade | Autoload `Cutscene` (begin/end, fade, wait, walk, face, camera, show/hide NPC, đổi map) | `MinigameManager`, `MinigameBase`, `MinigameSpot`, chỉ số F, "Nhờ Na", minigame thử |
| `ConditionalVisibility`, `StateSwitch` | Mẫu `.dialogue` dùng `npc_get / npc_talks`, lựa chọn, `has_item` | Na đi theo (`follower.gd`, hình khối tạm) |
| `Inspect`, `UseItemTarget` | Viết `ong_noi.dialogue`, `na.dialogue`, `ch1_story.dialogue` | Toast, HUD quest, Sổ (nhiệm vụ, túi đồ, Hạt Gió, nhật ký) |
| `NpcSchedule`, `Persistent` | Câu soi đồ, câu nội tâm của Minh | Menu chính, tạm dừng, cài đặt |
| `SaveManager` (lưu / tải / tự lưu) | `data/npcs/na.tres` + dữ liệu NPC phụ | `AudioManager` |

#### Core xong khi (test trên map thử nghiệm)
- [ ] Đi giữa 2 map qua mép map và qua cửa, đúng chỗ xuất hiện, có fade.
- [ ] Soi vật → Minh nói một câu; lần hai câu khác.
- [ ] Nhặt đồ → toast → có trong Sổ → vào lại map không còn đồ đó.
- [ ] Chỗ cần dùng đồ: thiếu thì nói đúng món còn thiếu, đủ thì thành công và bật cờ.
- [ ] Quest thử nhiều bước: HUD cập nhật từng bước, xong có thưởng, gạch ngang trong Sổ.
- [ ] Một vật đổi hình, một NPC đổi chỗ / đổi câu thoại khi quest xong.
- [ ] Cutscene thử chạy từ `.dialogue`: fade, NPC đi tới marker, camera lia, đổi map.
- [ ] Minigame thử: mở từ map → thắng → về đúng chỗ, cờ bật; giữ R chơi lại ≤ 2 s; gợi ý F hiện đúng mức.
- [ ] Na tạm đi theo Minh qua 2 map.
- [ ] Xong objective chương thử → hiện tên chương mới.
- [ ] Lưu → thoát → Tiếp tục: đúng map, vị trí, cờ, túi đồ, quest, chỗ NPC.
- [ ] Tất cả làm được bằng bàn phím **và** tay cầm.

### Phase 2 – Nội dung Chương 1

| Trí | Uyên | Tuấn |
|---|---|---|
| Minigame **Câu cá**: canh thời điểm, "Nhờ Na" chỉ chỗ có cá, đủ số cá → thắng | Quest **Sửa vòi nước**: `fix_pipe.tres` (3 bước), đặt 3 `Pickup`, `UseItemTarget` ống rò, van tưới, `StateSwitch` luống rau, hội thoại Ông Nội | Minigame **Trộm dưa**: nấp sau bó rơm, hướng nhìn người trông ruộng, bị phát hiện về bó rơm gần nhất, đủ dưa → thắng |
| Dựng map Làng quê, Bờ mương, Ruộng sau nhà Na; nối map; khoá đường sang làng bằng `ch1.village_unlocked` | `chapter_01.tres`, `fishing.tres`, `melon.tres` | Na thật (sprite + follower) |
| Đặt marker, lịch NPC theo danh sách của Uyên | Cutscene gặp Na, chạy trốn khỏi ruộng dưa, kết chương | HUD / Sổ với nội dung thật; `data/items/*.tres` |
| Parallax, ánh sáng từng map; `MinigameSpot` ở Bờ mương | Câu soi đồ, câu nội tâm, nhật ký | `MinigameSpot` ở ruộng dưa |

### Phase 3 – Hoàn thiện
- [ ] Âm thanh: nhạc làng quê, ve sầu, nước, bước chân, tiếng chữ chạy, tiếng nhặt đồ (Tuấn).
- [ ] Hiệu ứng: tia nước rò, nước tưới, lấp lánh Hạt Gió.
- [ ] Cả nhóm chơi thử trọn Chương 1, sửa lỗi, kiểm tra lưu / tải.
- [ ] Build Windows.

---

## 4. Ai cần gì của ai

| Người cần | Cần từ | Thứ cần | Tạm thời khi chưa có |
|---|---|---|---|
| Uyên (quest sửa vòi) | Trí | `Inspect`, `UseItemTarget`, `StateSwitch` | Viết `.dialogue` trước, test bằng `do set_flag(...)` |
| Uyên (quest sửa vòi) | Tuấn | `InventoryManager`, `Pickup` | Dùng cờ `item.x` thay cho túi đồ |
| Uyên (Chapter, Cutscene) | Trí | `SceneManager.change_map()`, Player `lock / walk_to` | Gọi `main.load_map()` hiện có; dùng `can_move` |
| Uyên (đặt đồ vào map) | Trí | Map có `Objects`, `Collectibles`, `Markers` | Đặt trên map thử nghiệm |
| Trí (câu cá) | Tuấn | `MinigameBase`, `MinigameManager` | Làm scene độc lập, F6 để chạy; tự phát `finished(result)` |
| Tuấn (HUD, Sổ) | Uyên | `QuestData` (tên, các bước), `QuestManager.get_current_objective()` | Hiện thẳng `GameState.quests` |
| Tuấn (Na) | Trí | `SceneManager` đặt Na khi đổi map | Na là con của `World`, tự đi theo trong 1 map |
| Tuấn (Na) | Uyên | `Cutscene.walk / show_npc` | Bật Na bằng cờ `ch1.na_joined` |
| Tuấn (menu Tiếp tục) | Trí | `SaveManager.has_save / load_game / new_game` | Nút Tiếp tục ẩn |
| Trí (lịch NPC) | Uyên | NPC nào đứng đâu theo chương / buổi | Dùng `appear_condition` (đã có) |

---

## 5. Git

```text
main            ← chỉ bản chạy được (sau mỗi phase)
└── develop     ← tích hợp thường xuyên
    ├── feature/scene-manager        (Trí)
    ├── feature/world-state          (Trí)
    ├── feature/save-load            (Trí)
    ├── feature/minigame-fishing     (Trí)
    ├── feature/quest-chapter        (Uyên)
    ├── feature/cutscene             (Uyên)
    ├── feature/quest-fix-pipe       (Uyên)
    ├── feature/inventory            (Tuấn)
    ├── feature/minigame-framework   (Tuấn)
    ├── feature/ui                   (Tuấn)
    └── feature/minigame-melon       (Tuấn)
```

- Không commit thẳng lên `main`.
- Xong một mục → Pull Request vào `develop`, **người sở hữu hệ thống / thư mục review**.
- Trước khi tạo PR: kéo `develop` mới nhất, mở game chạy thử.
- **Không hai người cùng sửa một `.tscn` / `.tres`.** Muốn đặt đồ vào map của Trí: làm scene đồ vật riêng rồi báo Trí instance vào, hoặc hẹn giờ sửa.
- Mỗi tuần: gộp `develop`, cả nhóm chơi thử trọn vòng.

---

## 6. Definition of Done

| Hệ thống / nội dung | Xong khi |
|---|---|
| Mỗi hệ thống cốt lõi | Đạt mục **"Xong khi"** của hệ thống đó trong [HE_THONG.md](HE_THONG.md) |
| Quest sửa vòi (Uyên) | Chơi từ lúc nhận việc tới lúc nhận Hạt Gió; thiếu đồ nói đúng món thiếu; vòi, rau, Ông Nội đổi đúng sau quest; lưu / tải giữa chừng vẫn đúng |
| Câu cá (Trí) | Chạy riêng bằng F6; mở từ Bờ mương; thắng / thua / chơi lại ≤ 2 s; "Nhờ Na" hồi 15 s; quest `fishing` xong |
| Trộm dưa (Tuấn) | Chạy riêng bằng F6; mở từ ruộng dưa; bị phát hiện về bó rơm ≤ 2 s giữ số dưa; đủ dưa → thắng → cutscene chạy trốn; quest `melon` xong |
| Map (Trí) | Có `Bounds`, `Spawns`, `Markers`, `Exits`; camera không lộ ngoài map; nối đúng sơ đồ |

**MVP Chương 1 xong khi:** chơi liền một mạch từ Vườn rau tới kết chương, thoát giữa chừng vào lại vẫn đúng, bàn phím và tay cầm đều chơi được, không có bước nào phải chỉnh tay trong Inspector khi đang chơi.

---

## 7. Sau MVP

- **Chương 1 đầy đủ:** việc phụ dân làng, thời gian trong ngày (ngủ, đổi màu theo buổi), Góc cây đa, nhà Ông Nội.
- **Chương 0 – Mở đầu:** phòng ngủ Minh (`phong_ngu_minh.aseprite`), minigame xếp hành lý, cutscene chuyến xe về quê. Dùng lại toàn bộ core; đổi `GameState.chapter` mặc định thành 0 khi ghép.
- **Chương 2–4:** mỗi chương = map mới + `chapter_XX.tres` + `.dialogue` + quest / minigame (GDD Bảng 10), tiếp tục mỗi người một quest / minigame.
