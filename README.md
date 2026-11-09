# Mùa Gió Về

## Yêu cầu

Xem [REQUIREMENTS.md](REQUIREMENTS.md) để biết các yêu cầu chạy dự án.

## 1. Giới thiệu

**Mùa Gió Về** là game 2D tập trung vào khám phá thế giới, tương tác với NPC, thực hiện nhiệm vụ (Quest) và tham gia các hoạt động nhỏ (Minigame).

Người chơi sẽ di chuyển qua các khu vực trong game, gặp gỡ các nhân vật, trò chuyện, nhận nhiệm vụ, thu thập vật phẩm và tham gia các hoạt động để khám phá câu chuyện.

### Gameplay Loop

```text
Explore Map
    ↓
Find NPC / Objects
    ↓
Interact / Dialogue
    ↓
Receive Quest / Minigame
    ↓
Explore / Collect / Play
    ↓
Complete Objective
    ↓
Receive Reward
    ↓
Continue Exploring
```

## 2. Cấu trúc tổng quan

```text
MuaGioVe/
│
├── assets/
│
├── scenes/
│   ├── main/
│   ├── player/
│   ├── companion/
│   ├── world/
│   ├── npc/
│   ├── interaction/
│   ├── narrative/
│   ├── quests/
│   ├── minigames/
│   ├── ui/
│   └── common/
│
├── scripts/
│   ├── autoload/
│   ├── components/
│   ├── systems/
│   └── utilities/
│
├── resources/
│   ├── characters/
│   ├── dialogues/
│   ├── quests/
│   ├── minigames/
│   ├── items/
│   ├── rewards/
│   ├── chapters/
│   └── achievements/
│
├── data/
│   ├── save/
│   └── config/
│
├── addons/
│
├── project.godot
└── README.md
```

---

# 3. Giải thích chi tiết

## 3.1. `assets/` – Tài nguyên của game

Chứa các file hình ảnh, âm thanh, font chữ và những tài nguyên được sử dụng trong game.

```text
assets/
├── characters/
│   ├── minh/
│   ├── be_na/
│   ├── npc/
│   └── animals/
│
├── environment/
│   ├── village/
│   ├── garden/
│   ├── forest/
│   ├── riverside/
│   ├── school/
│   └── interiors/
│
├── objects/
│   ├── furniture/
│   ├── collectibles/
│   ├── quest_items/
│   └── minigame_objects/
│
├── tilesets/
├── ui/
│   ├── icons/
│   ├── buttons/
│   └── panels/
│
├── effects/
├── audio/
│   ├── bgm/
│   └── sfx/
│
└── fonts/
```

| Thư mục | Chức năng |
|---|---|
| `characters/` | Sprite và animation của nhân vật, NPC, động vật. |
| `environment/` | Hình ảnh cảnh vật, cây cối, nhà cửa và môi trường từng khu vực. |
| `objects/` | Đồ vật xuất hiện trong thế giới game. |
| `tilesets/` | Tile texture và tài nguyên dùng để xây dựng bản đồ. |
| `ui/` | Hình ảnh giao diện, icon, button và panel. |
| `effects/` | Hiệu ứng hình ảnh như bụi, ánh sáng, gió. |
| `audio/bgm/` | Nhạc nền. |
| `audio/sfx/` | Âm thanh tương tác, bước chân, vật phẩm và hiệu ứng. |
| `fonts/` | Font chữ sử dụng trong game. |

**Nguyên tắc:** `assets/` chỉ chứa tài nguyên, không chứa code xử lý gameplay.

Ví dụ: Sprite của Minh nằm trong `assets/characters/minh/`, còn scene điều khiển Minh nằm trong `scenes/player/`.

## 3.2. `scenes/` – Các Scene của Godot

Chứa các scene `.tscn` và script gắn trực tiếp với từng scene.

Đây là nơi tổ chức các thành phần có thể xuất hiện hoặc được sử dụng trong game.

### `scenes/main/` – Scene chính

```text
main/
├── main.tscn
└── main.gd
```

Chứa scene khởi chạy game và điều phối các thành phần chính.

Ví dụ:
- Khởi tạo các hệ thống cần thiết.
- Hiển thị bản đồ hiện tại.
- Quản lý giao diện chính.
- Kết nối các thành phần trong game.

