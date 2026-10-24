class_name MushroomSkin
extends Resource

## 一顶皮肤的完整外观：两个色 + 斑点 + 挂在头上的零件。
## 零件名必须在 SkinCatalog.PART_NAMES 里，MushroomMesh 才认得。
## 这里是所有默认值的唯一来源：use_skin(null) 就用这里的一套。

enum SpotShape { ROUND, STAR, BLOB }

@export var id := ""
@export var display_name := ""
@export var rarity := 0
@export var tint_cap := Color(0.90, 0.22, 0.20)
@export var tint_body := Color(0.96, 0.78, 0.62)
@export var spot_count := 7
@export var spot_shape := SpotShape.ROUND
@export var spot_color := Color(0.99, 0.97, 0.94)
@export var spot_glow := 0.0
@export var parts: Array[String] = []
@export var cap_tilt := 0.0
@export var cap_squash := 0.0
