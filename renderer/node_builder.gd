class_name NodeBuilder extends RefCounted

## Converts a [PageNode] tree into a Godot [Control] tree.
##
## Each [code]build_*[/code] method handles exactly one XML tag.
## After building, [AttrApplicator.apply] is called on every non-page node
## so layout attributes (width, padding, align, etc.) are applied uniformly.
##
## Emits [signal link_clicked] whenever an [code]<a>[/code] is activated.

signal link_clicked(url: String)

const HEADING_SIZES := {"h1": 32, "h2": 28, "h3": 24, "h4": 20, "h5": 18, "h6": 16}

## Core palette — edit these to re-skin the entire renderer.
const COLOR_PAGE_BG := Color("#f9fafb") # near-white canvas
const COLOR_HEADING := Color("#111827") # almost-black
const COLOR_BODY := Color("#374151") # dark gray
const COLOR_MUTED := Color("#6b7280") # medium gray (bylines, footer)
const COLOR_RULE := Color("#e5e7eb") # hairline separator
const COLOR_HEADER_BG := Color("#1e293b") # dark navy header band
const COLOR_HEADER_TEXT := Color("#f1f5f9") # off-white text on header
const COLOR_FOOTER_BG := Color("#f1f5f9") # light footer band
const LINK_COLOR_NORMAL := Color("#2563eb")
const LINK_COLOR_HOVER := Color("#1e40af")

## Absolute path to the site's assets folder (populated by XmlPageRenderer).
var assets_base: String = ""

var _attrs: AttrApplicator
var _vars: VarResolver


func _init() -> void:
	_attrs = AttrApplicator.new()
	_vars = VarResolver.new()


## Build a full [Control] tree from [param node] and return its root.
func build(node: PageNode) -> Control:
	var ctrl := _build(node)
	return ctrl if ctrl else Control.new()


# ── Dispatch ───────────────────────────────────────────────────────────────────

func _build(node: PageNode) -> Control:
	var ctrl: Control

	match node.tag:
		"page": ctrl = _build_page(node)
		"vbox": ctrl = _build_vbox(node)
		"hbox": ctrl = _build_hbox(node)
		"p": ctrl = _build_p(node)
		"a": ctrl = _build_a(node)
		"img": ctrl = _build_img(node)
		"hr": ctrl = _build_hr()
		"#text": ctrl = _build_text(node)
		_:
			if HEADING_SIZES.has(node.tag):
				ctrl = _build_heading(node)
			else:
				ctrl = _build_unknown(node)

	if ctrl and node.tag != "page":
		ctrl = _attrs.apply(node, ctrl)

	return ctrl


# ── Tag builders ───────────────────────────────────────────────────────────────

func _build_page(node: PageNode) -> Control:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	# Give the canvas a background colour.
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = COLOR_PAGE_BG
	scroll.add_theme_stylebox_override("panel", bg_style)

	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_attrs.apply_box(node, box)
	_append_children(node, box)

	scroll.add_child(box)
	return scroll


func _build_vbox(node: PageNode) -> Control:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_attrs.apply_box(node, box)
	_append_children(node, box)
	return box


func _build_hbox(node: PageNode) -> Control:
	var box := HBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_attrs.apply_box(node, box)
	_append_children(node, box)
	return box


## Renders a full-width 1 px hairline rule.
func _build_hr() -> Control:
	var line := ColorRect.new()
	line.color = COLOR_RULE
	line.custom_minimum_size = Vector2(0.0, 1.0)
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return line


func _build_heading(node: PageNode) -> Control:
	var lbl := Label.new()
	lbl.text = _inner_text(node)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_font_size_override("font_size", HEADING_SIZES[node.tag])
	lbl.add_theme_color_override("font_color", COLOR_HEADING)
	return lbl


func _build_p(node: PageNode) -> Control:
	var lbl := Label.new()
	lbl.text = _inner_text(node)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_color_override("font_color", COLOR_BODY)
	return lbl


func _build_a(node: PageNode) -> Control:
	var href: String = node.attrs.get("href", "")
	var link_text: String = _inner_text(node)

	# Use a flat Button instead of RichTextLabel — meta_clicked is unreliable
	# inside ScrollContainers on the web export. Button.pressed always fires.
	var btn := Button.new()
	btn.text = link_text
	btn.flat = true
	btn.focus_mode = Control.FOCUS_NONE
	btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	# Style: underlined link colour, no background.
	var normal_font := btn.get_theme_font("font")
	btn.add_theme_color_override("font_color", LINK_COLOR_NORMAL)
	btn.add_theme_color_override("font_hover_color", LINK_COLOR_HOVER)
	btn.add_theme_color_override("font_pressed_color", LINK_COLOR_HOVER)
	btn.add_theme_color_override("font_focus_color", LINK_COLOR_NORMAL)

	# Transparent stylebox for all states so no button chrome shows.
	var empty := StyleBoxEmpty.new()
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		btn.add_theme_stylebox_override(state, empty)

	if href != "":
		btn.pressed.connect(func() -> void:
			link_clicked.emit(href))

	return btn


func _build_img(node: PageNode) -> Control:
	var tex_rect := TextureRect.new()
	var src: String = node.attrs.get("src", "")
	if src != "":
		# Resolve relative src names against the assets folder.
		var full_path := src
		if assets_base != "" and not src.begins_with("res://") and not src.begins_with("/"):
			full_path = assets_base.path_join(src)
		var img := Image.new()
		if img.load(full_path) == OK:
			tex_rect.texture = ImageTexture.create_from_image(img)
		else:
			push_warning("Could not load image: %s" % full_path)
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	return tex_rect


func _build_text(node: PageNode) -> Control:
	var lbl := Label.new()
	lbl.text = _vars.resolve(node.text)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_color_override("font_color", COLOR_BODY)
	return lbl


func _build_unknown(node: PageNode) -> Control:
	# Graceful degradation: wrap unknown tags in a VBox so their children render.
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_attrs.apply_box(node, box)
	_append_children(node, box)
	return box


# ── Helpers ────────────────────────────────────────────────────────────────────

func _append_children(node: PageNode, parent: Control) -> void:
	for child in node.children:
		var built := _build(child)
		if built:
			parent.add_child(built)


## Recursively collects all text content under [param node] and resolves vars.
func _inner_text(node: PageNode) -> String:
	if node.tag == "#text":
		return _vars.resolve(node.text)
	var out := ""
	for child in node.children:
		out += _inner_text(child)
	return _vars.resolve(out.strip_edges())
