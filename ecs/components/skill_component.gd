extends RefCounted
class_name SkillComponentData

## 技能组件 — 纯数据结构（不继承 Node）
## 替代原来的 技能实例.gd

enum 技能状态 {
	准备就绪,
	冷却中,
	已生效,    ## 被动技能 Buff 已创建，防止重复释放
}

var id: int = 0
var 技能名称: String = "未命名"
var 技能类型: int                           ## 技能数据.技能类型枚举
var 冷却时间: float = 0.0
var cd_remaining: float = 0.0              ## 运行时冷却倒计时（由 System 驱动）
var 技能触发范围: float = 0.0
var 动画名称: String = ""
var 当前状态: 技能状态 = 技能状态.准备就绪
var skill_logic_data: Dictionary = {}      ## JSON 配置数据

## 预编译的表达式
var _compiled_cd: Callable
var _compiled_trigger_range: Callable

## 技能本体数据引用（保留，用于初始化）
var 技能本体数据: 技能数据