### `scenes/player/` – Nhân vật người chơi

```text
player/
├── player.tscn
└── player.gd
```

Chứa scene và code điều khiển nhân vật chính.

Các chức năng:
- Di chuyển trái, phải, lên, xuống.
- Chạy và tương tác với môi trường.
- Animation idle, walk, run.
- Xử lý va chạm.
- Tương tác với NPC và đồ vật.

Ví dụ cấu trúc node:

```text
Player (CharacterBody2D)
├── AnimatedSprite2D
├── CollisionShape2D
├── InteractionArea (Area2D)
└── Camera2D
```

### `scenes/companion/` – Nhân vật đồng hành

```text
companion/
└── be_na/
    ├── be_na.tscn
    └── be_na.gd
```

Chứa các nhân vật đồng hành như Bé Na.

Các chức năng:
- Di chuyển theo người chơi.
- Animation riêng.
- Hỗ trợ người chơi trong một số hoạt động.
- Đưa ra gợi ý khi cần thiết.

### `scenes/world/` – Thế giới và bản đồ

```text
world/
├── maps/
│   ├── village/
│   ├── garden/
│   ├── forest/
│   ├── riverside/
│   └── school/
│
├── objects/
│   ├── doors/
│   ├── collectibles/
│   └── environmental_objects/
│
└── transitions/
```

Đây là nơi xây dựng thế giới mà người chơi có thể tự do khám phá.

| Thư mục | Chức năng |
|---|---|
| `maps/` | Các bản đồ và khu vực trong game. |
| `objects/` | Những vật thể có thể xuất hiện trong bản đồ. |
| `transitions/` | Scene hoặc thành phần chuyển đổi giữa các khu vực. |

Ví dụ một map:

```text
Garden (Node2D)
├── TileMapLayer
├── PlayerSpawn
├── NPCs
│   └── GrandmaSau
├── Objects
│   ├── WaterPipe
│   └── GardenTools
├── Collectibles
└── MapTransitions
```

**Lưu ý:** Các hoạt động tìm đồ, tương tác với môi trường và một số nhiệm vụ có thể diễn ra trực tiếp trong map, không nhất thiết phải chuyển sang một scene minigame riêng.

### `scenes/npc/` – Nhân vật NPC

```text
npc/
├── base/
│   ├── npc.tscn
│   └── npc.gd
│
└── characters/
    ├── ba_sau/
    ├── chu_muoi/
    └── be_tam/
```

Chứa các nhân vật NPC xuất hiện trong game.

- `base/`: Scene NPC dùng chung.
- `characters/`: Scene hoặc cấu hình riêng cho từng NPC.

Các chức năng:
- Hiển thị nhân vật và animation.
- Nhận tương tác từ người chơi.
- Hiển thị dấu hiệu có thể tương tác.
- Kích hoạt hội thoại.
- Cung cấp thông tin về nhiệm vụ hoặc hoạt động liên quan.

NPC không nên tự xử lý toàn bộ logic Quest. Việc quản lý tiến trình nhiệm vụ thuộc về Quest System.

### `scenes/interaction/` – Hệ thống tương tác

```text
interaction/
├── interaction_area.tscn
└── interaction_prompt.tscn
```

Chứa các scene phục vụ tương tác giữa người chơi và thế giới.

Ví dụ:
- Phát hiện NPC trong phạm vi tương tác.
- Phát hiện vật phẩm có thể nhặt.
- Hiển thị thông báo nhấn phím tương tác.
- Kích hoạt hành động khi người chơi nhấn phím.

Ví dụ: Khi Minh đứng gần bà Sáu, `InteractionArea` phát hiện NPC và hiển thị lời nhắc tương tác.

### `scenes/narrative/` – Nội dung kể chuyện

```text
narrative/
├── dialogue/
├── cutscenes/
└── endings/
```

Narrative là phần kể chuyện và dẫn dắt cốt truyện của game.

| Thư mục | Chức năng |
|---|---|
| `dialogue/` | Scene hiển thị hội thoại giữa các nhân vật. |
| `cutscenes/` | Các phân cảnh kể chuyện, sự kiện đặc biệt. |
| `endings/` | Các phân cảnh kết thúc game. |

