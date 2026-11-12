# 福清麻将 v1.2.4 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 重排主界面为菜单+右侧状态栏，加入首局掷骰庄家、开金骰子决定翻牌位置、可跳过的开局发牌/开金/补花演出，并补齐字牌与花牌矢量牌面。

**Architecture:** 规则层新增纯函数式的庄家掷骰与开金位置计算；表现层新增独立的开局演出状态机，牌局引擎仍一次性完成发牌，UI 按最终视图分阶段展示。联机仍由房主权威判定，快照携带掷骰与金牌信息。

**Tech Stack:** Godot 4.7.2 / GDScript；ENet 联机；SVG 牌面。

**Spec:** `docs/superpowers/specs/2026-11-12-godot-mahjong-v1.2.4-design.md`

## Global Constraints

- 使用 `D:\暮\桌面\Godot_v4.7.2-stable_win64.exe` 运行测试与导出。
- 版本号统一为 `1.2.4`（`project.godot`、联机 `VERSION`、导出路径、测试断言）。
- 画布 1280×800，最小窗口 864×540；不改造为响应式。
- 本期不绘制牌墙；开金骰子决定从牌墙倒数第 S 墩翻牌。
- 万筒条与字牌复用 FluffyStuff `riichi-mahjong-tiles`（CC0 1.0）；四季与梅兰竹菊 8 张原创，同样 CC0。
- 除首局庄家与开金位置外，不改动牌型、计分、争牌、抢杠规则。
- 联机保持房主权威；客户端只播放结果，不自行随机。
- 每个 Task 结束时运行相关测试并提交；测试命令统一为：
  `"/d/暮/桌面/Godot_v4.7.2-stable_win64.exe" --headless --path godot --script res://tests/<file>.gd`

## Review Focus

- 自定义小牌墙下 `gold_index` 越界或回绕：`posmod` 后必须落在 `0..wall.size()-1`，且翻出的牌确实是计划位置。
- 庄家平局重掷：只重掷并列最高者，必须收敛到唯一赢家，不能死循环。
- 联机 `dealer_rolls` 的座位号：快照按服务端座位，客户端视图必须随 `OnlineTableView` 一起旋转。
- 演出期间的动作门禁：单机 AI、联机超时/托管 AI 都不能在演出结束前推进阶段。
- 结算、争牌、抢杠状态下删掉底部栏后的按钮可达性：菜单、状态面板按钮必须覆盖这些状态。
- 42 张牌面齐全时的文字兜底：有纹理时不再叠加文字；缺图时仍可读。

---

### Task 1: 牌桌几何与主界面重排

**Files:**
- Modify: `godot/scripts/table_art.gd`
- Modify: `godot/scripts/table.gd`
- Test: `godot/tests/desktop_test.gd`

**Interfaces:**
- Produces: `Art.FRAME = Rect2(28, 16, 1042, 768)`, `Art.FELT = Rect2(41, 29, 1016, 742)`, `Art.CENTER = Vector2(549, 400)`, `Art.RIVERS = [Rect2(352, 505, 394, 101), Rect2(647, 330, 250, 132), Rect2(352, 150, 394, 101), Rect2(201, 330, 250, 132)]`
- Produces: `desk.menu_button: Button`, `desk.menu_panel: Panel`, `desk.status_panel: Panel`, `desk.status_label: Label`
- Produces: `GOLD_AREA = Rect2(842, 52, 194, 112)`; hand tiles 56×76 at y=700; seat origins `[Vector2(63, 640), Vector2(915, 290), Vector2(472, 40), Vector2(58, 290)]`.

- [ ] **Step 1: 写失败测试**

在 `desktop_test.gd` 的 `run()` 中加入：

