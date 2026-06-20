class_name EquipSlotConfig extends Resource
## 装备槽位配置 —— 将一个 islot 槽位与 VisualItem 配对

## islot字典，每种只能拥有1个实例，决定了角色的装备类型和可替换部件
@export var islot: Dictionary[islot_enum,VisualItem]

enum islot_enum {
    Bd,	# 身体
    Hd,	# 头部
    Hr,	# 发型
    Fc,	# 脸型
    Af,	# 脸饰
    Ae,	# 耳环
    Ay,	# 眼饰
    Cp,	# 帽子
    Ri,	# 戒指
    Gv,	# 手套
    Wp,	# 武器
    Si,	# 盾牌
    So,	# 鞋子
    Pn,	# 下装
    Ma,	# 上衣
    Sr,	# 披风
    Tm,	# 坐骑
    Sd,	# 鞍子
    Sh,	# 肩饰
    Bi,	# 拼图
    Ba,	# 徽章
    Me,	# 勋章
    Pe,	# 坠子
    Po,	# 口袋物品
    Ss,	# 技能皮肤
}