Ví dụ:
- Cảnh Minh chuẩn bị về quê.
- Cuộc gặp gỡ đầu tiên với bà Sáu.
- Hội thoại giữa Minh và các NPC.
- Các sự kiện mở đầu hoặc kết thúc chương.

Narrative không phải một hệ thống gameplay độc lập. Nội dung câu chuyện sẽ được triển khai thông qua Dialogue, Cutscene và Progression System.

### `scenes/quests/` – Giao diện nhiệm vụ

```text
quests/
├── quest_log.tscn
├── quest_tracker.tscn
└── quest_notification.tscn
```

Chứa các scene giao diện liên quan đến nhiệm vụ.

| Scene | Chức năng |
|---|---|
| `quest_log.tscn` | Danh sách các nhiệm vụ người chơi đã nhận. |
| `quest_tracker.tscn` | Hiển thị mục tiêu nhiệm vụ hiện tại trên màn hình. |
| `quest_notification.tscn` | Thông báo khi nhận hoặc hoàn thành nhiệm vụ. |

**Phân biệt:** `scenes/quests/` chứa giao diện Quest, còn logic quản lý nhiệm vụ nằm trong `scripts/systems/quest/`.

### `scenes/minigames/` – Các hoạt động và minigame

```text
minigames/
├── chapter_00/
│   └── packing/
│
├── chapter_01/
│   ├── pipe_repair/
│   ├── fishing/
│   └── melon_stealth/
│
├── chapter_02/
│   ├── village_exploration/
│   ├── baking/
│   ├── delivery/
│   └── kite_rescue/
│
├── chapter_03/
│   ├── old_stories/
│   ├── quiz/
│   └── school_event/
│
└── chapter_04/
    ├── making_cakes/
    ├── lanterns/
    ├── kite_repair/
    ├── kite_flying/
    └── boat/
```

Chứa các scene và code triển khai gameplay riêng của từng hoạt động.

Ví dụ:
- `pipe_repair/`: Tìm và lắp ráp các bộ phận để sửa vòi nước.
- `fishing/`: Hoạt động câu cá.
- `baking/`: Điều chỉnh nhiệt độ lò nướng.
- `delivery/`: Giao đồ cho các nhân vật.
- `kite_flying/`: Hoạt động thả diều.

Mỗi minigame có thể có cấu trúc riêng:

```text
pipe_repair/
├── pipe_repair.tscn
├── pipe_repair.gd
└── components/
```

**Lưu ý quan trọng:** Không phải mọi Quest đều là Minigame. Ví dụ nhiệm vụ sửa vòi nước có thể diễn ra ngay trong bản đồ vườn rau: người chơi tìm các bộ phận, sau đó tương tác để lắp ráp. Nếu có một cơ chế lắp ráp riêng, phần cơ chế đó có thể được tổ chức trong `pipe_repair/`.

### `scenes/ui/` – Giao diện người dùng

```text
ui/
├── menus/
├── hud/
├── dialogue/
├── inventory/
├── quest/
├── collection/
└── settings/
```

Chứa các thành phần giao diện hiển thị trong game.

| Thư mục | Chức năng |
|---|---|
| `menus/` | Main Menu, Pause Menu. |
| `hud/` | Giao diện hiển thị thông tin trong khi chơi. |
| `dialogue/` | Khung hội thoại. |
| `inventory/` | Giao diện túi đồ. |
| `quest/` | Giao diện danh sách và mục tiêu nhiệm vụ. |
| `collection/` | Giao diện bộ sưu tập vật phẩm. |
| `settings/` | Cài đặt âm thanh, điều khiển và các tùy chọn khác. |

### `scenes/common/` – Scene dùng chung

```text
common/
├── item/
├── reward/
└── feedback/
```

Chứa các scene nhỏ có thể tái sử dụng ở nhiều nơi.

Ví dụ:
- Scene hiển thị vật phẩm.
- Scene hiển thị phần thưởng.
- Hiệu ứng thông báo thành công hoặc thất bại.

---

## 3.3. `scripts/` – Code xử lý logic game

Chứa các file GDScript xử lý gameplay và quản lý hệ thống.

```text
scripts/
├── autoload/
├── components/
├── systems/
└── utilities/
```

### `scripts/autoload/` – Các hệ thống toàn cục

```text
autoload/
├── game_state.gd
├── scene_manager.gd
├── save_manager.gd
├── event_bus.gd
└── audio_manager.gd
```

