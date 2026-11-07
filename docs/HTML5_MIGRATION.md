# HTML5 迁移路线

## 决策

HERO WORLD / 传奇的主开发运行时迁移为原生 HTML5、CSS、JavaScript ES Modules 与 Canvas 2D。目标为离线优先、竖屏手机、无需服务端即可游玩。

## 迁移原则

- 根目录 `index.html` 成为网页版本入口。
- `web/js` 按数据、输入、游戏逻辑、渲染和存档拆分。
- `web/css` 管理移动端 HUD、面板和安全区适配。
- `data/*.json` 后续逐步承接职业、怪物、地图、掉落、装备和任务配置。
- 现有 `assets/` 原创 SVG 继续复用。
- 旧 Godot 工程文件暂时保留作逻辑参考与回退基线；不再作为新功能的主实现位置。
- 不复制第三方商业游戏的源代码、美术、文案、协议或数值；只吸收通用架构和玩法设计。

## 阶段

1. **HTML5 运行底座（本次）**：竖屏画布、触屏/键盘输入、原创地图绘制、角色/怪物、普攻/技能/自动战斗、经验金币掉落、背包面板和 localStorage。
2. **系统迁移**：逐个迁移现有 Godot 已实现的职业技能、装备词缀、套装、锻造/觉醒、任务、Boss 阶段和 NPC 服务。
3. **内容数据化**：把 Godot 脚本中的静态配置迁移为可校验 JSON；配置和逻辑分离。
4. **质量与发布**：单元测试、移动端浏览器回归、PWA 缓存、离线安装、性能和存档迁移工具。

## 当前切片边界

本次是可运行的 HTML5 原型底座，不声称已迁移完整 Godot 系统。旧版 Godot 的装备成长、Boss、任务与存档规则将分批迁移并进行规则对照测试。


## 与既有 Godot 项目的代码复用边界

已核对用户提供的另一个仓库 oneyi53/game：它当前同样是 Godot/GDScript 项目，不是 HTML5 项目。因此 GDScript 不能直接在浏览器中运行；可复用的是规则、数据结构、资源和模块职责，再迁移为 JavaScript。

| 既有 Godot 模块 | HTML5 对应位置 | 迁移方式 |
|---|---|---|
| PlayerController | web/js/game.js + input.js | 将属性、移动、升级和存档行为转换为 JS |
| CombatDirector / EnemyController | web/js/game.js | 转换索敌、攻击、伤害、掉落和 Boss 规则 |
| IsometricWorld | web/js/renderer.js | 用 Canvas 重建地图绘制和区域表现 |
| BattleHUD / TouchControls | index.html + game.css + input.js | 用 DOM/CSS 控件和 Pointer Events 重建 |
| QuestDirector | web/js/game.js（后续拆分 quest.js） | 迁移任务状态机、进度和奖励 |
| JSON 数据表 | web/js/data.js / data/*.json | 字段兼容时可直接复用 JSON，逐项校验后接入 |
| SaveManager | web/js/storage.js | 转换为 localStorage，并增加版本迁移和备份策略 |

### 复用原则

- 优先复用通用数值、字段定义、掉落表结构、任务状态机、装备属性和验证用例。
- 另一仓库中的英雄小队、编队、营地等系统与本项目的单角色传奇 ARPG 定位不同；不会未经设计就整套搬入。
- 用户此前提供的对标游戏代码若为 JavaScript/TypeScript，可在确认依赖、许可证和运行环境后直接复用合适模块；若为 GDScript，则必须逐项移植，不能简单改扩展名。
- 迁移时保持原系统的行为测试，先对齐规则，再优化网页实现；不把两个项目不同的经济数值和内容混为一套。
