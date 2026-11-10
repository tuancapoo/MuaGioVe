# Kiến trúc – Mùa Gió Về

Tài liệu kỹ thuật chung của cả nhóm: cách các hệ thống ghép với nhau, cấu trúc thư mục, quy ước đặt tên, cờ, signal và API. **Ai thêm autoload, signal, cờ hay đổi API phải cập nhật file này.**

- Mô tả đầy đủ từng hệ thống cốt lõi: [HE_THONG.md](HE_THONG.md)
- Kế hoạch, thứ tự làm và phân công: [KE_HOACH.md](KE_HOACH.md)

---

## 1. Bốn nguyên tắc

| Nguyên tắc | Nghĩa là |
|---|---|
| **Scene-based** | Mỗi map, nhân vật, vật thể, minigame, màn UI là một scene riêng. Không có scene "cả thế giới". |
| **Component-based** | Hành vi dùng lại được tách thành node gắn vào: `Interactable`, `Pickup`, `ConditionalVisibility`, `Persistent`… |
| **Data-driven** | Nội dung (nhân vật, hội thoại, quest, vật phẩm, chương) là **file dữ liệu** trong `data/`. Thêm nội dung = thêm file, không sửa code. |
| **Event-driven + State-driven** | Hệ thống báo cho nhau bằng signal. **Thế giới được dựng lại từ trạng thái hiện tại** trong `GameState`, không dựa vào việc "vừa xảy ra gì". |

> Ví dụ: sửa xong vòi nước → `GameState` ghi `quest fix_pipe = done`. Vòi nước, luống rau, Ông Nội, hội thoại **tự đọc** trạng thái đó mỗi khi vào map. Rời map rồi quay lại, hay thoát game vào lại, mọi thứ vẫn đúng.

---

## 2. Năm tầng

```text
┌─ 5. UI ─────────── HUD, Sổ, toast, menu, hộp thoại      (chỉ NGHE signal, đọc GameState)
├─ 4. World ──────── Main → Map → Player / Na / NPC / vật thể (ghép từ component)
├─ 3. Managers ───── SceneManager, QuestManager, InventoryManager, ChapterManager,
│                    Cutscene, MinigameManager, SaveManager, AudioManager   (autoload, chỉ có LOGIC)
├─ 2. State ──────── GameState: NGUỒN DỮ LIỆU DUY NHẤT, lưu được ra JSON
│                    EventBus: kênh sự kiện dùng chung
└─ 1. Data ───────── data/*.tres, data/dialogues/*.dialogue
```

**Quy tắc phụ thuộc**
- Tầng trên gọi xuống tầng dưới; tầng dưới chỉ **phát signal** lên.
- **Manager không giữ trạng thái**, mọi thứ cần nhớ đều ghi vào `GameState` → lưu game chỉ là lưu `GameState`.
- Manager **không bao giờ** trỏ tới một scene cụ thể (`get_node("/root/Main/World/Garden/OngNoi")` là sai).
- **Không viết logic riêng của từng quest trong code** (`if quest_id == "fix_pipe": ...`). Đối tượng tự khai báo điều kiện bằng biểu thức, ví dụ `visible_when = "is_quest_done('fix_pipe')"`.
- Không tạo `GameManager` khổng lồ; mỗi manager một việc.

### Ví dụ: nhặt đầu nối ống nước

```text
Player bấm E ─▶ Pickup.interact()
   ├─▶ InventoryManager.add_item("pipe_connector")  ─▶ GameState.inventory  ─▶ GameState.changed
   └─▶ EventBus.item_collected("pipe_connector")
           ├─▶ UI: toast "Đã nhận: Đầu nối ống"
           └─▶ QuestManager kiểm tra bước "Tìm bộ phận" của fix_pipe ─▶ EventBus.quest_changed
                                                                         └─▶ UI: HUD "Tìm bộ phận 1/3"
GameState.changed ─▶ Ông Nội, cửa, luống rau… tự cập nhật theo điều kiện của mình
SaveManager tự lưu khi đổi map / xong việc
```

---

## 3. Cây scene khi chơi