```gdscript
	check(Art.FRAME == Rect2(28, 16, 1042, 768), "table frame fills the window")
	check(Art.FELT == Rect2(41, 29, 1016, 742), "felt follows the frame")
	check(Art.CENTER == Vector2(549, 400), "table center is recentered")
	check(Art.RIVERS[0] == Rect2(352, 505, 394, 101), "bottom river fits above the hand")
	check(desk.GOLD_AREA == Rect2(842, 52, 194, 112), "gold display moves to the new frame")
	check(is_instance_valid(desk.menu_button) and desk.menu_button.text == "菜单", "one menu button replaces the header row")
	check(not desk.header.find_children("*", "Label", true, false).any(func(node): return node.text == "福清麻将"), "title block is removed")
	check(desk.human_buttons.size() == 17 and desk.human_buttons[0].size == Vector2(56, 76), "hand grows to 56x76")
	check(desk.human_buttons.back().position.x + 56 <= 1070, "17 tiles fit the frame width")
```

并更新 `test_gold_display` 中的区域断言为 `Rect2(842, 52, 194, 112)`。

- [ ] **Step 2: 运行测试确认失败**

Run: `"/d/暮/桌面/Godot_v4.7.2-stable_win64.exe" --headless --path godot --script res://tests/desktop_test.gd`
Expected: FAIL（常量或节点不存在）。

- [ ] **Step 3: 实现几何与布局**

- `table_art.gd`：替换 `FRAME`/`FELT`/`CENTER`/`RIVERS`；删除底栏 `Rect2(28,716,1042,55)` 的绘制；右侧面板改为 `Rect2(1083,72,169,272)`、`Rect2(1083,360,169,188)`、`Rect2(1083,564,169,220)`。
- `table.gd`：`GOLD_AREA` 改为 `Rect2(842, 52, 194, 112)`；`build_header()` 只创建右上角菜单按钮 `Rect2(1083, 16, 169, 44)`，删除福字、标题、副标题、声音/玩法规则/返回首页按钮；`render_sidebar()` 的积分/动态位置按新面板；`draw_hand()` 改为 56×76、y=700、步进 59；座位原点与牌河、副露、金坎锚点按新外框重算。
- 状态/上下文按钮暂时保留旧逻辑，Task 2 再迁入右侧面板。

- [ ] **Step 4: 运行测试确认通过**

Run: 同 Step 2。Expected: PASS（除 Task 2 尚未迁移的状态栏断言）。

- [ ] **Step 5: 提交**

```bash
git add godot/scripts/table_art.gd godot/scripts/table.gd godot/tests/desktop_test.gd
git commit -m "feat: enlarge the table and simplify the header"
```

### Task 2: 自绘菜单与牌桌状态面板

**Files:**
- Modify: `godot/scripts/table.gd`
- Modify: `godot/scripts/table_art.gd`
- Test: `godot/tests/desktop_test.gd`

**Interfaces:**
- Produces: `desk.toggle_menu()`, `desk.close_menu()`, `desk.menu_open() -> bool`
- Menu items: 声音（开/关）、玩法规则、移交房主（条件显示）、返回首页/退出房间。
- `desk.status_label` 显示原底部状态文案；`desk.controls` 里的上下文按钮放在状态面板内。

- [ ] **Step 1: 写失败测试**

```gdscript
	click(desk.menu_button)
	check(desk.menu_open(), "menu opens")
	var labels := desk.menu_panel.find_children("*", "Button", true, false).map(func(b): return b.text)
	check(labels.has("声音  开") and labels.has("玩法规则") and labels.has("返回首页"), "menu has sound, rules and leave")
	check(not labels.has("操作说明"), "the old operation hints are gone")
	click(by_text(desk.menu_panel, "声音  开"))
	check(desk.muted and not desk.menu_open(), "sound item toggles and closes the menu")
	click(desk.menu_button)
	desk.close_menu()
	check(not desk.menu_open(), "escape or outside click closes the menu")
```

在牌局中构造 `view.phase == "turn"`、`current == 0` 后：

