class_name RaceCourse
extends Node3D

## 按 RaceField 把赛道建出来：地面、护栏、起终点拱门、每组障碍的碰撞与外观。
## 只建静态几何，不知道玩家存在。

const GROUND_COLOR := Color(0.62, 0.48, 0.33)
const RAIL_COLOR := Color(0.42, 0.30, 0.20)
const TALL_COLOR := Color(0.16, 0.42, 0.30)
const LOW_COLOR := Color(0.72, 0.48, 0.26)
const ARCH_COLOR := Color(0.78, 0.30, 0.26)
const FINISH_COLOR := Color(0.94, 0.86, 0.32)
const LINE_COLOR := Color(0.96, 0.96, 0.92)

const TALL_HEIGHT := 2.2
const LOW_HEIGHT := 0.6
const BLOCK_DEPTH := 0.5
const RAIL_HEIGHT := 0.9
const RAIL_WIDTH := 0.3
const ARCH_HEIGHT := 3.4
const GROUND_DEPTH := 0.2
const END_MARGIN := 3.0
const END_WALL_HEIGHT := 3.0


func build(field: RaceField) -> void:
	_build_environment()
	var length := Config.RACE_TRACK_LENGTH
	var half := Config.RACE_TRACK_HALF_WIDTH

	var ground := StaticBody3D.new()
	ground.name = "Ground"
	add_child(ground)
	_block(ground, Vector3(half * 2.0, GROUND_DEPTH, length + END_MARGIN * 2.0), Vector3(0.0, -GROUND_DEPTH * 0.5, length * 0.5), _solid(GROUND_COLOR))
	# 两端封死：裁判区之外没有地面，跑出去会直接掉出世界
	for end_z in [-END_MARGIN + 0.4, length + END_MARGIN - 0.4]:
		var wall := StaticBody3D.new()
		wall.name = "EndWall"
		add_child(wall)
		_block(wall, Vector3(half * 2.0, END_WALL_HEIGHT, 0.8), Vector3(0.0, END_WALL_HEIGHT * 0.5, end_z), _solid(RAIL_COLOR))
	for side in [-1.0, 1.0]:
		var rail := StaticBody3D.new()
		rail.name = "Rail"
		add_child(rail)
		_block(rail, Vector3(RAIL_WIDTH, RAIL_HEIGHT, length), Vector3(side * (half + RAIL_WIDTH * 0.5), RAIL_HEIGHT * 0.5, length * 0.5), _solid(RAIL_COLOR))

	_arch("StartArch", Vector3(0.0, 0.0, 0.0), ARCH_COLOR)
	_arch("FinishArch", Vector3(0.0, 0.0, length), FINISH_COLOR)
	_plain("FinishLine", Vector3(half * 2.0 - 0.2, 0.02, 0.6), Vector3(0.0, 0.01, length), _solid(LINE_COLOR))

	var tall_mat := _solid(TALL_COLOR)
	var low_mat := _solid(LOW_COLOR)
	for i in field.groups.size():
		var group: RaceField.Group = field.groups[i]
		var body := StaticBody3D.new()
		body.name = "Group%d" % i
		body.add_to_group("hazard")
		add_child(body)
		var height := TALL_HEIGHT if group.kind == RaceField.TALL else LOW_HEIGHT
		var material := tall_mat if group.kind == RaceField.TALL else low_mat
		var left_end := group.gap_x - group.gap_width * 0.5
		var right_start := group.gap_x + group.gap_width * 0.5
		if left_end > -half:
			var width := left_end + half
			_block(body, Vector3(width, height, BLOCK_DEPTH), Vector3(-half + width * 0.5, height * 0.5, group.z), material)
		if right_start < half:
			var width := half - right_start
			_block(body, Vector3(width, height, BLOCK_DEPTH), Vector3(half - width * 0.5, height * 0.5, group.z), material)


func _arch(node_name: String, pos: Vector3, color: Color) -> void:
	var material := _solid(color)
	var half := Config.RACE_TRACK_HALF_WIDTH
	_plain(node_name + "PostL", Vector3(0.3, ARCH_HEIGHT, 0.3), pos + Vector3(-half, ARCH_HEIGHT * 0.5, 0.0), material)
	_plain(node_name + "PostR", Vector3(0.3, ARCH_HEIGHT, 0.3), pos + Vector3(half, ARCH_HEIGHT * 0.5, 0.0), material)
	_plain(node_name + "Lintel", Vector3(half * 2.0 + 0.3, 0.35, 0.35), pos + Vector3(0.0, ARCH_HEIGHT, 0.0), material)


func _plain(node_name: String, size: Vector3, pos: Vector3, material: Material) -> void:
	var node := MeshInstance3D.new()
	node.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.material_override = material
	node.position = pos
	add_child(node)


## 一块看得见也撞得到的方块：视觉与碰撞同尺寸。
func _block(parent: Node3D, size: Vector3, pos: Vector3, material: Material) -> void:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.material_override = material
	node.position = pos
	parent.add_child(node)

	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = pos
	parent.add_child(shape)


func _build_environment() -> void:
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-55.0, -35.0, 0.0)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 40.0
	add_child(sun)

	var sky := Sky.new()
	sky.sky_material = ProceduralSkyMaterial.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	var world := WorldEnvironment.new()
	world.name = "Environment"
	world.environment = env
	add_child(world)


func _solid(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	return material
