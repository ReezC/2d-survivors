extends Node2D
class_name CharacterBody
## 角色身体数据容器 —— 纯数据存储，不包含任何 PaperDollAnimator 逻辑
##
## 挂载在角色根节点下。通过 装备槽位 配置各个 slot 对应的 VisualItem。
## 纸娃娃渲染由 PaperDollAnimator 自主读取本节点数据并驱动。

## 装备槽位配置，将 islot（Bd/Hd/Wp/...）与 VisualItem 配对
@export var 装备槽位: EquipSlotConfig


# ============================================================
#  部件绑定 —— 手动将 视觉 下的预制 VisualItemPart 拖入对应槽位
#  部件叫什么名字无所谓，只要绑定到对应 islot 即可
# ============================================================

@export var Bd_身体部件列表: Array[Node]	# 对应 islot_enum.Bd
@export var Hd_头部部件列表: Array[Node]	# 对应 islot_enum.Hd
@export var Hr_发型部件列表: Array[Node]	# 对应 islot_enum.Hr
@export var Fc_脸型部件列表: Array[Node]	# 对应 islot_enum.Fc
@export var Af_脸饰部件列表: Array[Node]	# 对应 islot_enum.Af
@export var Ae_耳环部件列表: Array[Node]	# 对应 islot_enum.Ae
@export var Ay_眼饰部件列表: Array[Node]	# 对应 islot_enum.Ay
@export var Cp_帽子部件列表: Array[Node]	# 对应 islot_enum.Cp
@export var Ri_戒指部件列表: Array[Node]	# 对应 islot_enum.Ri
@export var Gv_手套部件列表: Array[Node]	# 对应 islot_enum.Gv
@export var Wp_武器部件列表: Array[Node]	# 对应 islot_enum.Wp
@export var Si_盾牌部件列表: Array[Node]	# 对应 islot_enum.Si
@export var So_鞋子部件列表: Array[Node]	# 对应 islot_enum.So
@export var Pn_下装部件列表: Array[Node]	# 对应 islot_enum.Pn
@export var Ma_上衣部件列表: Array[Node]	# 对应 islot_enum.Ma
@export var Sr_披风部件列表: Array[Node]	# 对应 islot_enum.Sr
@export var Tm_坐骑部件列表: Array[Node]	# 对应 islot_enum.Tm
@export var Sd_鞍子部件列表: Array[Node]	# 对应 islot_enum.Sd
@export var Sh_肩饰部件列表: Array[Node]	# 对应 islot_enum.Sh
@export var Bi_拼图部件列表: Array[Node]	# 对应 islot_enum.Bi
@export var Ba_徽章部件列表: Array[Node]	# 对应 islot_enum.Ba
@export var Me_勋章部件列表: Array[Node]	# 对应 islot_enum.Me
@export var Pe_坠子部件列表: Array[Node]	# 对应 islot_enum.Pe
@export var Po_口袋部件列表: Array[Node]	# 对应 islot_enum.Po
@export var Ss_技能皮肤部件列表: Array[Node]	# 对应 islot_enum.Ss


## 视觉容器节点引用
var _visual_node: Node2D

## islot_enum → Array[Node] 快速查询映射（_ready() 时构建）
var _slot_part_map: Dictionary = {}


func _ready() -> void:
	if 装备槽位 == null:
		push_error("CharacterBody: 未配置装备槽位")
		return

	_visual_node = _find_visual()
	_build_slot_part_map()


# ============================================================
#  槽位 → 部件 映射
# ============================================================

func _find_visual() -> Node2D:
	var player_root := get_parent()
	if player_root == null:
		return null
	return player_root.get_node_or_null("视觉") as Node2D


func _build_slot_part_map() -> void:
	"""将 @export 数组按 islot_enum 建立快速查询映射"""
	_slot_part_map = {
		EquipSlotConfig.islot_enum.Bd: Bd_身体部件列表,
		EquipSlotConfig.islot_enum.Hd: Hd_头部部件列表,
		EquipSlotConfig.islot_enum.Hr: Hr_发型部件列表,
		EquipSlotConfig.islot_enum.Fc: Fc_脸型部件列表,
		EquipSlotConfig.islot_enum.Af: Af_脸饰部件列表,
		EquipSlotConfig.islot_enum.Ae: Ae_耳环部件列表,
		EquipSlotConfig.islot_enum.Ay: Ay_眼饰部件列表,
		EquipSlotConfig.islot_enum.Cp: Cp_帽子部件列表,
		EquipSlotConfig.islot_enum.Ri: Ri_戒指部件列表,
		EquipSlotConfig.islot_enum.Gv: Gv_手套部件列表,
		EquipSlotConfig.islot_enum.Wp: Wp_武器部件列表,
		EquipSlotConfig.islot_enum.Si: Si_盾牌部件列表,
		EquipSlotConfig.islot_enum.So: So_鞋子部件列表,
		EquipSlotConfig.islot_enum.Pn: Pn_下装部件列表,
		EquipSlotConfig.islot_enum.Ma: Ma_上衣部件列表,
		EquipSlotConfig.islot_enum.Sr: Sr_披风部件列表,
		EquipSlotConfig.islot_enum.Tm: Tm_坐骑部件列表,
		EquipSlotConfig.islot_enum.Sd: Sd_鞍子部件列表,
		EquipSlotConfig.islot_enum.Sh: Sh_肩饰部件列表,
		EquipSlotConfig.islot_enum.Bi: Bi_拼图部件列表,
		EquipSlotConfig.islot_enum.Ba: Ba_徽章部件列表,
		EquipSlotConfig.islot_enum.Me: Me_勋章部件列表,
		EquipSlotConfig.islot_enum.Pe: Pe_坠子部件列表,
		EquipSlotConfig.islot_enum.Po: Po_口袋部件列表,
		EquipSlotConfig.islot_enum.Ss: Ss_技能皮肤部件列表,
	}


# ============================================================
#  公共查询接口
# ============================================================

## 获取某个槽位当前绑定的 VisualItemPart 列表（供 PaperDollAnimator 查询）
func get_slot_parts(slot_key: EquipSlotConfig.islot_enum) -> Array:
	return _slot_part_map.get(slot_key, [])


# ============================================================
#  碰撞形状翻转（物理层，与渲染无关）
# ============================================================

var _original_collision_positions: Dictionary = {}


func set_face_direction(direction: int) -> void:
	"""仅翻转碰撞形状（视觉翻转由 PaperDollAnimator 负责）"""
	_flip_collision_shapes(direction)


func _flip_collision_shapes(direction: int) -> void:
	"""同步翻转碰撞形状的 x 位置，匹配视觉镜像翻转"""
	var player_root := get_parent()
	if player_root == null:
		return

	_flip_one_collision(player_root.get_node_or_null("移动碰撞"), direction)

	var hurtbox := player_root.get_node_or_null("HurtboxComponent")
	if hurtbox:
		_flip_one_collision(hurtbox.get_node_or_null("CollisionShape2D"), direction)


func _flip_one_collision(shape: CollisionShape2D, direction: int) -> void:
	if shape == null:
		return
	var key := str(shape.get_path())
	if key not in _original_collision_positions:
		_original_collision_positions[key] = shape.position
	var orig := _original_collision_positions[key] as Vector2
	shape.position.x = abs(orig.x) * direction