```gdscript
	check(desk.status_label.text.contains("轮到你出牌"), "turn status moves to the side panel")
	check(not desk.dynamic.get_children().any(func(node): return node is Label and node.text == "出牌操作"), "operation hints are removed")
```

- [ ] **Step 2: 运行确认失败**

Expected: FAIL（`toggle_menu` 不存在）。

- [ ] **Step 3: 实现菜单与状态面板**

- 菜单面板用 `Panel` + 4 个 `Button` 自绘，位置 `Rect2(1083, 64, 169, 184)`；点击外部用全屏透明 `Control` 关闭；Esc 关闭。
- `toggle_sound()` 更新菜单项文案；`show_rules`/`show_transfer`/`show_reset` 复用现有弹窗。
- 删除 `render_sidebar()` 中「出牌操作」段落；`render_controls()` 将 detail 文本放进 `status_label`（`Rect2(1093, 596, 149, 56)`，自动换行），上下文按钮从 `y=660` 起纵向排列，宽 149、高 36、间距 6。
- `transfer_button` 改为菜单项可见性；`leave_button` 文案改为菜单最后一项。
- 联机 `header.show()/hide()` 继续控制菜单按钮可见。

- [ ] **Step 4: 运行测试确认通过**

Run: 同 Task 1。Expected: PASS。

- [ ] **Step 5: 提交**

```bash
git add godot/scripts/table.gd godot/scripts/table_art.gd godot/tests/desktop_test.gd
git commit -m "feat: add a self-drawn menu and side status panel"
```

### Task 3: 庄家掷骰规则

**Files:**
- Modify: `godot/scripts/rules.gd`
- Test: `godot/tests/v124_opening_test.gd` (create)

**Interfaces:**
- Produces: `Rules.roll_dealer(rng: RandomNumberGenerator, dice_roll := Callable()) -> Dictionary`，返回 `{"winner": int, "dice": Array, "sums": Array, "rerolls": int}`；`dice[i]` 为第 i 座的两枚点数，`sums[i]` 为和值。
- `dice_roll` 为空时使用 `rng.randi_range(1, 6)`；测试传入返回固定点数的 Callable。

- [ ] **Step 1: 写失败测试**

```gdscript
func test_roll_dealer_breaks_ties() -> void:
	var values := [6, 4, 5, 5, 1, 2, 3, 2, 6, 5, 2, 1]
	var index := 0
	var roller := func(): var v: int = values[index]; index += 1; return v
	var roll: Dictionary = Rules.roll_dealer(RandomNumberGenerator.new(), roller)
	check(roll.winner == 0 and roll.rerolls == 1, "tied leaders reroll until one wins")
	check(roll.sums == [11, 4, 5, 3], "only tied seats reroll")
```

- [ ] **Step 2: 运行确认失败**

Run: `... --script res://tests/v124_opening_test.gd`
Expected: FAIL（`roll_dealer` 不存在）。

- [ ] **Step 3: 实现**

`rules.gd` 新增静态函数；`winner` 为唯一最高和值；并列时只重掷并列座位并更新 `dice`/`sums`，`rerolls` 计数；循环上限 100 次，理论上不会触发。

- [ ] **Step 4: 运行确认通过并提交**

```bash
git add godot/scripts/rules.gd godot/tests/v124_opening_test.gd
git commit -m "feat: add dealer dice roll rules"
```

### Task 4: 开金骰子与庄家参数

**Files:**
- Modify: `godot/scripts/game.gd`
- Test: `godot/tests/v124_opening_test.gd`, `godot/tests/v122_game_test.gd`

**Interfaces:**
- Produces: `Game.new(seed_value := -1, rounds := 15, luck_setting := "normal", online := false, dealer_seat := 0)`；`dealer_seat` 决定 `dealer`。
- Produces: `game.gold_dice: Array`、`game.gold_index: int`、`game.dealer_rolls: Dictionary`。
- `Game.view(seat)` 新增 `gold_dice`、`gold_index`、`dealer_rolls`。
- 翻牌索引：`gold_index = posmod(wall.size() - 1 - 2 * (S - 1), wall.size())`，`S = gold_dice[0] + gold_dice[1]`；用 `wall.pop_at(gold_index)` 取指示牌。

