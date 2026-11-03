extends Node

func _ready() -> void:
	print("[ScreenshotCapturer] Initializing capture sequence...")
	# Allow game systems, shaders and forest chunks to initialize
	for i in range(15):
		await get_tree().process_frame

	var main_scene = get_tree().current_scene
	if main_scene == null:
		print("[ERROR] No current scene found!")
		get_tree().quit(1)
		return

	# Create a dedicated high-quality camera for screenshots
	var cam = Camera3D.new()
	cam.current = true
	cam.fov = 68.0
	cam.near = 0.1
	cam.far = 1000.0
	main_scene.add_child(cam)

	var captures = [
		{
			"id": "crafting",
			"pos": Vector3(3.5, 2.0, -10.5),
			"look_at": Vector3(0.0, 1.2, -15.0),
			"hour": 14.0
		},
		{
			"id": "forest",
			"pos": Vector3(8.0, 2.8, 18.0),
			"look_at": Vector3(25.0, 4.0, 45.0),
			"hour": 10.5
		},
		{
			"id": "fishing",
			"pos": Vector3(18.5, -6.0, 300.0),
			"look_at": Vector3(15.0, -7.5, 315.0),
			"hour": 8.0
		},
		{
			"id": "zombies",
			"pos": Vector3(-14.0, 2.0, -20.0),
			"look_at": Vector3(-20.0, 1.2, -28.0),
			"hour": 21.5
		}
	]

	var time_mgr = main_scene.get_node_or_null("TimeManager")
	var dir_path = "res://screenshots"
	var dir = DirAccess.open("res://")
	if not dir.dir_exists("screenshots"):
		dir.make_dir("screenshots")

	for cap in captures:
		var cap_id: String = cap["id"]
		var cap_pos: Vector3 = cap["pos"]
		var cap_look: Vector3 = cap["look_at"]
		var cap_hour: float = cap["hour"]

		print("[ScreenshotCapturer] Setting up shot: %s" % cap_id)
		if time_mgr and time_mgr.has_method("set_time_of_day"):
			time_mgr.set_time_of_day(cap_hour)
		elif ValleyEcology and ValleyEcology.has_method("set_time_of_day"):
			ValleyEcology.set_time_of_day(cap_hour)

		cam.global_position = cap_pos
		cam.look_at(cap_look, Vector3.UP)

		# Wait for rendering to settle
		for f in range(6):
			await get_tree().process_frame
		await RenderingServer.frame_post_draw

		var vp = get_viewport()
		var img: Image = vp.get_texture().get_image()
		var file_path = "res://screenshots/raw_%s.png" % cap_id
		var err = img.save_png(file_path)
		if err == OK:
			print("[ScreenshotCapturer] Saved %s successfully (%dx%d)" % [file_path, img.get_width(), img.get_height()])
		else:
			print("[ScreenshotCapturer] Failed to save %s, code: %d" % [file_path, err])

	print("[ScreenshotCapturer] All raw screenshots captured successfully!")
	get_tree().quit(0)