Đây là các hệ thống có thể được truy cập từ nhiều scene khác nhau thông qua Autoload trong Godot.

| Script | Chức năng |
|---|---|
| `game_state.gd` | Lưu trạng thái chung của game trong phiên chơi. |
| `scene_manager.gd` | Quản lý chuyển đổi scene và bản đồ. |
| `save_manager.gd` | Lưu và tải tiến trình game. |
| `event_bus.gd` | Quản lý các signal dùng để giao tiếp giữa những hệ thống. |
| `audio_manager.gd` | Quản lý nhạc nền và hiệu ứng âm thanh. |

Không nên đưa tất cả logic gameplay vào Autoload. Chỉ nên đặt các hệ thống thực sự cần dùng toàn cục ở đây.

### `scripts/components/` – Các thành phần có thể tái sử dụng

```text
components/
├── movement_component.gd
├── animation_component.gd
├── interaction_component.gd
├── health_component.gd
└── physics_component.gd
```

Chứa các đoạn logic nhỏ, có thể gắn vào nhiều scene khác nhau.

Ví dụ:
- `movement_component.gd`: Logic di chuyển dùng chung.
- `animation_component.gd`: Hỗ trợ quản lý animation.
- `interaction_component.gd`: Xử lý tương tác.
- `physics_component.gd`: Xử lý các hành vi vật lý dùng chung.

Không bắt buộc mọi nhân vật phải sử dụng toàn bộ components. Chỉ sử dụng khi thực sự cần thiết.

### `scripts/systems/` – Logic của các hệ thống gameplay

```text
systems/
├── quest/
│   ├── quest_manager.gd
│   └── quest_objective.gd
│
├── dialogue/
│   └── dialogue_manager.gd
│
├── progression/
│   └── progression_manager.gd
│
├── inventory/
│   └── inventory_manager.gd
│
├── collectibles/
│   └── wind_seed_manager.gd
│
├── hints/
│   └── hint_manager.gd
│
└── companion/
    └── companion_manager.gd
```

Đây là nơi chứa logic nghiệp vụ của các hệ thống chính.

| Hệ thống | Chức năng |
|---|---|
| Quest | Quản lý nhiệm vụ, mục tiêu và trạng thái hoàn thành. |
| Dialogue | Quản lý nội dung và tiến trình hội thoại. |
| Progression | Quản lý tiến trình chương và các sự kiện mở khóa. |
| Inventory | Quản lý vật phẩm người chơi thu thập được. |
| Collectibles | Quản lý vật phẩm sưu tầm như Wind Seeds. |
| Hints | Quản lý gợi ý cho người chơi. |
| Companion | Quản lý hành vi và khả năng hỗ trợ của Bé Na. |

Ví dụ về cách phối hợp giữa các hệ thống:

Khi người chơi nhặt được một bộ phận vòi nước:

1. `InventoryManager` cập nhật vật phẩm.
2. `QuestManager` cập nhật mục tiêu tìm vật phẩm.
3. Khi đủ vật phẩm, người chơi có thể thực hiện thao tác sửa vòi nước.
4. Khi sửa thành công, hệ thống nhiệm vụ nhận sự kiện và cập nhật trạng thái.
5. `ProgressionManager` có thể mở khóa sự kiện tiếp theo.

### `scripts/utilities/` – Các hàm hỗ trợ

```text
utilities/
├── constants.gd
└── helpers.gd
```

Chứa các hàm và hằng số dùng chung.

- `constants.gd`: Các hằng số như tên nhóm, trạng thái hoặc giá trị cố định.
- `helpers.gd`: Những hàm tiện ích không thuộc riêng một hệ thống nào.

---

## 3.4. `resources/` – Dữ liệu tĩnh của game

```text
resources/
├── characters/
├── dialogues/
├── quests/
│   ├── main_quests/
│   └── side_quests/
│
├── minigames/
│   └── minigame_definitions/
│
├── items/
├── rewards/
├── chapters/
└── achievements/
```

Chứa các file Resource của Godot, thường là `.tres`, dùng để lưu dữ liệu và cấu hình.

Mục đích là tách dữ liệu ra khỏi code để có thể chỉnh sửa nội dung mà không cần thay đổi logic xử lý.

