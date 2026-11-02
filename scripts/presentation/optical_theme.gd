class_name OpticalTheme
extends RefCounted

## Gameplay-only Optical Clarity tokens. No global theme mutation.
const NAVY: Color = Color("111b2c")
const INK: Color = Color("f4f7fc")
const MUTED: Color = Color("aabbd0")
const ACCENT: Color = Color("75d7ea")
const LATIN: FontFile = preload("res://content/fonts/Manrope.ttf")
const ARABIC: FontFile = preload("res://content/fonts/NotoSansArabic.ttf")

static func create() -> Theme:
	var result: Theme = Theme.new()
	var font: FontVariation = FontVariation.new()
	font.base_font = LATIN
	font.variation_opentype = {2003265652: 550.0} # OpenType wght axis.
	var arabic: FontVariation = FontVariation.new()
	arabic.base_font = ARABIC
	arabic.variation_opentype = {2003265652: 500.0}
	font.fallbacks = [arabic]
	result.default_font = font
	result.set_color("font_color", "Label", INK)
	return result

static func style_button(button: Button) -> void:
	for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.bg_color = Color("1c2a40") if state != "pressed" else Color("29445a")
		style.border_color = Color("3b566c") if state != "focus" else ACCENT
		style.set_border_width_all(1 if state != "focus" else 2)
		style.set_corner_radius_all(20)
		style.set_content_margin_all(18)
		button.add_theme_stylebox_override(state, style)
	button.add_theme_color_override("font_color", INK)
	button.add_theme_color_override("font_disabled_color", MUTED)
