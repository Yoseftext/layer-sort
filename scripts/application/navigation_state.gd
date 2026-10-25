class_name NavigationState
extends RefCounted

enum Route { SPLASH, HOME, SETTINGS, ABOUT, GAME }

var route: Route = Route.SPLASH
var level_id: String = ""


func open_home() -> void:
	route = Route.HOME
	level_id = ""


func open_settings() -> void:
	route = Route.SETTINGS


func open_about() -> void:
	route = Route.ABOUT


func open_game(id: String) -> void:
	route = Route.GAME
	level_id = id


func back() -> bool:
	if route == Route.HOME:
		return false
	open_home()
	return true
