# 福清麻将 v1.3.3c 牌桌重制设计

2026-11-23 · 审阅稿

## 目标与范围

用莲花广麻的 3D 渲染代码重制《福清麻将 · 融城茶馆》的 Godot 对局画面。牌墙、手牌、舍牌和副露进入同一个立体场景，优先改善对家舍牌的可读性、本家手牌的立体感，以及桌面各区域的空间分配。保留融城茶馆的绿桌布、木边、圆形风盘、角色头像和两套牌面辨识度。

重制范围包括桌体、四边双层牌墙、四家手牌与公开牌、金标和最近弃牌标记，以及与新坐标有关的动画、操作区和桌心状态。现有首页、大厅、规则页、设置、数据统计、结算和早期网页版继续使用各自的入口。结算与选吃等弹窗沿用现有 2D 牌面组件。

牌型、计分、摸打与争牌顺序、牌墙取牌顺序、AI 难度和托管、联机房间和超时、统计与保存格式沿用 v1.3.3b。发牌、开金、补花、海底、胡牌演出和互动道具继续使用现有触发条件、跳过入口和特效设置。现有公开信息与暗牌可见范围也属于行为契约。

福清麻将基线为 `9b5b4421eb88060c4a130662c21767be48379bc4`，与 GitHub `main` 的 v1.3.3b 合并提交 `b57701e1f0fbefa6e12fb97a916c0283c39dc106` 文件树相同。莲花广麻代码固定到 `1f1be0079f37a3a5b1a559c29366b23916e1735b`，移植期间用这个版本核对函数与许可。[福清麻将基线](https://github.com/happiness763/fuqing-mahjong/commit/b57701e1f0fbefa6e12fb97a916c0283c39dc106) · [莲花广麻源码](https://github.com/BestGuo2020/lianhuaguangdongmahjong/tree/1f1be0079f37a3a5b1a559c29366b23916e1735b) · [当前对局画面](../../images/gameplay.png)

## 技术路线

| 路线 | 适用条件与代价 |
| --- | --- |
| **移植核心渲染函数到 Godot 原生 3D，推荐** | 将上游座位变换、镜头适配、牌张实例提交和桌体结构翻译为 GDScript。沿用本项目的 `Control` 界面和对局入口。需要处理 3D 与现有交互、动画的坐标衔接。 |
| 嵌入莲花广麻的 Three.js 牌桌 | 可以直接运行较多上游 TypeScript。需要引入 WebView 或浏览器运行时，以及快照、命令与输入桥接，增加 Windows、Android 和离线发布的维护面。 |
| 沿用现有 2D 透视绘制 | 适合只调整尺寸与间距。桌体、牌墙和平放牌仍须各自计算投影与阴影，上游的 3D 实例渲染也用不上。 |

主场景沿用 `table.tscn` 和 `table.gd`。在现有 2D 对局 UI 下方挂载独立的 `SubViewport` 3D 牌桌，用 `Camera3D`、共享材质和网格呈现。对局状态、键鼠和触屏输入由现有入口管理。沿用 GL Compatibility 和现有横屏安全区定位。牌桌载入完成后，离线单机可直接使用。[主场景](../../../godot/table.tscn) · [Godot SubViewport](https://docs.godotengine.org/en/stable/classes/class_subviewport.html) · [Godot Compatibility](https://docs.godotengine.org/en/stable/tutorials/rendering/renderers.html)

## 上游代码移植清单

移植单位是可对应到源文件的函数与实现片段。移植时记录上游文件、函数、固定提交、本地目标和适配差异，便于日后追踪。保留莲花广麻的版权声明与 MIT 许可全文，在仓库 `release/licenses/` 和后续导出包中附上。现有木纹、桌布、头像、牌面和牌背继续按各自的素材许可使用。[莲花广麻 MIT 许可](https://github.com/BestGuo2020/lianhuaguangdongmahjong/blob/1f1be0079f37a3a5b1a559c29366b23916e1735b/LICENSE) · [福清麻将牌面署名](../../../godot/assets/tiles/CREDITS.md)

| 上游实现 | 移植到 Godot 的内容 | 福清麻将适配 |
| --- | --- | --- |
| [`staticTableScene.ts`](https://github.com/BestGuo2020/lianhuaguangdongmahjong/blob/1f1be0079f37a3a5b1a559c29366b23916e1735b/src/components/table/three/staticTableScene.ts) | 桌面基座、桌缘、牌桌材质与中心件的分层构造。 | 采用融城茶馆的木边与桌布，中心件的外观配合原有圆形风盘。桌布贴图继续来自 `Preferences.table_texture()`。 |
| [`sceneRenderProfile.ts`](https://github.com/BestGuo2020/lianhuaguangdongmahjong/blob/1f1be0079f37a3a5b1a559c29366b23916e1735b/src/components/table/three/sceneRenderProfile.ts) | `tableCameraPosition` 的固定视点思路、`responsiveCameraFov` 的宽高比适配。 | 相机以本家为近端，窄幅窗口优先保住桌面边界与牌面。机位、视场角与灯光参数在效果图和实机上确定。 |
| [`tableLayout.ts`](https://github.com/BestGuo2020/lianhuaguangdongmahjong/blob/1f1be0079f37a3a5b1a559c29366b23916e1735b/src/game/core/presentation/tableLayout.ts) | `pointFromSeat` 的四向坐标变换、`seatTableLayout` 的局部轴、`meldTrackTransform` 的副露延伸、`discardTileLayout` 的行列坐标推导。 | 四家按本项目视角编号和已旋转的座位数据摆放。每条牌河始终六列，保持福清麻将现有的弃牌顺序和副露来源方向。 |
| [`tileInstanceRenderer.ts`](https://github.com/BestGuo2020/lianhuaguangdongmahjong/blob/1f1be0079f37a3a5b1a559c29366b23916e1735b/src/components/table/three/tileInstanceRenderer.ts)、[`tableTilePresenter.ts`](https://github.com/BestGuo2020/lianhuaguangdongmahjong/blob/1f1be0079f37a3a5b1a559c29366b23916e1735b/src/components/table/three/tableTilePresenter.ts) | 共享牌体、牌面贴图合批、接触阴影、牌张按区域提交实例与查询动画坐标的组织方式。 | 使用 Godot 实例渲染，保留已有 42 种牌的两套图案、六款牌背和金标。以本地状态生成实例，沿用现有胡牌演出。 |
| [`wallLayout.ts`](https://github.com/BestGuo2020/lianhuaguangdongmahjong/blob/1f1be0079f37a3a5b1a559c29366b23916e1735b/src/game/core/rules/wallLayout.ts) | 四段牌墙、各墩沿桌缘排布和上下层变换的几何部分。 | 牌墙为 144 张，四边各 18 墩、每墩两张。槽位、庄位旋转和取牌事件来自福清麻将。上游按 136 张计算的开口和尾牌逻辑留在上游。 |

## 对局画面

整体构图参考莲花广麻对局中四家牌河围绕桌心、大牌集中在屏幕内侧的布局。本家 17 张起手、单金与花金、海底和圆形风盘按融城茶馆自己的空间需求安排。[莲花广麻对局截图](https://github.com/BestGuo2020/lianhuaguangdongmahjong/blob/1f1be0079f37a3a5b1a559c29366b23916e1735b/docs/QQ20260801-222700.png)

- **桌体和镜头。** 默认画面为轻透视俯视。压缩屏幕四周的木框与背景，给牌河更多面积。灯光以均匀照亮牌面为先，允许用柔和接触阴影表现倒角和牌厚。桌布换肤继续使用已有选项与导入图片。圆形风盘在牌河内侧显示方位、庄位、分数和当前行牌方，联机倒计时放在桌心固定位置。
- **四家牌河。** 四块区域沿同一桌心排成四向，每家从桌心向外增加行数，六张换行。对家采用较缓的远近缩比，左右家依座位旋转。1280×800 下优先做到前三行可直接辨牌。单家第 19 张开始继续同一牌河，检查到第 36 张。加行时允许按需整块等比收紧，牌面保持 3:4 的原始贴图比例，落点与悬停区跟随。更长的合法牌河沿用同一换行和收紧算法。鼠标仍可查看小牌的牌名。最近弃牌的标记贴着对应牌与桌面。
- **本家手牌与副露。** 手牌立在桌前沿内侧，顶边可见，正面朝向本家。摸入牌与原手牌之间留缝。手牌与副露作为一个整体计算可用宽度，副露在手牌右侧，投影底缘对齐。覆盖庄家起手 17 张以及多组副露，优先保住手牌与按钮可点区域。来源横牌按整块牌旋转，补杠第四张叠在来源牌上。外家暗杠使用现有隐藏方式。
- **外家与花牌。** 外家未公开手牌只显示张数对应的牌背，在安全桌边与副露、花牌分区。花牌数量、公开花牌及金坎亮牌按当前视图呈现。结算揭牌时根据视图原样显示已公开手牌，避免遮住同侧副露和桌心。
- **牌墙与金牌。** 四边牌墙使用同一牌体和两层高度，局内牌背仍由手号决定。墙面空缺与取牌实际槽位对应。开金栏保留单金和花金的展示，桌上金牌沿用角标避让和小尺寸金色提示。海底牌按既有规则和槽位高亮，继续显示既有进度。
- **操作区。** 主要动作位于本家手牌上方的固定区域。出现出牌、吃、碰、杠、胡、过、报听、抢金或海底操作时，操作条留在原区域，维持原有文字、可用条件、确认流程与快捷键。候选组合和其他弹窗优先接收输入，桌面点击区域在其下方。

## 对局状态与渲染接口

1. **共享视图。** 桌面从 `table.gd` 的 `board_view()` 读取快照。单机来自 `game.view(0)`，联机来自 `OnlineTableView.from_room()` 转换后的视图。视角约定为本家 `0`、右家 `1`、对家 `2`、左家 `3`。渲染器接收已旋转的玩家、风位、庄位、分数、副露来源和操作事件。牌河、牌墙、手牌及动画均使用这个座位约定。
2. **实例与可见性。** 牌体、牌面、牌背和接触阴影按材质复用实例。公开牌按视图里的牌号填入纹理图集。未揭开的外家手牌由 `count` 生成背面，`-1` 暗杠也使用背面。开局与补花期间以现有 `OpeningIntro` 和补花序列的进度逐步亮出手牌背、花牌和金牌。结算按现有时序呈现视图中已公开的手牌。实例缓存限于当前桌次和可见快照，离桌、换局、重发和重连换视图时清理旧实例、动画和输入目标。
3. **牌墙槽位。** 从 `view.wall.slots` 取当前可见槽位，从 `opening` 模拟开局各帧的占用，从 `takes` 找取牌来源，从 `sea_slots` 取海底标记。按现有 `wall_side(slot, dealer)` 与上下层对应关系投影。槽位决定画面，牌序、开金点、前后取牌与保留数由 `game.gd` 提供。牌墙逐张减少，重复刷新同一快照时保持同一占用。
4. **投影与交互。** 由 3D 牌面角点投影到 2D 牌桌区域，并转换到 `Control` 坐标。可点牌使用同源命中范围，牌张交叠时优先最前一张。现有选牌、确认、撤销和提交仍由 `table.gd` 处理。缩放、全屏、Android 安全区变化后同帧刷新命中区和动画端点。牌面图案与命中区一起移动，触屏维持原有触发和确认语义。[Godot Camera3D](https://docs.godotengine.org/en/stable/classes/class_camera3d.html)
5. **动画与重连。** 从实际墙槽起飞，在手牌、金栏、花牌区或桌面落点结束。牌河最新一张、抢杠牌与胡牌来源按已有事件定位。以手号和现有事件位置或状态差量建立去重依据，开局跳过或收到重连快照时收敛到当前牌面，正常的下一次操作恢复动画。表现层不生成动作，`local_moves()` 和 `perform()` 继续决定可用动作与提交路径。
6. **外观与质量。** 重用现有外观保存、皮肤加载、导入桌布和特效档位。完整档使用主光和阴影，简洁档减少动态阴影和粒子，关闭档遵守当前特效开关。各档保持同样的牌河容量、投影和按钮。优先用 `MultiMesh` 等共享绘制方式处理静态牌墙与牌河，活跃动画使用少量单独实例。[Godot MultiMesh](https://docs.godotengine.org/en/stable/classes/class_multimesh.html)

关键接口见 [table.gd](../../../godot/scripts/table.gd)、[table_wall.gd](../../../godot/scripts/table_wall.gd)、[online_table_view.gd](../../../godot/scripts/online_table_view.gd)、[game.gd](../../../godot/scripts/game.gd) 和 [preferences.gd](../../../godot/scripts/preferences.gd)。

## 实施顺序与验收

1. **确认画面。** 先出三张同一画幅的效果图。发牌前摆齐四边双层墙；发牌后展示庄家 17 张牌和对应墙槽缺口，可选无花开局固定局面；中后盘至少包含三排舍牌、两组副露、金栏、联机倒计时和操作按钮。以 1280×800 为基准，检查近、中、远三处牌面大小和区域关系。效果图确认后再接入主场景。
2. **接入渲染。** 先用固定快照验证桌面、墙槽和各座投影，再接手牌、牌河、副露、花牌和标记。逐项接入现有输入和动画。用固定视图检查四家舍牌各自到 6、7、18、19、24、36 张的边界，验证双层牌墙的上下层缺口、窄窗和四周区域交界。对比两套牌面、单金与花金、六款牌背、来源横牌与补杠叠放。
3. **核对规则和功能。** 跑现有 Godot 规则、计分、AI、开局、牌墙、海底、联机和桌面回归。用相同的固定种子及行动序列对比 v1.3.3b 和新版的合法动作、关键状态以及结算。覆盖抢金、报听金坎、过碰过胡、抢杠、首巡流局重发及海底。将依赖旧 2D 节点或矩形的界面断言迁移到 3D 投影，继续检查四座槽位、17 张手牌、来源横牌、暗牌可见性、点击区域及悬停提示。
4. **真实入口验收。** Windows 实际导出包开单机对局，用鼠标和键盘完成选牌、出牌、争牌与结算。用两个 v1.3.3c 客户端开 UDP 房间、切换玩家方位、验证断线重连、托管、计时与四家结算，核对各客户端的暗牌可见范围。窗口检查至少覆盖 864×540、1280×800、1920×1080。Android 保留当前导出预设，有真机时检查横屏安全区、触屏和相同局面。Windows ZIP 依 Windows 验收独立交付，Android 的导出与真机结果分别记录。
5. **核对性能与发布。** 同一设备上用相同分辨率、特效档位和帧率上限，对比 v1.3.3b 与 v1.3.3c 的满墙和密集舍牌场景，记录第 95 百分位帧时间和点击响应。出现持续掉帧或操作卡顿时，先优化阴影、批量绘制和视口成本，通过原有档位覆盖低配环境。若 Windows 包仍有明显退化，记录差值并解决后再发布。发布时同步工程版本、联机版本和导出名为 `1.3.3c`，沿用现有同版本入房要求，快照和协议字段保持原样。用验证过的 Windows 包更新实机图和更新说明。提 PR 时同步 GitHub Release 并上传该 Windows ZIP。
