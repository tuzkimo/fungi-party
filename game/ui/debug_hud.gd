extends CanvasLayer

@onready var _label: Label = $Label

func _process(_delta: float) -> void:
	_label.text = "FPS %d  DRAW %d  TRI %d" % [
		Engine.get_frames_per_second(),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
	]