| Thư mục | Chức năng |
|---|---|
| `characters/` | Dữ liệu nhân vật, NPC. |
| `dialogues/` | Nội dung hội thoại. |
| `quests/main_quests/` | Dữ liệu nhiệm vụ chính. |
| `quests/side_quests/` | Dữ liệu nhiệm vụ phụ. |
| `minigames/` | Thông tin và cấu hình minigame. |
| `items/` | Dữ liệu vật phẩm. |
| `rewards/` | Dữ liệu phần thưởng. |
| `chapters/` | Dữ liệu và cấu hình các chương. |
| `achievements/` | Dữ liệu thành tựu. |

Ví dụ:

```text
resources/quests/side_quests/
└── fix_garden_pipe.tres
```

File này có thể chứa:

- ID nhiệm vụ.
- Tên nhiệm vụ.
- Mô tả.
- Danh sách mục tiêu.
- Phần thưởng.
- Điều kiện mở khóa.

Trong khi đó, `quest_manager.gd` chịu trách nhiệm đọc dữ liệu và xử lý tiến trình nhiệm vụ.

**Phân biệt:**

- `resources/`: Dữ liệu thiết kế được chuẩn bị trước.
- `scripts/systems/`: Code xử lý dữ liệu.
- `scenes/`: Thành phần trực quan và gameplay.

---

## 3.5. `data/` – Dữ liệu phát sinh khi chạy game

```text
data/
├── save/
└── config/
```

Chứa dữ liệu lưu tiến trình và cấu hình của game.

| Thư mục | Chức năng |
|---|---|
| `save/` | Dữ liệu save game của người chơi. |
| `config/` | Các cấu hình được lưu trong quá trình sử dụng. |

Ví dụ:
- Vị trí hiện tại của người chơi.
- Nhiệm vụ đã hoàn thành.
- Vật phẩm đã thu thập.
- Chương đã mở khóa.
- Cài đặt âm lượng.

Lưu ý: Đây là thư mục dành cho dữ liệu runtime. Các file save cá nhân không nên được đưa lên Git.

## 3.6. `addons/` – Plugin của Godot

Chứa các plugin được cài đặt và sử dụng trong project.

Ví dụ:
- Plugin hỗ trợ quản lý hội thoại.
- Plugin hỗ trợ chỉnh sửa animation.
- Plugin hỗ trợ công cụ phát triển.

Không cần tự tạo plugin nếu project chưa sử dụng.

## 3.7. `project.godot` – File cấu hình project

Đây là file cấu hình chính của Godot.

Nó chứa:
- Tên project.
- Main Scene.
- Input Map.
- Cấu hình cửa sổ game.
- Renderer.
- Autoload.
- Các thiết lập khác.

Không nên chỉnh sửa tùy tiện nếu chưa hiểu cấu hình liên quan.

## 3.8. `README.md` – Tài liệu project

Chứa thông tin giới thiệu project, cấu trúc thư mục, hướng dẫn cài đặt, cách chạy game và quy định làm việc nhóm.

---

# 4. Phân biệt các thành phần quan trọng

Một số thư mục có tên hoặc chức năng khá gần nhau. Cần phân biệt rõ để tránh đặt nhầm code.

| Thành phần | Nơi lưu | Vai trò |
|---|---|---|
| NPC Scene | `scenes/npc/` | Hiển thị và xử lý nhân vật NPC. |
| Dialogue Scene | `scenes/narrative/dialogue/` | Hiển thị hội thoại. |
| Dialogue Data | `resources/dialogues/` | Nội dung hội thoại. |
| Dialogue Manager | `scripts/systems/dialogue/` | Quản lý logic hội thoại. |
| Quest UI | `scenes/quests/` | Hiển thị nhiệm vụ. |
| Quest Data | `resources/quests/` | Dữ liệu nhiệm vụ. |
| Quest Manager | `scripts/systems/quest/` | Quản lý tiến trình nhiệm vụ. |
| Minigame Scene | `scenes/minigames/` | Triển khai gameplay của minigame. |
| Minigame Data | `resources/minigames/` | Cấu hình minigame. |
| Player Scene | `scenes/player/` | Scene nhân vật chính. |
| Player Assets | `assets/characters/` | Hình ảnh và âm thanh của nhân vật. |

# 5. Quy tắc tổ chức code

