# 技术架构

## 分层
表现层：场景、动画、UI、音效、特效、镜头。
领域层：战斗、英雄、AI、装备、关卡、任务与成长规则。
数据层：英雄、怪物、技能、装备、掉落与关卡配置。
基础服务：存档、场景路由、事件总线、配置加载、日志。

## 核心服务
GameManager、SceneRouter、EventBus、DataRegistry、SaveManager、CombatDirector、TargetingComponent、StatsComponent、SkillController、LootService。

## 数据规范
所有实体使用稳定 ID，不以显示名称作为主键。配置导入检查 ID 重复、引用缺失、字段缺失、数值越界和掉落权重异常。

## 存档
存档包含 schema_version、时间戳、章节进度、英雄成长、装备背包、货币、任务和设置。先写临时文件，校验后替换正式文件，保留备份；加载时执行版本迁移，损坏时回退并提示。

## 性能
避免每帧全场景昂贵寻敌；采用空间分区或定时感知。远处 AI 降频，控制粒子和透明叠层。性能目标以 Android 实机报告为准。
