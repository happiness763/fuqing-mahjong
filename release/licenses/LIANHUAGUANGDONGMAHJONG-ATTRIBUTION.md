# 莲花广麻 3D 牌桌代码

福清麻将 v1.3.3c 的 Godot 牌桌移植自 BestGuo2020（我叫人员外婆）的莲花广麻，来源固定为提交 `1f1be0079f37a3a5b1a559c29366b23916e1735b`。[上游源码][upstream] · [MIT 许可全文](LIANHUAGUANGDONGMAHJONG-MIT.txt)

| 上游实现 | 福清麻将实现与适配 |
| --- | --- |
| [`tableLayout.ts`][table] 的 `pointFromSeat`、`seatTableLayout`、`meldTrackTransform`、`discardTileLayout` | `godot/scripts/table_layout_3d.gd` 的 `_from_seat`、`_meld_span`、`_meld_poses`、`river_pose` 将座位轴、来源横牌和行列计算用于福清麻将的六列牌河和副露。 |
| [`wallLayout.ts`][wall] 的 `wallStackSlot`、`wallTilePlacement` | `godot/scripts/table_layout_3d.gd` 的 `wall_pose` 按福清麻将的对局槽位摆放四边双层墙，每边 18 墩。 |
| [`staticTableScene.ts`][static] 的 `createStaticTableScene`、`addTable` | `godot/scripts/table_scene_3d.gd` 的 `_build_table` 使用 `table_meshes_3d.gd` 的网格分层构造桌体、木边和桌面，应用本项目桌布。 |
| [`sceneRenderProfile.ts`][profile] 的 `tableCameraPosition`、`responsiveCameraFov` | `godot/scripts/table_scene_3d.gd` 采用固定视点。1280×800 的 3D 视口等比显示，便于维持镜头构图。 |
| [`tileInstanceRenderer.ts`][instances] 的 `createTileInstanceRenderer`、`makeContactShadowTexture`，以及 [`staticTableScene.ts`][static] 的 `atlasCellUvFor` | `table_scene_3d.gd` 的 `TileBatch` 通过 Godot `MultiMesh` 分批渲染牌张。`table_meshes_3d.gd` 的 `shadow_texture` 生成接触阴影。`table_tile_atlas.gd` 和 `godot/assets/effects/table_tile_atlas.gdshader` 用图集与实例偏移选择牌面。 |
| [`tableTilePresenter.ts`][presenter] 的 `createTableTilePresenter`、`rebuildTableTiles`、`sourcePose` | `table_scene_3d.gd` 的 `add_tile`、`add_wall_tile` 接收按区域计算的牌张变换。`project_point` 提供动画与交互使用的屏幕坐标。 |

本项目继续使用各自许可下的桌布、牌面和牌背素材。[牌面与牌背署名](TILE-ART-ATTRIBUTION.md)

[upstream]: https://github.com/BestGuo2020/lianhuaguangdongmahjong/tree/1f1be0079f37a3a5b1a559c29366b23916e1735b
[table]: https://github.com/BestGuo2020/lianhuaguangdongmahjong/blob/1f1be0079f37a3a5b1a559c29366b23916e1735b/src/game/core/presentation/tableLayout.ts
[wall]: https://github.com/BestGuo2020/lianhuaguangdongmahjong/blob/1f1be0079f37a3a5b1a559c29366b23916e1735b/src/game/core/rules/wallLayout.ts
[static]: https://github.com/BestGuo2020/lianhuaguangdongmahjong/blob/1f1be0079f37a3a5b1a559c29366b23916e1735b/src/components/table/three/staticTableScene.ts
[profile]: https://github.com/BestGuo2020/lianhuaguangdongmahjong/blob/1f1be0079f37a3a5b1a559c29366b23916e1735b/src/components/table/three/sceneRenderProfile.ts
[instances]: https://github.com/BestGuo2020/lianhuaguangdongmahjong/blob/1f1be0079f37a3a5b1a559c29366b23916e1735b/src/components/table/three/tileInstanceRenderer.ts
[presenter]: https://github.com/BestGuo2020/lianhuaguangdongmahjong/blob/1f1be0079f37a3a5b1a559c29366b23916e1735b/src/components/table/three/tableTilePresenter.ts
