class_name LocalizationManager
extends RefCounted

const LANGUAGES := ["auto", "en", "uk", "pl", "de", "es", "fr"]
const LABELS := ["", "English", "Українська", "Polski", "Deutsch", "Español", "Français"]

static func apply(preference: String) -> void:
	var language := OS.get_locale_language() if preference == "auto" else preference
	TranslationServer.set_locale(language if language in LANGUAGES and language != "auto" else "en")
