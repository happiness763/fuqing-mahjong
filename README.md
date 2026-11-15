# 福清麻将 · 融城茶馆

四人福清麻将小游戏。当前 Godot 版为 **v1.2.7**，可与三名 AI 单机对局，也可以通过局域网或 UDP 内网穿透和朋友开房。

## 运行和测试

1. 用 Godot 4.7.2 导入 [godot/project.godot](godot/project.godot)。
2. 按 **F5** 启动。Windows 导出使用项目自带的 **Windows Desktop** 预设，并安装同版本的 Godot 导出模板。
3. 从仓库根目录运行下列命令。将 `godot` 替换为本机 Godot 可执行文件路径。

```text
godot --headless --path godot --editor --import
godot --headless --path godot --script res://tests/v122_game_test.gd
godot --headless --path godot --script res://tests/v122_scoring_test.gd
godot --headless --path godot --script res://tests/win_pattern_test.gd
godot --headless --path godot --script res://tests/v124_opening_test.gd
godot --headless --path godot --script res://tests/v127_center_test.gd
godot --headless --path godot --script res://tests/v126_pass_test.gd
godot --headless --path godot --script res://tests/v126_wall_test.gd
godot --headless --path godot --script res://tests/v126_dice_test.gd
godot --headless --path godot --script res://tests/v126_interaction_test.gd
godot --headless --path godot --script res://tests/online_rules_test.gd
godot --headless --path godot --script res://tests/online_room_test.gd
```

## 参与开发

- 从 `main` 创建功能分支，完成后向 `main` 提交 Pull Request。说明改动、复现或操作步骤，以及运行过的测试。
- 牌型与计分在 `godot/scripts/rules.gd`，牌局流程在 `game.gd`，AI 在 `opponent.gd`，联机房间和同步在 `online_room.gd`。相关测试放在 `godot/tests/`。
- 修改规则前查看 [v1.2.2 规则设计稿](docs/superpowers/specs/2026-11-12-godot-mahjong-v1.2.2-design.md)；界面与开局体验见 [v1.2.4 设计稿](docs/superpowers/specs/2026-11-12-godot-mahjong-v1.2.4-design.md)。修改争牌、抢杠或结算时，验证单机和联机两条入口。
- 根目录的 `index.html`、`src/` 和 `test/` 是早期网页版，可用 `node --test` 运行测试。当前游戏开发入口是 `godot/`。

## 联机和资源

- [v1.2.7 联机说明](release/联机说明-v1.2.7.md)
- [v1.2.7 更新说明](release/更新说明-v1.2.7.md)
- [v1.2.7 设计稿](docs/superpowers/specs/2026-11-15-godot-mahjong-v1.2.7-design.md)
- [牌面来源](godot/assets/tiles/CREDITS.md)及 [第三方许可](release/licenses/)