```text
Main (core/main/main.tscn)
├── World (Node2D)
│   ├── <Map hiện tại>      ← SceneManager thay map ở đây
│   ├── Player              ← sống xuyên suốt khi đổi map
│   └── Na                  ← sống xuyên suốt khi đổi map (khi đã đi theo)
├── UI (CanvasLayer)        ← HUD, Toast, Journal, PauseMenu
└── Transition (CanvasLayer)← lớp fade
```

Menu chính là scene riêng (sau này: `ui/menu/main_menu.tscn` → `core/main/main.tscn`).

---

## 4. Cấu trúc thư mục

```text
res://
├── core/                          # nền tảng dùng chung, KHÔNG chứa nội dung game
│   ├── autoload/                  # game_state, event_bus, scene_manager, save_manager, …
│   ├── components/                # interactable, conditional_visibility, persistent, …
│   └── main/                      # main.tscn – scene khởi chạy
│
├── gameplay/                      # cơ chế người chơi trực tiếp điều khiển
│   ├── player/                    # player.tscn, player.gd
│   ├── interaction/               # icon / lời nhắc tương tác
│   ├── inventory/                 # inventory_manager.gd, item_data.gd, pickup.tscn, wind_seed.tscn
│   ├── companion/                 # follower.gd – hành vi đi theo của Na
│   └── minigame/                  # minigame_manager.gd, minigame_base.gd, minigame_spot.tscn
│       ├── fishing/               # mỗi minigame một thư mục, chạy độc lập được (F6)
│       └── melon_stealth/
│
├── narrative/                     # kể chuyện
│   ├── npc/                       # npc.tscn (dùng chung), npc_data.gd, characters/<id>/
│   ├── dialogue/                  # hộp thoại (balloon) cho Dialogue Manager
│   ├── quest/                     # quest_manager.gd, quest_data.gd
│   ├── chapter/                   # chapter_manager.gd, chapter_data.gd, màn hình tên chương
│   └── cutscene/                  # cutscene.gd (lệnh gọi từ .dialogue), cảnh dùng AnimationPlayer
│
├── world/                         # không gian người chơi đi lại
│   ├── areas/                     # map_base.gd + mỗi map một thư mục: garden/, village/, canal/…
│   │   └── test/                  # map thử nghiệm cho giai đoạn Core
│   ├── transitions/               # map_exit.tscn (mép map), door.tscn (cửa)
│   └── objects/                   # vật thể trong map: inspect/, use_item/, pipe/, bed/…
│
├── ui/                            # màn hình giao diện (không gồm hộp thoại)
│   ├── hud/ (quest tracker, toast)   journal/   menu/   settings/
│   ├── transition/   chapter_title/   theme/ (main_theme.tres – font VT323)
│
├── data/                          # NỘI DUNG GAME – thêm nội dung chủ yếu ở đây
│   ├── npcs/                      # <id>.tres (NpcData): tên, màu thoại, sprite, file hội thoại
│   ├── dialogues/                 # <id>.dialogue (Dialogue Manager)
│   ├── quests/                    # <id>.tres (QuestData)
│   ├── items/                     # <id>.tres (ItemData)
│   └── chapters/                  # chapter_01.tres (ChapterData)
│
├── assets/                        # chỉ tài nguyên, không có code
│   ├── characters/<id>/           # minh/, ong_noi/, an/ (.aseprite)
│   ├── maps/                      # <map>.aseprite
│   │   └── layers/<map>/          # texture tách layer do AsepriteWizard sinh ra – KHÔNG sửa tay
│   ├── ui/  fonts/  objects/  environment/  effects/  tilesets/  palette/
│   ├── audio/bgm/  audio/sfx/
│   └── _reference/                # asset tham khảo; có .gdignore nên Godot bỏ qua
│
├── addons/                        # AsepriteWizard, dialogue_manager – không sửa
└── docs/                          # KIEN_TRUC.md, KE_HOACH.md
```

**Đặt file ở đâu?**