- [ ] **Step 1: 写失败测试**

```gdscript
func test_gold_dice_choose_the_indicator() -> void:
	var game = Game.new(43, 1, "normal", false, 2)
	check(game.dealer == 2, "explicit dealer seat")
	check(game.gold_dice.size() == 2 and game.view(0).gold_dice == game.gold_dice, "view exposes gold dice")
	check(game.gold == game.indicator, "indicator becomes the gold")
	var size_before := 79
	var sum: int = game.gold_dice[0] + game.gold_dice[1]
	check(game.gold_index == posmod(size_before - 1 - 2 * (sum - 1), size_before), "gold index follows the dice")
```

自定义牌墙测试：

```gdscript
	var game2 = Game.new(43)
	game2.gold_dice = [1, 1]
	var deck := []
	deck.resize(100); deck.fill(10)
	deck[97] = 34
	game2.deal(deck)
	check(game2.indicator == 34, "sum 2 flips the second stack from the tail")
```

同时更新 `v122_game_test.gd` 的 `test_flower_gold_deal`：把期望的金牌放到骰子计算出的下标（100 张牌、和值 2 时为 `deck[97]`），并设置 `game.gold_dice = [1, 1]`。

- [ ] **Step 2: 运行确认失败**

Run: `... --script res://tests/v124_opening_test.gd` 和 `... --script res://tests/v122_game_test.gd`
Expected: FAIL。

- [ ] **Step 3: 实现**

- `_init` 增加 `dealer_seat` 参数并先设置 `dealer`；新增 `_dice_rng`，`seed_value >= 0` 时 `seed = seed_value + 104729`，否则 `randomize()`。
- `start_round()` 在 `deal()` 前掷一次 `gold_dice`；运气重洗沿用同一组。
- `deal()` 用 `gold_index` 取指示牌；`best` 缓存 `players/wall/gold/indicator/gold_index`。
- `view()` 暴露 `gold_dice`、`gold_index`、`dealer_rolls`。

- [ ] **Step 4: 运行确认通过并提交**

```bash
git add godot/scripts/game.gd godot/tests/v124_opening_test.gd godot/tests/v122_game_test.gd
git commit -m "feat: let the gold dice choose the indicator position"
```

### Task 5: 开局演出状态机

**Files:**
- Create: `godot/scripts/opening_intro.gd`
- Test: `godot/tests/v124_opening_test.gd`

**Interfaces:**
- `OpeningIntro.start(dealer_seat: int) -> void`
- `advance() -> String`：按 `deal`（4 轮，每轮四家各 +4）→ `dealer_extra`（庄家 +1）→ `dice` → `gold` → `flowers` → `done` 推进，返回新阶段。
- `skip() -> void`：直接进入 `done`。
- `is_active() -> bool`、`visible_count(seat: int, final_count: int) -> int`、`status_text() -> String`。
- `status_text()` 依次为「发牌中…」「庄家补牌」「掷骰开金」「翻金」「补花」「」。

- [ ] **Step 1: 写失败测试**

```gdscript
func test_opening_intro_sequence() -> void:
	var intro := OpeningIntro.new()
	intro.start(1)
	check(intro.stage == "deal" and intro.seat_counts == [0, 0, 0, 0], "deal starts empty")
	for i in range(4):
		intro.advance()
	check(intro.seat_counts == [16, 16, 16, 16] and intro.stage == "dealer_extra", "four rounds deal sixteen tiles")
	intro.advance()
	check(intro.seat_counts[1] == 17 and intro.stage == "dice", "dealer takes the extra tile")
	intro.advance(); check(intro.stage == "gold", "dice precedes the gold reveal")
	intro.advance(); check(intro.stage == "flowers", "flowers follow the gold")
	intro.advance(); check(intro.stage == "done" and not intro.is_active(), "intro finishes")
	check(intro.visible_count(0, 16) == 16, "final counts are fully visible")
	intro.start(0); intro.skip(); check(intro.stage == "done", "skip ends the intro")
```

