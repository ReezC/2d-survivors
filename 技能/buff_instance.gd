extends Node
class_name BuffInstance

## Buff 实例 — 已完全迁移到 ECS
## 此文件仅保留 class_name 和枚举以维持向后兼容（ExprCompiler 注释等仍引用类型名）
## 实际 Buff 逻辑由 ECSWorld.buff_system 管理，数据由 BuffComponentData 承载
## 方法由 BuffSystem 实现，枚举在 BuffComponentData 中有副本

enum buff叠加计时类型枚举 {
	不改变计时,
	叠加时刷新计时,
	每层独立计时,
	延长计时,
}