| Bạn đang làm | Đặt ở |
|---|---|
| Script / scene dùng cho mọi chỗ, không gắn nội dung cụ thể | `core/` |
| Thứ người chơi điều khiển trực tiếp (nhân vật, túi đồ, minigame) | `gameplay/` |
| Nhân vật, hội thoại, quest, chương, cutscene (phần code) | `narrative/` |
| Map và đồ vật đặt trong map | `world/` |
| Màn hình giao diện | `ui/` |
| Nội dung: thêm NPC, câu thoại, quest, vật phẩm | `data/` |
| Hình, âm thanh, font | `assets/` |

**Không có** thư mục `save/` trong project: file save ghi vào `user://save.json`, cài đặt vào `user://settings.cfg` (`res://` là chỉ đọc khi export).

---

## 5. Quy ước đặt tên

| Loại | Quy ước | Ví dụ |
|---|---|---|
| Thư mục, file (code, scene, asset) | `snake_case`, **không dấu, không khoảng trắng** | `ong_noi_idle.aseprite`, `quest_manager.gd` |
| `class_name`, tên node | `PascalCase` | `NpcData`, `PlayerSpawn` |
| Biến, hàm | `snake_case` | `can_move`, `place_player()` |
| Hằng số | `UPPER_SNAKE_CASE` | `SPEAKER_GROUP` |
| Signal | `snake_case`, thì quá khứ | `item_collected`, `map_changed` |
| id dữ liệu (`npc_id`, `quest_id`, `item_id`, `map_id`) | `snake_case`, trùng tên file trong `data/` | `ong_noi`, `fix_pipe`, `pipe_connector`, `garden` |
| Layer trong file Aseprite của map | `NN_Ten_layer` (số thứ tự trước) | `01_Bau_troi`, `11_Co_tien_canh` |
| Animation | `PascalCase` | `Idle`, `Walk`, `Run` |

> **Đổi tên / di chuyển file luôn làm trong Godot editor** (FileSystem → chuột phải → Rename / Move To). Làm bằng Explorer sẽ gãy tham chiếu trong scene.

---

## 6. Trạng thái: `GameState`

`GameState` (autoload) là **nơi duy nhất** giữ tiến trình. File: `core/autoload/game_state.gd`.

| Dữ liệu | Kiểu | Ví dụ |
|---|---|---|
| `chapter`, `day`, `time_of_day` | int / enum | `1`, `2`, `MORNING` |
| `current_map` | String | `"garden"` |
| `flags` | Dictionary | `{"ch1.pipe_fixed": true, "npc.ong_noi.talks": 3}` |
| `quests` | Dictionary | `{"fix_pipe": "active"}` |
| `wind_seeds` | int | `7` |
| *(sẽ thêm)* `inventory` | Dictionary | `{"pipe_connector": 1}` |

### 6.1. Quy ước cờ

| Mẫu | Ví dụ | Ý nghĩa |
|---|---|---|
| `chN.<sự_kiện>` | `ch1.pipe_fixed`, `ch1.na_joined`, `ch1.village_unlocked` | Sự kiện cốt truyện trong chương N |
| `seed.<map>_<số>` | `seed.garden_01` | Đã nhặt Hạt Gió |
| `seen.<id>` | `seen.mango_tree` | Đã soi / đã xem |
| `npc.<id>.<key>` | `npc.ong_noi.talks`, `npc.na.location` | Trạng thái NPC (`talks` NPC tự cộng) |
| `world.<map>.<id>.<key>` | `world.garden.crate_1.position` | Vật thể có trạng thái riêng (`Persistent`) |

**Danh sách cờ của từng chương nằm trong [KE_HOACH.md](KE_HOACH.md). Thêm cờ mới phải báo người giữ danh sách.**

### 6.2. Hàm có sẵn (gọi được cả trong code lẫn trong `.dialogue`)

```gdscript
# Cờ
has_flag(key) / get_flag(key, default) / set_flag(key, value = true) / add_flag(key, amount = 1)
# NPC
npc_get(id, key, default) / npc_set(id, key, value) / npc_talks(id)
# Quest
quest_state(id) / is_quest_new(id) / is_quest_active(id) / is_quest_done(id)
start_quest(id) / complete_quest(id)
# Thời gian
time  # "morning" / "noon" / "evening"
advance_time() / sleep()
# Phần thưởng
add_wind_seeds(amount)
# Điều kiện dạng chữ (cho appear_condition, cửa, visible_when…)
check("chapter == 1 and is_quest_done('fix_pipe')")
```