- [ ] **Step 2: 运行确认失败并实现**

Run: 同测试文件。Expected: FAIL → 实现状态机 → PASS。

- [ ] **Step 3: 提交**

```bash
git add godot/scripts/opening_intro.gd godot/tests/v124_opening_test.gd
git commit -m "feat: add the opening deal timeline"
```

### Task 6: 单机接入开局演出

**Files:**
- Modify: `godot/scripts/table.gd`
- Test: `godot/tests/desktop_test.gd`

**Interfaces:**
- `desk.intro: OpeningIntro`、`desk.start_intro() -> void`、`desk.skip_intro() -> void`。
- 演出期间 `local_moves()` 返回空；状态面板显示 `intro.status_text()`；金牌区在 `gold` 阶段前不绘制；对手牌数与自家手牌按 `visible_count` 截断；花牌在 `flowers` 阶段前不显示。
- 点击、空格、回车跳过；演出结束后启动 AI 计时。

- [ ] **Step 1: 写失败测试**

```gdscript
	desk.game = Game.new(43, 2)
	desk.start_intro()
	check(desk.local_moves().is_empty() and desk.intro.is_active(), "intro blocks moves")
	check(desk.status_label.text.contains("发牌中"), "intro status is visible")
	check(not desk.dynamic.get_node_or_null("GoldDisplay"), "gold stays hidden while dealing")
	desk.intro.advance(); desk.intro.advance(); desk.intro.advance(); desk.intro.advance()
	desk.refresh()
	check(desk.human_buttons.size() == 16, "four rounds reveal sixteen tiles")
	desk.skip_intro()
	check(desk.intro == null and desk.controls.size() >= 0, "skip ends the intro")
```

- [ ] **Step 2: 运行确认失败并实现**

- `begin_game()` / `next_round()`：本地创建/推进牌局后调用 `start_intro()`。
- `refresh()`：根据 `intro` 覆盖 `draw_hand`、对手数量、花牌、金牌区与状态文本。
- Timer 驱动 `intro.advance()`，每步约 0.35s；`dice` 阶段用 6 次随机面后落到 `view.gold_dice`；`gold`/`flowers` 阶段刷新。
- `_unhandled_input` 处理鼠标左键/空格/回车跳过。
- Run: desktop_test。Expected: PASS（含 Task 1/2 的断言）。

- [ ] **Step 3: 提交**

```bash
git add godot/scripts/table.gd godot/tests/desktop_test.gd
git commit -m "feat: animate the opening deal, gold and flowers"
```

### Task 7: 联机接入掷骰与演出宽限

**Files:**
- Modify: `godot/scripts/online_room.gd`
- Modify: `godot/scripts/online_table_view.gd`
- Test: `godot/tests/online_room_test.gd`, `godot/tests/online_table_test.gd`

**Interfaces:**
- `online_room.gd`：`const INTRO_MS := 4500`、`const ROLL_MS := 1800`；新增 `_roll_rng`。
- `_apply_request("start")` 掷庄家、以 `dealer_seat` 创建 `Game`、写入 `_game.dealer_rolls`，`_begin_stage(INTRO_MS + ROLL_MS)`。
- `_apply_request` 的 `next`：`_begin_stage(INTRO_MS)`。
- `_begin_stage(intro_ms := 0)` 把 `intro_ms` 加到 `_deadline_ms` 与 `_ai_due_ms`。
- `OnlineTableView.from_room()` 旋转 `dealer_rolls` 的 `dice`/`sums`/`winner`（按 `viewer`），`gold_dice` 不旋转。

- [ ] **Step 1: 写失败测试**

