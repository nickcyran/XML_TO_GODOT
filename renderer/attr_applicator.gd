class_name AttrApplicator extends RefCounted

## Applies XML attributes to built Godot Control nodes.
##
## Supported on all tags:
##   width="200"               fixed pixel width
##   height="48"               fixed pixel height
##   min_width="100"           minimum pixel width
##   min_height="24"           minimum pixel height
##   grow="true"               SIZE_EXPAND_FILL horizontally
##   align="left|center|right|fill"
##   padding="12"              uniform — all sides
##   padding="8,16"            vertical, horizontal
##   padding="4,8,12,16"       top, right, bottom, left
##   color="#1a1a2e"           text color (Label / RichTextLabel)
##   bg="#f0f4f8"              background fill color
##
## Supported on BoxContainer (vbox / hbox):
##   gap="12"                  pixel separation between children


## Apply all common layout attributes to [param ctrl].
## Returns [param ctrl] unchanged, or a [MarginContainer] wrapping it if
## [code]padding[/code] was specified.
func apply(node: PageNode, ctrl: Control) -> Control:
	_apply_size(node.attrs, ctrl)
	_apply_alignment(node.attrs, ctrl)
	_apply_color(node.attrs, ctrl)
	if node.attrs.has("padding"):
		ctrl = _wrap_padding(ctrl, node.attrs["padding"])
	if node.attrs.has("bg"):
		ctrl = _wrap_bg(ctrl, node.attrs["bg"])
	return ctrl


## Apply gap separation to a [BoxContainer].
func apply_box(node: PageNode, box: BoxContainer) -> void:
	if node.attrs.has("gap"):
		box.add_theme_constant_override("separation", int(node.attrs["gap"]))


# ── Private ────────────────────────────────────────────────────────────────────

func _apply_size(attrs: Dictionary, ctrl: Control) -> void:
	if attrs.has("width"):
		ctrl.custom_minimum_size.x = float(attrs["width"])
		ctrl.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	if attrs.has("height"):
		ctrl.custom_minimum_size.y = float(attrs["height"])
	if attrs.has("min_width"):
		ctrl.custom_minimum_size.x = maxf(ctrl.custom_minimum_size.x, float(attrs["min_width"]))
	if attrs.has("min_height"):
		ctrl.custom_minimum_size.y = maxf(ctrl.custom_minimum_size.y, float(attrs["min_height"]))
	if attrs.get("grow", "false") == "true":
		ctrl.size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _apply_alignment(attrs: Dictionary, ctrl: Control) -> void:
	if not attrs.has("align"):
		return

	match attrs["align"]:
		"center":
			if ctrl is Label:
				(ctrl as Label).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			elif ctrl is RichTextLabel:
				(ctrl as RichTextLabel).text = "[center]%s[/center]" % (ctrl as RichTextLabel).text
			elif ctrl is BoxContainer:
				(ctrl as BoxContainer).alignment = BoxContainer.ALIGNMENT_CENTER
		"right":
			if ctrl is Label:
				(ctrl as Label).horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			elif ctrl is RichTextLabel:
				(ctrl as RichTextLabel).text = "[right]%s[/right]" % (ctrl as RichTextLabel).text
			elif ctrl is BoxContainer:
				(ctrl as BoxContainer).alignment = BoxContainer.ALIGNMENT_END
		"fill":
			if ctrl is Label:
				(ctrl as Label).horizontal_alignment = HORIZONTAL_ALIGNMENT_FILL
		_: # "left" or unknown — default, no-op
			pass


func _wrap_padding(ctrl: Control, padding_str: String) -> MarginContainer:
	var parts: PackedStringArray = padding_str.split(",")
	var top: int = 0
	var right: int = 0
	var bottom: int = 0
	var left: int = 0

	match parts.size():
		1:
			top = int(parts[0])
			right = top
			bottom = top
			left = top
		2:
			top = int(parts[0])
			bottom = top
			right = int(parts[1])
			left = right
		_:
			top = int(parts[0])
			right = int(parts[1])
			bottom = int(parts[2])
			left = int(parts[3]) if parts.size() > 3 else right

	var margin := MarginContainer.new()
	margin.size_flags_horizontal = ctrl.size_flags_horizontal
	margin.add_theme_constant_override("margin_top", top)
	margin.add_theme_constant_override("margin_right", right)
	margin.add_theme_constant_override("margin_bottom", bottom)
	margin.add_theme_constant_override("margin_left", left)
	margin.add_child(ctrl)
	return margin


func _apply_color(attrs: Dictionary, ctrl: Control) -> void:
	if not attrs.has("color"):
		return
	var c := Color(attrs["color"])
	if ctrl is Label:
		(ctrl as Label).add_theme_color_override("font_color", c)
	elif ctrl is RichTextLabel:
		(ctrl as RichTextLabel).add_theme_color_override("default_color", c)


## Wraps [param ctrl] in a [PanelContainer] with a solid background colour.
func _wrap_bg(ctrl: Control, bg_str: String) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(bg_str)
	panel.add_theme_stylebox_override("panel", style)
	panel.size_flags_horizontal = ctrl.size_flags_horizontal
	panel.size_flags_vertical = ctrl.size_flags_vertical
	panel.add_child(ctrl)
	return panel
