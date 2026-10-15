extends Node
## Global game state, available everywhere as `Game`.
## Holds the Trust meters and the Drama meter (this game's version of wanted stars).

signal trust_changed(who: String, value: float, change: float)
signal drama_changed(value: float)
signal notice(text: String, color: Color)

const DRAMA_MAX := 5.0
const DRAMA_DECAY_DELAY := 7.0 ## seconds without new drama before it starts to cool off
const DRAMA_DECAY_RATE := 0.18 ## phones per second

var trust := {"janae": 60.0, "jessica": 50.0, "brandon": 55.0}
var drama := 0.0
var drama_peak := 0.0
var flags := {}

var _quiet := 0.0


func reset() -> void:
	trust = {"janae": 60.0, "jessica": 50.0, "brandon": 55.0}
	drama = 0.0
	drama_peak = 0.0
	flags.clear()
	drama_changed.emit(drama)
	for who in trust:
		trust_changed.emit(who, trust[who], 0.0)


func add_trust(who: String, amount: float) -> void:
	trust[who] = clampf(trust.get(who, 50.0) + amount, 0.0, 100.0)
	trust_changed.emit(who, trust[who], amount)
	var sign_text := "+" if amount > 0 else ""
	notice.emit("%s trust %s%d" % [who.capitalize(), sign_text, int(amount)], Color("7fd0c3") if amount > 0 else Color("ff6f91"))


func add_drama(amount: float, why: String = "") -> void:
	drama = minf(DRAMA_MAX, drama + amount)
	drama_peak = maxf(drama_peak, drama)
	_quiet = 0.0
	drama_changed.emit(drama)
	if why != "":
		notice.emit(why, Color("ff6f91"))


func _process(delta: float) -> void:
	_quiet += delta
	if _quiet > DRAMA_DECAY_DELAY and drama > 0.0:
		drama = maxf(0.0, drama - DRAMA_DECAY_RATE * delta)
		drama_changed.emit(drama)
