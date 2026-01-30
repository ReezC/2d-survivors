# skill_system.gd
extends Node
class_name SkillSystem

# 技能数据类型枚举
enum SkillActionType {
    DAMAGE,
    MODIFY_ATTRIBUTE,
    ACTION_IF_ELSE,
    ACTION_MULTI,
    ADD_BUFF
}

enum DamageElementType {
    PHYSICS,
    LIGHTNING,
    FIRE
}
