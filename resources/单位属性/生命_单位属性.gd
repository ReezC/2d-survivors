class_name 生命_单位属性 extends 单位属性


func 获取依赖的属性列表() -> Array[String]:
    return [
        "最大生命值",
    ]

func 属性依赖计算(_计算参数:Array[单位属性]) -> float:
    var 最大生命值属性: 单位属性 = _计算参数[0] if _计算参数.size() > 0 else null
    if 最大生命值属性 == null:
        return self.值
    else :
        var 最大生命值 = 最大生命值属性.获取最终值()
        self.最大值 = 最大生命值
        return clamp(self.值, self.最小值, 最大生命值)
    