### 6.3. Vị trí NPC: lưu **chỗ đứng**, không lưu toạ độ
- Mỗi map có các `Marker2D` đặt tên làm chỗ đứng: `porch`, `garden_bed`…
- *(sẽ làm)* `NpcSchedule`: danh sách `{ when, map, marker }`, xét từ trên xuống, dòng khớp đầu tiên thắng.
- Kịch bản dời chỗ: `npc_set("na", "location", "canal/sitting_spot")` (ưu tiên hơn lịch).
- Hiện tại: dùng `appear_condition` trên từng instance NPC.

### 6.4. Hội thoại nhớ gì
| Cần nhớ | Cách viết trong `.dialogue` |
|---|---|
| Đoạn đã nghe | `do npc_set("ong_noi", "heard_intro", true)` / `if not npc_get("ong_noi", "heard_intro", false)` |
| Đổi câu theo số lần nói | `if npc_talks("ong_noi") >= 3:` |
| Lựa chọn của người chơi | `do set_flag("ch1.asked_grandpa_past")` |
| Câu rảnh ngẫu nhiên | Dòng bắt đầu bằng `%` (không cần lưu) |

---

## 7. Autoload

| Autoload | File | Trạng thái | Việc |
|---|---|---|---|
| `EventBus` | `core/autoload/event_bus.gd` | ✅ | Signal sự kiện dùng chung |
| `GameState` | `core/autoload/game_state.gd` | ✅ | Toàn bộ trạng thái |
| `DialogueManager` | `addons/dialogue_manager/` | ✅ | Chạy file `.dialogue` (addon) |
| `SceneManager` | `core/autoload/scene_manager.gd` | ⬜ | Đổi map có fade, đặt Player ở marker |
| `SaveManager` | `core/autoload/save_manager.gd` | ⬜ | Lưu / tải `GameState` ↔ `user://save.json` |
| `InventoryManager` | `gameplay/inventory/inventory_manager.gd` | ⬜ | Thêm / bớt / kiểm tra vật phẩm (ghi vào GameState) |
| `QuestManager` | `narrative/quest/quest_manager.gd` | ⬜ | Đọc `QuestData`, theo dõi bước, hoàn thành |
| `ChapterManager` | `narrative/chapter/chapter_manager.gd` | ⬜ | Bắt đầu / kết thúc chương |
| `Cutscene` | `narrative/cutscene/cutscene.gd` | ⬜ | Lệnh dàn cảnh gọi từ `.dialogue` |
| `MinigameManager` | `gameplay/minigame/minigame_manager.gd` | ⬜ | Mở minigame, nhận kết quả, quay về map |
| `AudioManager` | `core/autoload/audio_manager.gd` | ⬜ | Nhạc nền, SFX |

**Thứ tự trong `project.godot`:** `EventBus` → `GameState` → các manager → `DialogueManager`.

---

## 8. Signal (`EventBus`)

```gdscript
signal interacted(target: Node)                              # ✅ Player phát
signal item_collected(item_id: StringName)                   # InventoryManager phát
signal item_removed(item_id: StringName)                     # InventoryManager phát
signal quest_changed(quest_id: String, state: String)        # ✅ GameState phát
signal map_changed(map_id: String)                           # ✅ GameMap phát
signal minigame_finished(minigame_id: String, result: Dictionary)  # MinigameManager phát
signal toast_requested(text: String)                         # ai cũng phát được
```

Ngoài ra: `GameState.changed` (mọi thay đổi trạng thái), `DialogueManager.dialogue_started / dialogue_ended`.

**Sự kiện** ("vừa xảy ra") đi qua `EventBus`. **Trạng thái** ("đang là gì") đọc từ `GameState`.

---

## 9. API đã thống nhất

