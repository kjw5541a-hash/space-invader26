extends SceneTree

func _init() -> void:
	for f in ["shoot.ogg", "boom.ogg", "hit.ogg", "wave.ogg",
			"boss.ogg", "over.ogg", "tick.ogg", "big.ogg"]:
		var s = load("res://assets/audio/" + f)
		if s == null:
			print("FAIL ", f)
		else:
			print("OK   ", f, " len=%.2f" % (s as AudioStream).get_length())
	var bgm = load("res://assets/audio/apex.mp3")
	if bgm == null:
		print("FAIL apex.mp3")
	else:
		print("OK   apex.mp3 len=%.2f" % (bgm as AudioStream).get_length())
	var vg = load("res://assets/audio/vanguard.mp3")
	if vg == null:
		print("FAIL vanguard.mp3")
	else:
		print("OK   vanguard.mp3 len=%.2f" % (vg as AudioStream).get_length())
	quit()
