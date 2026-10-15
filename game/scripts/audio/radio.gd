class_name Radio
extends Node
## SA NU FM, the in-car radio. Plays every .ogg, .mp3 or .wav in
## res://audio/radio/ (drop the album tracks in there). Plays while you drive,
## stops when you get out, like San Andreas. Press R in the car to skip.

signal station_changed(station: String, track: String)

const STATION := "SA NU FM"
const TRACK_DIR := "res://audio/radio"
const EXTENSIONS := ["ogg", "mp3", "wav"]

var tracks: PackedStringArray = []
var index := 0
var on := false

var _player := AudioStreamPlayer.new()


func _ready() -> void:
	_player.bus = "Master"
	_player.volume_db = -4.0
	add_child(_player)
	_player.finished.connect(next_track)
	_scan()


func _scan() -> void:
	tracks.clear()
	if not DirAccess.dir_exists_absolute(TRACK_DIR):
		return
	for f in DirAccess.get_files_at(TRACK_DIR):
		# In exported games the folder lists "song.ogg.import"; strip that back off.
		var file := f.trim_suffix(".import").trim_suffix(".remap")
		if file.get_extension().to_lower() in EXTENSIONS and not tracks.has(file):
			tracks.append(TRACK_DIR.path_join(file))
	tracks.sort()


func track_title() -> String:
	if tracks.is_empty():
		return "No tracks yet"
	return tracks[index].get_file().get_basename()


func turn_on() -> void:
	on = true
	if not tracks.is_empty():
		if _player.stream == null:
			_load_current()
		_player.stream_paused = false
		if not _player.playing:
			_player.play()
	station_changed.emit(STATION, track_title())


func turn_off() -> void:
	on = false
	_player.stream_paused = true


func next_track() -> void:
	if tracks.is_empty():
		station_changed.emit(STATION, track_title())
		return
	index = (index + 1) % tracks.size()
	_load_current()
	if on:
		_player.play()
		station_changed.emit(STATION, track_title())


func _load_current() -> void:
	var stream := load(tracks[index]) as AudioStream
	_player.stream = stream


func _unhandled_input(event: InputEvent) -> void:
	if on and event.is_action_pressed("radio_next"):
		next_track()
