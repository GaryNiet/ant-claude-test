extends Node
## Autoload that plays the background music (on every screen, looping) and the sound
## effects. Sound files are made by tools/make_sounds.py, in [sound] folder.
## Each effect has its own volume and a shortest time between two plays (in [sound]), so a
## burst of events (many hatches at once) doesn't turn into noise. The player sets the
## music and effects volumes in the Settings menu (see PlayerSettings).

var _music: AudioStreamPlayer
var _effects := {}        ## effect name -> AudioStream
var _last_played := {}    ## effect name -> time it last started (milliseconds)
var _voices: Array[AudioStreamPlayer] = []  ## players for effects, used in turn
var _next_voice := 0

var _folder: String = GameSettings.get_setting("sound", "folder")


func _ready() -> void:
	_music = AudioStreamPlayer.new()
	_music.stream = load("%s/%s" % [_folder, GameSettings.get_setting("sound", "music_file")])
	_music.finished.connect(_music.play)  # loop
	add_child(_music)
	for effect in GameSettings.get_list("sound", "effects"):
		_effects[effect] = load("%s/%s.wav" % [_folder, effect])
	for voice in int(GameSettings.get_setting("sound", "effect_voices")):
		var player := AudioStreamPlayer.new()
		add_child(player)
		_voices.append(player)
	apply_volumes()
	_music.play()


## Plays the effect `effect` (one of [sound] effects), unless it played too recently.
func play(effect: String) -> void:
	var now := Time.get_ticks_msec()
	var min_interval: float = GameSettings.get_setting("sound", "%s_min_interval" % effect)
	if now - int(_last_played.get(effect, -1000000)) < min_interval * 1000.0:
		return
	_last_played[effect] = now
	var player := _voices[_next_voice]
	_next_voice = (_next_voice + 1) % _voices.size()
	player.stream = _effects[effect]
	player.volume_db = GameSettings.get_setting("sound", "%s_volume_db" % effect) + linear_to_db(PlayerSettings.effects_volume())
	player.play()


## Sets the music volume from the player's choice (call after it changed).
func apply_volumes() -> void:
	_music.volume_db = GameSettings.get_setting("sound", "music_volume_db") + linear_to_db(PlayerSettings.music_volume())
	_music.stream_paused = PlayerSettings.music_volume() <= 0.0
