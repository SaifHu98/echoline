class_name SafeConfirmDialog
extends AcceptDialog

# ECHO//LINE — Safe Confirmation Dialog
# =====================================
# للعمليات الحساسة فقط. صُمّم لمنع:
# - النقرات المكررة (debounce)
# - التأكيد الخاطئ (زر Cancel واضح ومرئي)
# - اللغة الغامضة (نص واضح بـ "Yes, I'm sure" / "نعم، متأكد")
# - الإلغاء السريع (Escape يعمل دائماً)

const DEBOUNCE_MS = 500
const MIN_TOUCH_TARGET = 48

signal confirmed(operation: String)
signal cancelled(operation: String)

var _operation: String = ""
var _last_action_time: int = 0
var _confirm_btn: Button = null
var _cancel_btn: Button = null
var _warning_label: Label = null


static func show(parent: Node, operation: String, title: String, body: String,
		warning_text: String = "", is_destructive: bool = false,
		on_confirm: Callable = Callable()) -> SafeConfirmDialog:

	var dlg := SafeConfirmDialog.new()
	parent.add_child(dlg)

	dlg._operation = operation
	dlg.title = title
	dlg.dialog_text = body
	dlg._build_buttons(warning_text, is_destructive, on_confirm)
	dlg.popup_centered()
	return dlg


func _build_buttons(warning_text: String, is_destructive: bool, on_confirm: Callable) -> void:
	# نضيف custom buttons بدلاً من OK/Cancel الافتراضية
	add_button(Localization.tr_key("common.cancel"), false, "cancel")
	add_button(Localization.tr_key("common.confirm"), true, "confirm")

	# إخفاء الزر الافتراضي OK من AcceptDialog الأصلي
	get_label().autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	if warning_text != "":
		_warning_label = Label.new()
		_warning_label.text = "⚠ " + warning_text
		_warning_label.add_theme_color_override("font_color", Color(1, 0.7, 0.2))
		add_child(_warning_label)

	# تأكيد صريح — لا يمكن أن يكون مجرد "OK"
	_confirm_btn = get_ok_button()
	if _confirm_btn:
		_confirm_btn.text = Localization.tr_key(
			"common.yes_i_understand" if is_destructive else "common.confirm")
		_confirm_btn.custom_minimum_size = Vector2(MIN_TOUCH_TARGET * 2, MIN_TOUCH_TARGET)
		_confirm_btn.pressed.connect(_on_confirm.bind(on_confirm))

	# Cancel واضح ومرئي
	_cancel_btn = get_cancel_button()
	if _cancel_btn:
		_cancel_btn.text = Localization.tr_key("common.cancel")
		_cancel_btn.custom_minimum_size = Vector2(MIN_TOUCH_TARGET * 2, MIN_TOUCH_TARGET)
		_cancel_btn.pressed.connect(_on_cancel)


func _on_confirm(on_confirm: Callable) -> void:
	var now = Time.get_ticks_msec()
	if now - _last_action_time < DEBOUNCE_MS:
		return  # debounce
	_last_action_time = now
	confirmed.emit(_operation)
	if on_confirm.is_valid():
		on_confirm.call()
	queue_free()


func _on_cancel() -> void:
	cancelled.emit(_operation)
	queue_free()


func _input(event: InputEvent) -> void:
	# Escape دائماً يلغي (لا تأكيد عرضي)
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			_on_cancel()
