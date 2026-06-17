class_name zmap extends Resource


## 渲染层级枚举（从后到前，即枚举顺序即渲染顺序）
enum Layer {
	mobEquipFront,
	tamingMobFront,
	mobEquipMid,
	saddleFront,
	mobEquipUnderSaddle,
	tamingMobMid,
	saddleMid,
	backSaddleFront,
	characterStart,
	emotionOverBody,
	weaponWristOverGloveEffectOver,
	weaponWristOverGlove,
	weaponWristOverGloveEffectUnder,
	capeOverHead,
	weaponOverGloveEffectOver,
	weaponOverGlove,
	weaponOverGloveEffectUnder,
	gloveWristOverHair,
	gloveOverHair,
	handOverHair,
	weaponOverHandEffectOver,
	weaponOverHand,
	weaponOverHandEffectUnder,
	shieldOverHair,
	gloveWristBelowWeapon,
	gloveBelowWeapon,
	handBelowWeapon,
	weaponOverArmEffectOver,
	weaponOverArm,
	weaponOverArmEffectUnder,
	gloveWristBelowMailArm,
	mailArmOverHair,
	gloveBelowMailArm,
	armOverHair,
	mailArmOverHairBelowWeapon,
	armOverHairBelowWeapon,
	weaponBelowArmEffectOver,
	weaponBelowArm,
	weaponBelowArmEffectUnder,
	capOverHair,
	accessoryEarOverHair,
	accessoryOverHair,
	hairOverHead,
	accessoryEyeOverCap,
	capAccessory,
	cap,
	hair,
	capeOverFace,
	accessoryEye,
	accessoryEyeShadow,
	accessoryFace,
	capAccessoryBelowAccFace,
	accessoryEar,
	capBelowAccessory,
	accessoryFaceOverFaceBelowCap,
	face,
	accessoryEyeBelowFace,
	accessoryFaceBelowFace,
	hairShade,
	head,
	cape,
	gloveWrist,
	mailArm,
	glove,
	hand,
	arm,
	weaponEffectOver,
	weapon,
	weaponEffectUnder,
	shield,
	weaponOverArmBelowHeadEffectOver,
	weaponOverArmBelowHead,
	weaponOverArmBelowHeadEffectUnder,
	gloveWristBelowHead,
	mailArmBelowHeadOverMailChest,
	gloveBelowHead,
	armBelowHeadOverMailChest,
	mailArmBelowHead,
	armBelowHead,
	weaponOverBodyEffectOver,
	weaponOverBody,
	weaponOverBodyEffectUnder,
	capeBelowWeapon,
	mailChestTop,
	gloveWristOverBody,
	mailChestOverHighest,
	pantsOverMailChest,
	mailChest,
	shoesTop,
	pantsOverShoesBelowMailChest,
	shoesOverPants,
	mailChestOverPants,
	pants,
	shoes,
	pantsBelowShoes,
	mailChestBelowPants,
	gloveOverBody,
	body,
	gloveWristBelowBody,
	gloveBelowBody,
	capAccessoryBelowBody,
	shieldBelowBody,
	capeBelowBody,
	hairBelowBody,
	weaponBelowBodyEffectOver,
	weaponBelowBody,
	weaponBelowBodyEffectUnder,
	backHairOverCape,
	backWing,
	backWeaponOverShieldEffectOver,
	backWeaponOverShield,
	backWeaponOverShieldEffectUnder,
	backShield,
	backCapOverHair,
	backHair,
	backCap,
	backWeaponOverHeadEffectOver,
	backWeaponOverHead,
	backWeaponOverHeadEffectUnder,
	backHairBelowCapWide,
	backHairBelowCapNarrow,
	backHairBelowCap,
	backCape,
	backAccessoryOverHead,
	backAccessoryFaceOverHead,
	backHead,
	backMailChestOverPants,
	backPantsOverMailChest,
	backMailChest,
	backPantsOverShoesBelowMailChest,
	backShoes,
	backPants,
	backShoesBelowPants,
	backPantsBelowShoes,
	backMailChestBelowPants,
	backWeaponOverGloveEffectOver,
	backWeaponOverGlove,
	backWeaponOverGloveEffectUnder,
	backGloveWrist,
	backGlove,
	backBody,
	backAccessoryEar,
	backAccessoryFace,
	backCapAccessory,
	backMailChestAccessory,
	backShieldBelowBody,
	backHairBelowHead,
	backWeaponEffectOver,
	backWeapon,
	backWeaponEffectUnder,
	characterEnd,
	saddleRear,
	tamingMobRear,
	mobEquipRear,
	backMobEquipFront,
	backTamingMobFront,
	backMobEquipMid,
	backSaddle,
	backMobEquipUnderSaddle,
	backTamingMobMid,
	Sd,
	Tm,
	Sr,
	Wg,
	Ma,
	Ws,
	Pn,
	So,
	Si,
	Wp,
	Gv,
	Ri,
	Cp,
	Ay,
	As,
	Ae,
	Am,
	Af,
	At,
	Fc,
	Hr,
	Hd,
	Bd,
}


## 渲染层级顺序数组（枚举值按顺序排列，用于快速索引）
static var layer_order: Array[Layer] = []
static var _layer_initialized: bool = false


static func _ensure_initialized() -> void:
	if _layer_initialized:
		return
	_layer_initialized = true
	for val in Layer.values():
		layer_order.append(val)


## 获取层级的索引（从后到前，0 为最底层）
func get_layer_index(layer: Layer) -> int:
	_ensure_initialized()
	return layer_order.find(layer)


## 通过名称获取层级的索引（兼容字符串查找）
func get_layer_index_by_name(layer_name: String) -> int:
	_ensure_initialized()
	for i in range(layer_order.size()):
		if Layer.keys()[i] == layer_name:
			return i
	return -1


## 判断 layer_a 是否在 layer_b 前面（先渲染）
func is_front_of(layer_a: Layer, layer_b: Layer) -> bool:
	return get_layer_index(layer_a) < get_layer_index(layer_b)


## 获取层级的总数
func get_layer_count() -> int:
	_ensure_initialized()
	return layer_order.size()


## 获取所有层级名称
static func get_layer_names() -> PackedStringArray:
	_ensure_initialized()
	return Layer.keys()
