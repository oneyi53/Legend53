# HERO WORLD · 传奇

**纯 HTML5 离线竖屏 ARPG**。主运行入口为根目录 index.html，使用原生 JavaScript ES Modules、Canvas 2D、HTML/CSS 和 localStorage；无需游戏服务器或第三方运行时。

## 当前技术路线

- **渲染**：HTML5 Canvas 2D，原创程序化场景与 SVG 角色/怪物素材。
- **界面**：HTML + CSS，竖屏 HUD、触屏按钮、弹窗和背包面板。
- **逻辑**：原生 JavaScript ES Modules，按数据、输入、战斗、渲染、存档拆分。
- **存档**：浏览器 localStorage，支持离线单机。
- **测试**：Node.js 单元测试、语法检查和 GitHub Actions。

## 本地运行

ES Modules 需要通过本地 HTTP 服务打开，不要直接双击 index.html。

```bash
python3 -m http.server 8080
```

浏览器访问：

```text
http://localhost:8080
```

手机可在同一 Wi-Fi 下访问电脑局域网 IP 的 8080 端口。正式部署可使用 GitHub Pages 或任意静态网站托管。

## 当前 HTML5 可玩切片

- 竖屏 Canvas 场景、原创战士/法师/道士 SVG。
- 虚拟触屏摇杆与 WASD/方向键桌面输入。
- 怪物追击、近战攻击、普攻、职业技能、自动战斗。
- 区域推进、精英怪、Boss 出现、经验升级、金币和装备掉落。
- 职业切换、装备穿戴、药水、任务接取与奖励。
- localStorage 自动保存与手动保存。

## 迁移说明

旧 Godot 4.7.2 工程文件目前保留在仓库中，作为迁移前的玩法规则、数据和素材参考，不再作为新功能的主开发入口。HTML5 版本目前是第一阶段可运行底座，Godot 版本中的装备套装、强化/觉醒、材料、完整任务链、NPC 服务、地图解锁和 Boss 多阶段等系统还需要分批迁移，不能将其描述为已全部完成。

迁移计划见 docs/HTML5_MIGRATION.md。

## 项目约束

- 保持纯前端、离线优先；不引入必须联网的后端依赖。
- 只使用原创或明确可合法使用的代码、素材和内容。
- 参考其他游戏的通用玩法规律，不复制商业游戏源代码、美术、文案、协议或可识别表达。
- 每个模块迁移后增加测试；浏览器桌面验证与 Android 真机触屏验证分开记录。
