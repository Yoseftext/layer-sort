class_name AppSettings
extends RefCounted

var language: String = "en"


func _init() -> void:
	if OS.get_locale_language() == "ar":
		language = "ar"
	TranslationServer.set_locale(language)


func set_language(value: String) -> bool:
	if value != "ar" and value != "en":
		return false
	language = value
	TranslationServer.set_locale(language)
	return true