```gdscript
	# online_room_test: 开局后
	check(not host.state.view.dealer_rolls.is_empty(), "host publishes the dealer roll")
	check(client.state.view.dealer_rolls.winner == host.state.view.dealer_rolls.winner, "both peers see the same dealer")
	check(host.state.view.gold_dice.size() == 2, "gold dice are part of the snapshot")
	check(host._deadline_ms - Time.get_ticks_msec() >= 5000, "first stage includes the intro grace")
```

```gdscript
	# online_table_test: 构造 state.view.dealer_rolls，viewer=2
	check(view.dealer_rolls.winner == 0 and view.dealer_rolls.dice[0] == original_dice[2], "dealer roll rotates with the seat view")
```

- [ ] **Step 2: 运行确认失败并实现**

Run: `... --script res://tests/online_room_test.gd`、`... --script res://tests/online_table_test.gd`。

- [ ] **Step 3: 提交**

```bash
git add godot/scripts/online_room.gd godot/scripts/online_table_view.gd godot/tests/online_room_test.gd godot/tests/online_table_test.gd
git commit -m "feat: sync dealer and gold dice through the online snapshot"
```

### Task 8: 庄家掷骰界面

**Files:**
- Modify: `godot/scripts/table.gd`
- Test: `godot/tests/desktop_test.gd`

**Interfaces:**
- `desk.show_dealer_roll(roll: Dictionary, on_done: Callable) -> void`：居中面板 `Rect2(420, 250, 440, 220)`，四行显示座位、骰子点数、和值，胜者高亮；约 1.6s 后回调。
- 单机 `begin_game()`：先掷骰，展示面板，再以胜者为庄创建 `Game` 并 `start_intro()`。
- 联机：进入牌桌且 `view.dealer_rolls` 非空时先展示；之后 `start_intro()`。

- [ ] **Step 1: 写失败测试**

```gdscript
	var roll := {"winner": 2, "dice": [[1, 2], [3, 4], [5, 6], [2, 2]], "sums": [3, 7, 11, 4], "rerolls": 0}
	desk.show_dealer_roll(roll, Callable())
	check(is_instance_valid(desk.dealer_roll_panel), "dealer roll panel opens")
	var labels: Array = desk.dealer_roll_panel.find_children("*", "Label", true, false).map(func(n): return n.text)
	check(labels.any(func(t): return t.contains("阿榕") and t.contains("11")), "winner and sums are shown")
```

- [ ] **Step 2: 运行确认失败并实现**

- 面板用现有 `panel`/`label`/`button` 风格；行逐个淡入；按钮「开始」或自动 callback。
- 单机流程在 `begin_game()` 里替换直接创建 `Game`。
- 联机流程在 `room_state_changed` 首次进入时触发。
- Run: desktop_test。Expected: PASS。

- [ ] **Step 3: 提交**

```bash
git add godot/scripts/table.gd godot/tests/desktop_test.gd
git commit -m "feat: show the dealer dice roll before the first deal"
```

### Task 9: 字牌与花牌矢量素材

**Files:**
- Create: `godot/assets/tiles/Ton.svg`、`Nan.svg`、`Shaa.svg`、`Pei.svg`、`Chun.svg`、`Hatsu.svg`、`Haku.svg`
- Create: `godot/assets/tiles/Spring.svg`、`Summer.svg`、`Autumn.svg`、`Winter.svg`、`Plum.svg`、`Orchid.svg`、`Bamboo.svg`、`Chrysanthemum.svg`
- Modify: `godot/scripts/table.gd`、`godot/assets/tiles/CREDITS.md`
- Test: `godot/tests/desktop_test.gd`

**Interfaces:**
- `desk.faces.size() == 42`；索引 27–33 为字牌，34–37 为四季，38–41 为花牌。
- `tile()` 仅在 `face == null` 时绘制文字标签。

- [ ] **Step 1: 写失败测试**

