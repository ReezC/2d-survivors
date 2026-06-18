extends RefCounted
class_name ECSComponentTypes

## ECS 组件类型枚举（位掩码）
enum ComponentType {
	NONE      = 0,
	SKILL     = 1 << 0,
	BUFF      = 1 << 1,
	ATTRIBUTE = 1 << 2,
}

## 组件类型 → 字符串名称映射
static func get_component_name(ctype: int) -> String:
	match ctype:
		ComponentType.SKILL:     return "SkillComponent"
		ComponentType.BUFF:      return "BuffComponent"
		ComponentType.ATTRIBUTE: return "AttributeComponent"
	return "Unknown"

## 字符串名称 → 组件类型映射
static func from_name(name: String) -> int:
	match name:
		"SkillComponent":     return ComponentType.SKILL
		"BuffComponent":      return ComponentType.BUFF
		"AttributeComponent": return ComponentType.ATTRIBUTE
	return ComponentType.NONE
