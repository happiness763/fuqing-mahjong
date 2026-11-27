<h1 align="center">福清麻将 · 融城茶馆</h1>

<p align="center">四人福清麻将，一人也能开桌。和三名 AI 练牌，或邀朋友在局域网和 UDP 内网穿透房间里同桌。</p>

<p align="center">
  <a href="https://github.com/happiness763/fuqing-mahjong/releases/latest"><strong>下载 Windows 版</strong></a>
  · <a href="#玩法速览">玩法速览</a>
  · <a href="release/联机说明-v1.3.4a.md">联机说明</a>
  · <a href="#参与开发">参与开发</a>
</p>

<p align="center">
  <img src="docs/images/gameplay.png" width="1000" alt="融城茶馆 3D 牌桌实机画面，四家牌河围绕圆形风盘，桌沿有双层牌墙，本家手牌立在桌前">
</p>

## 快速开桌

从 [GitHub Releases](https://github.com/happiness763/fuqing-mahjong/releases/latest) 下载 Windows ZIP，解压后运行里面的 `FuqingMahjong-*.exe`。

| 模式 | 怎么开局 |
| --- | --- |
| **单机** | 从首页点「开始游戏」进入开桌设置，选局数（默认 25）、AI 难度和运气，再点「开始游戏」。三档难度为简单、普通、困难。 |
| **联机** | 房主开房并分享「地址:端口」。朋友填昵称、粘贴地址后加入，在大厅选东、南、西、北的空座。房主可加 AI 补齐四席，再开始游戏。 |

联机请统一使用 v1.3.4a。房主可设置 15 秒、30 秒、60 秒或不限时，默认 60 秒。跨网络开房需转发 UDP 端口，具体步骤见 [联机说明](release/联机说明-v1.3.4a.md)。

首页「数据统计」和对局菜单里的「数据统计」可查看本机累计战绩、单局详情、最近 100 局历史和成就；数据只保存在本机。整桌结算会列出每位牌手的胡牌次数和点炮次数。

v1.3.1 新增 16+4 海底牌阶段、联机四家准备与结算确认、AI 托管，以及新的风盘、头像统计和每行 6 张的舍牌布局。

v1.3.2 新增六款动物牌背，每副牌统一一种，按发牌次序循环，联机同步。

v1.3.3 重排玩家视角。双层牌墙沿透视桌边摆放，圆形风盘居中，本家副露放在手牌右侧，操作按钮在手牌上方横排。

v1.3.3a 放大远端舍牌和常见副露，调整四家间距，本家手牌与吃碰杠牌底边对齐。

v1.3.3b 统一牌张规格及两套牌面的留白，校正金标和副露，四家舍牌连续排布。

v1.3.3c 将 Godot 对局重制为 3D 牌桌。双层牌墙沿木边摆放，四家牌河围绕圆形风盘，每六张换行。本家手牌立在桌前，摸入牌单独留缝，吃碰杠牌排在手牌右侧。

v1.3.3d 统一副露与牌山、舍牌的立体厚度，支持高分辨率（2K）全屏原生清晰渲染并全面开启各向异性过滤，调整牌墙与外家间距以消除对家及侧边副露被牌墙遮挡的问题。

v1.3.3e 放大并重绘左上角单金与花金显示，去除冗余小角标大幅提升辨识度；同时开启 3D 透明牌桌并加入新中式“融城茶馆”沉浸式全景背景。

v1.3.4a 以 v1.3.3e 的稳定构图与 2K 清晰度为基准，将本家手牌倾角由 51° 向桌面方向调整至 36°（正对 56° 俯视视线）并同步贴合桌布底边，修正打牌时的手牌视角观感。

### 键鼠操作

- **出牌**。点一下选中手牌，再点同一张、按回车或点击「出牌」确认。按 Esc 可取消选择或关闭弹窗。
- **吃、碰、杠、胡、过**。能操作时，按钮出现在手牌上方。有多种吃法时，点「吃」后按牌面选组合。
- **跳过开局演出**。发牌、开金或补花演出时，点击画面或按空格。
- **换外观**。在「菜单 → 设置」切换国标或日麻皮肤，也可以导入自定义桌布。点击其他牌手头像可以发互动道具。
- **AI 托管**。对局菜单开启后，本机座位按普通难度自动出牌；不代点下一局，返回大厅自动关闭。
- **胡牌演出**。胡牌后先播 1–2 秒演出再弹出结算；点击画面、按空格/回车/Esc 或点「跳过演出」可立即结算。特殊牌型有专属 2 秒演出。

「设置 → 特效强度」可选完整、简洁或关闭。关闭后不播放胡牌演出和桌面浮尘；Android 四核及以下设备自动使用简洁模式。

## 玩法速览

**胡牌需要五组加一对将。** 一组可以是同花色的三连张，如一二三万，也可以是三张相同的牌。吃、碰和杠形成的面子也计入这五组。

1. **定庄、发牌、开金。** 首局掷骰定庄。庄家起手 17 张，闲家各 16 张。翻到的牌决定本局的「金」，金可以在胡牌时当作缺少的牌来用。翻到季节牌时春夏秋冬都作金，翻到植物牌时梅兰竹菊都作金。其他花牌补掉。
2. **摸牌、出牌、争牌。** 四人按东、南、西、北的顺序轮转。吃只接上家的牌。争同一张牌时，胡优先于碰、杠，碰、杠优先于吃。多人能胡同一张牌时，牌型较高者优先，同牌型按座次。打出的金不能被认领。有人补杠时，能用第四张牌成胡的牌手可抢杠。
3. **留意过碰和过胡。** 已经得到碰或点炮胡的选项并选择「过」后，到自己实际摸牌前，别人再打相同牌面时，不能再以相同动作认领。这次自己摸到并符合胡牌条件时，仍可自摸。
4. **认清两种流局。** 牌墙保留最后 18 张，可摸的牌耗尽时流局。首巡四家各自打出的第一张牌都相同，且期间无人实际吃、碰、明杠或补杠，第四张落地就流局并自动重发本局。暗杠和补花仍可进行。

### 福清特色牌型

| 牌型 | 怎么认 |
| --- | --- |
| **闲金** | 自摸前留一张金来配将，其余牌凑齐五组。手中若有两张金，另一张可以补顺子或刻子。摸到普通牌与留出的金成将即可。 |
| **金雀、金龙** | 金雀用两张金作一对将。金龙用三张金作一副刻子。 |
| **抢金** | 开局可用桌面翻起的金成胡。闲家优先，庄家符合条件时可用一张手牌换金。 |
| **报听金坎** | 例如五万是金，满足听牌条件时可以亮出四万和六万报听。报听后摸打，直到自摸金补成四五六万胡牌。 |

<details>
<summary>计分与庄家轮转</summary>

平胡分 **P = 底分 + 花分 + 普通金张数 + 2 × 花金张数**。胡家是庄家时底分为 3，闲家为 1。花牌、明杠和补杠各计 1 花，暗杠计 2 花。

| 胡法或牌型 | 各支付方计分 |
| --- | ---: |
| 平胡 | P |
| 自摸、抢杠 | 2P |
| 闲金 | 2P + 10 |
| 三金倒、抢金、碰碰胡 | 3P |
| 金雀、金坎 | 4P + 40 |
| 金龙、天胡、正清、单吊 | 5P + 50 |

同一手牌符合多个牌型时取最高分。点炮由出牌者付分，抢杠由被抢杠者付分，自摸与特殊开局胡法由另外三家付分。庄家胡或流局连庄，闲家胡则由庄家下家接庄。

</details>

游戏内的「玩法规则」可以查到庄家上家无金时的碰杠限制、锁牌和其他细则。

## 参与开发

用 Godot **4.7.2** 导入 [godot/project.godot](godot/project.godot)，按 **F5** 运行。Windows 打包使用项目里的 **Windows Desktop** 预设，并安装同版本的导出模板。

| 模块 | 文件 |
| --- | --- |
| 牌型与计分 | [rules.gd](godot/scripts/rules.gd) |
| 牌局流程 | [game.gd](godot/scripts/game.gd) |
| AI 选牌 | [opponent.gd](godot/scripts/opponent.gd) |
| 房间与同步 | [online_room.gd](godot/scripts/online_room.gd) |
| 测试 | [godot/tests/](godot/tests/) |

从 `main` 建立功能分支后提交 Pull Request。请附上操作或复现步骤以及测试结果。改动争牌、抢杠或结算时，验证单机和联机两条入口。报错可在 [GitHub Issues](https://github.com/happiness763/fuqing-mahjong/issues) 提交游戏版本和复现步骤。

<details>
<summary>运行回归测试</summary>

从仓库根目录执行。若 `godot` 未加入 PATH，请换成 Godot 可执行文件的路径。

```text
godot --headless --path godot --editor --import
godot --headless --path godot --script res://tests/v122_game_test.gd
godot --headless --path godot --script res://tests/v122_scoring_test.gd
godot --headless --path godot --script res://tests/win_pattern_test.gd
godot --headless --path godot --script res://tests/v124_opening_test.gd
godot --headless --path godot --script res://tests/v128_idle_test.gd
godot --headless --path godot --script res://tests/v128_redeal_test.gd
godot --headless --path godot --script res://tests/v128_ai_test.gd
godot --headless --path godot --script res://tests/v128_redeal_desktop_test.gd
godot --headless --path godot --script res://tests/v127_center_test.gd
godot --headless --path godot --script res://tests/v126_pass_test.gd
godot --headless --path godot --script res://tests/v126_wall_test.gd
godot --headless --path godot --script res://tests/v126_dice_test.gd
godot --headless --path godot --script res://tests/v126_interaction_test.gd
godot --headless --path godot --script res://tests/online_rules_test.gd
godot --headless --path godot --script res://tests/online_room_test.gd
```

早期网页版源代码见 `index.html`、`src/` 和 `test/`，测试可用 `node --test`。

</details>

[更新说明](release/更新说明-v1.3.4a.md) · [牌桌重制设计](docs/superpowers/specs/2026-11-23-godot-mahjong-v1.3.3c-design.md) · [清晰度与遮挡修复设计](docs/superpowers/specs/2026-11-24-godot-mahjong-v1.3.3d-design.md) · [金牌与茶馆背景设计](docs/superpowers/specs/2026-11-24-godot-mahjong-v1.3.3e-design.md) · [数据统计与首页设计](docs/superpowers/specs/2026-11-17-godot-mahjong-v1.2.9-design.md) · [牌面来源](godot/assets/tiles/CREDITS.md) · [第三方许可](release/licenses/)