```gdscript
	check(desk.faces.size() == 42, "all forty-two tiles have artwork")
	for face in desk.faces:
		check(face != null and face.get_image().get_used_rect().has_area(), "tile has visible artwork")
	var honor := desk.tile(desk, 27, Rect2(0, 0, 56, 76), 26)
	check(not honor.find_children("*", "Label", false, false).size(), "honor tiles do not fall back to text")
```

- [ ] **Step 2: 获取复用素材**

用官方源码下载 7 张字牌：

```bash
for n in Ton Nan Shaa Pei Chun Hatsu Haku; do
  curl -L -o "godot/assets/tiles/$n.svg" "https://raw.githubusercontent.com/FluffyStuff/riichi-mahjong-tiles/master/Regular/$n.svg"
done
```

- [ ] **Step 3: 原创 8 张花牌 SVG**

以 300×400 viewBox 制作，象牙白牌面由 `tile_view` 绘制，SVG 只含墨线/朱红/青绿图案。建议用 Noto Sans SC（OFL）字形路径 + 折枝/花瓣/竹叶线稿，避免依赖系统字体；文件与 `CREDITS.md` 一并更新。

- [ ] **Step 4: 接入与导入**

- `table.gd`：`faces` 追加 15 张（顺序 27→41）；`tile()` 的 `if number >= Rules.NUMBERED:` 改为仅当 `face == null` 时加文字。
- 用 4.7.2 运行 `--import` 生成 `.import`。
- 更新 CREDITS：7 张字牌来自 FluffyStuff（CC0），8 张花牌原创（CC0）。

- [ ] **Step 5: 运行测试并提交**

Run: desktop_test。Expected: PASS。

```bash
git add godot/assets/tiles godot/scripts/table.gd godot/tests/desktop_test.gd
git commit -m "feat: add honor and flower tile artwork"
```

### Task 10: 版本 1.2.4、文档与导出

**Files:**
- Modify: `godot/project.godot`、`godot/scripts/online_room.gd`、`godot/export_presets.cfg`、`godot/tests/desktop_test.gd`、`README.md`、`release/使用说明.txt`
- Create: `release/更新说明-v1.2.4.md`、`release/联机说明-v1.2.4.md`
- Test: 全量测试

- [ ] **Step 1: 版本号**

`project.godot` → `1.2.4`；`online_room.gd` 的 `VERSION` → `1.2.4`；导出路径 → `../release/FuqingMahjong-v1.2.4.exe`；`desktop_test` 版本断言 → `1.2.4`。

- [ ] **Step 2: 发布文档**

更新 README 的当前版本与文档链接；`使用说明.txt` 改为 v1.2.4；新增更新说明与联机说明（内容同 v1.2.3，追加本次界面、庄家、开金、演出与牌面改动）。

- [ ] **Step 3: 全量测试**

Run: 依次运行 `rules_test`、`v122_game_test`、`v122_scoring_test`、`win_pattern_test`、`v124_opening_test`、`online_rules_test`、`online_room_test`、`online_table_test`、`desktop_test`。
Expected: 全部 PASS。

- [ ] **Step 4: 4.7.2 导出**

下载并安装 Godot 4.7.2 **标准版**导出模板；执行：

```bash
"/d/暮/桌面/Godot_v4.7.2-stable_win64.exe" --headless --path godot --export-release "Windows Desktop" "D:/ModsByMyself/mojang/fuqing-mahjong/release/FuqingMahjong-v1.2.4.exe"
```

无头启动冒烟：`./release/FuqingMahjong-v1.2.4.exe --headless --quit-after 60`，退出码 0。

- [ ] **Step 5: 提交**

```bash
git add README.md godot/project.godot godot/scripts/online_room.gd godot/export_presets.cfg godot/tests/desktop_test.gd release/使用说明.txt "release/更新说明-v1.2.4.md" "release/联机说明-v1.2.4.md"
git commit -m "chore: release v1.2.4"
```
