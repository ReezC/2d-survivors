class_name 最大生命值_单位属性 extends 单位属性



func 获取依赖的属性列表() -> Array[String]:
    return [
        "最大生命值加成",
    ]

func 属性依赖计算(_计算参数:Array[单位属性]) -> float:
    var 最大生命值加成属性: 单位属性 = _计算参数[0] if _计算参数.size() > 0 else null
    if 最大生命值加成属性 == null:
        return self.值
    else :
        var 最大生命值加成 = 最大生命值加成属性.获取最终值()
        return self.值 * (1.0 + 最大生命值加成)