```gdscript
# Đổi map
SceneManager.change_map("village", "from_garden")      # map_id, tên Marker2D

# Túi đồ
InventoryManager.add_item("pipe_connector", 1)
InventoryManager.has_item("pipe_connector", 1)
InventoryManager.remove_item("pipe_connector", 1)
InventoryManager.count_of(["pipe_connector", "rubber_ring", "pipe_clamp"])

# Quest (dữ liệu trong data/quests/<id>.tres)
QuestManager.start_quest("fix_pipe")
QuestManager.update_objective("fix_pipe", "connector")
QuestManager.can_complete("fix_pipe")
QuestManager.complete_quest("fix_pipe")

# Minigame — chỉ TRẢ KẾT QUẢ, không tự đổi chương / tự xong quest
MinigameManager.start("fishing", {"location": "canal"})
# → EventBus.minigame_finished("fishing", {"success": true, "score": 80, "item_id": "fish", "amount": 1})

# Lưu game
SaveManager.save_game() / SaveManager.load_game() / SaveManager.has_save() / SaveManager.autosave()

# Player
player.lock("cutscene") / player.unlock("cutscene")

# Cutscene (gọi từ .dialogue bằng do) – danh sách lệnh: HE_THONG.md mục 8
Cutscene.begin() / Cutscene.walk("Na", "fence") / Cutscene.fade_out(0.5) / Cutscene.end()
```

---

## 10. Thành phần đã có

| Thành phần | File | Ghi chú |
|---|---|---|
| Player | `gameplay/player/` | Đi, chạy, camera, chọn vật tương tác gần nhất, khoá khi thoại; tên/màu thoại lấy từ `data/npcs/minh.tres` |
| `Interactable` | `core/components/interactable.gd` | Area2D layer 4; `prompt_text`, `enabled`, signal `interacted` |
| Icon tương tác | `gameplay/interaction/` | Dấu hỏi nổi trên vật gần nhất |
| NPC dùng chung | `narrative/npc/npc.tscn` | Gán `data` (NpcData) + `appear_condition`; tự đếm `npc.<id>.talks` |
| `NpcData` | `narrative/npc/npc_data.gd` | `NpcData.find_by_name("Ông Nội")` cho nhân vật không có trong scene |
| Hộp thoại | `narrative/dialogue/` | Khung `dialogue_box.aseprite`, đuôi chỉ người nói, đổi màu viền theo nhân vật |
| `GameMap` | `world/areas/map_base.gd` | `map_id`, `map_size`, `PlayerSpawn`, giới hạn camera |
| Map Vườn rau | `world/areas/garden/` | 11 layer AsepriteWizard; mây, cây hậu cảnh, cỏ tiền cảnh dùng `Parallax2D` |

---

## 11. Asset & AsepriteWizard

- File `.aseprite` import thẳng bằng AsepriteWizard; sửa trong Aseprite → Godot tự import lại.
- **Nhân vật:** importer *SpriteFrames*, cần tag `Idle` / `Walk` / `Run`.
- **Map:** importer *Texture (Split By Layer)*, `output/layers_resources_folder = res://assets/maps/layers/<map>`; mỗi layer thành một texture.
- **Plugin PixelLab trong Aseprite** in lỗi Lua lẫn vào kết quả dòng lệnh → mọi file import kiểu *Split By Layer* phải đặt `layer/exclude_layers_pattern = "lua:[0-9]+:"` (hoặc tắt plugin đó).
- **Parallax:** dùng node `Parallax2D` (Inspector: `scroll_scale`, `repeat_size`, `autoscroll`), **không viết script parallax riêng cho từng map**.

---

## 12. Lưu ý kỹ thuật

- Sửa file `.dialogue` xong phải để Godot import lại (mở editor là tự làm).
- **Không đặt biến trong scene trùng tên biến của `GameState`** (`current_map`, `chapter`, `time`…): Dialogue Manager sẽ đọc nhầm biến của scene.
- Tên nhân vật trong `.dialogue` phải trùng `display_name` trong `data/npcs/<id>.tres`.
- Không hai người cùng sửa một file `.tscn` / `.tres` một lúc; muốn đặt đồ vào map của người khác thì làm scene riêng rồi instance vào.
