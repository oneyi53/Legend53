# HTML5 迁移说明

HERO WORLD 新运行时采用纯 HTML5：HTML 页面结构、CSS HUD/弹窗/触控、原生 JavaScript ES Modules 逻辑、Canvas 绘制 2D/伪 2.5D 世界。第一阶段不引入 Phaser/Pixi/Three.js。

Godot 项目先保留为 legacy/reference。GDScript 不能直接在浏览器执行，需逐模块改写为 JavaScript。优先复用原创 SVG、美术、设计文档、数据语义和玩法规则；后续逐步迁移背包装备、任务、技能成长、掉落表、地图、Boss 阶段和存档。当前网页存档与 Godot user:// 存档尚不互通，需后续开发有备份保护的导入工具。