Để project dễ bảo trì và tránh xung đột khi làm việc nhóm, cần tuân thủ một số quy tắc:

### 5.1. Không đặt tất cả code vào một file

Ví dụ không nên để toàn bộ logic di chuyển, nhiệm vụ, hội thoại và inventory trong `main.gd`.

Mỗi hệ thống nên chịu trách nhiệm cho một nhóm chức năng cụ thể.

### 5.2. Tách dữ liệu và logic

Ví dụ với nhiệm vụ sửa vòi nước:

```text
resources/
└── quests/
    └── side_quests/
        └── fix_garden_pipe.tres

scripts/
└── systems/
    └── quest/
        └── quest_manager.gd

scenes/
├── quests/
│   └── quest_tracker.tscn
│
├── world/
│   └── maps/
│       └── garden/
│
└── minigames/
    └── chapter_01/
        └── pipe_repair/
```

- Resource chứa thông tin nhiệm vụ.
- QuestManager quản lý tiến trình.
- Garden chứa môi trường và các vật thể trong bản đồ.
- Pipe Repair chứa cơ chế lắp ráp nếu hoạt động đó cần gameplay riêng.
- Quest Tracker hiển thị mục tiêu cho người chơi.

### 5.3. Ưu tiên sử dụng Signal để giao tiếp giữa các hệ thống

Ví dụ khi minigame sửa vòi nước hoàn thành, minigame phát ra signal:

```gdscript
signal repair_completed
```

Quest System lắng nghe sự kiện này để cập nhật nhiệm vụ.

Cách này giúp Minigame không cần phụ thuộc trực tiếp vào QuestManager.

### 5.4. Đặt tên thống nhất

- Folder và file: `snake_case`.
- Class hoặc tên node: `PascalCase`.
- Biến và hàm: `snake_case`.
- Hằng số: `UPPER_SNAKE_CASE`.

Ví dụ:

```text
fix_garden_pipe.tscn
quest_manager.gd
dialogue_manager.gd
```

---

# 6. Phân chia công việc cho nhóm 3 người

Để hạn chế việc nhiều thành viên chỉnh sửa cùng một file, có thể phân chia theo từng nhóm chức năng:

| Thành viên | Phụ trách | Thư mục chính |
|---|---|---|
| Người 1 | Player, World, Map, NPC Interaction | `scenes/player/`, `scenes/world/`, `scenes/interaction/` |
| Người 2 | NPC, Dialogue, Quest, Narrative | `scenes/npc/`, `scenes/narrative/`, `scenes/quests/`, `scripts/systems/quest/`, `scripts/systems/dialogue/` |
| Người 3 | Minigame, Physics, Gameplay Mechanics | `scenes/minigames/`, `resources/minigames/`, các components liên quan |

Các thành viên cần phối hợp khi tích hợp:
- `main/`
- `autoload/`
- `resources/`
- `assets/`
- `project.godot`

Trước khi tích hợp một tính năng, cần thống nhất cách giao tiếp giữa các hệ thống, đặc biệt là tên signal, dữ liệu đầu vào và kết quả đầu ra.

---

# 7. Lưu ý khi phát triển project

Cấu trúc trên là cấu trúc mục tiêu để tổ chức toàn bộ project, không có nghĩa là phải tạo và triển khai tất cả thư mục ngay từ đầu.

Nên phát triển theo từng giai đoạn:

1. Tạo Main Scene và Player.
2. Xây dựng bản đồ và hệ thống di chuyển.
3. Thêm NPC và cơ chế tương tác.
4. Xây dựng Dialogue System.
5. Xây dựng Quest System.
6. Thêm Inventory và Collectibles.
7. Hoàn thiện minigame đầu tiên: Sửa vòi nước.
8. Xây dựng các minigame tiếp theo.
9. Thêm Progression, Reward và Save/Load.
10. Hoàn thiện UI, âm thanh và hiệu ứng.

Chỉ tạo những thư mục cần thiết cho tính năng đang triển khai. Khi phát triển thêm tính năng mới, bổ sung thư mục tương ứng theo cấu trúc đã thống nhất.

**Mục tiêu cuối cùng:** Project có cấu trúc rõ ràng, mỗi hệ thống có trách nhiệm riêng, các thành viên có thể phát triển song song và dễ dàng tích hợp code mà không ảnh hưởng đến những phần khác.