extends Control

const SiteRouter := preload("res://core/site_router.gd")

# ── Node references (resolved in _ready) ──────────────────────────────────────
@onready var _upload_screen: Control = $UploadScreen
@onready var _upload_btn: Button = $UploadScreen/CenterBox/Card/UploadBtn
@onready var _status_label: Label = $UploadScreen/CenterBox/Card/StatusLabel

@onready var _render_view: Control = $RenderView
@onready var _render_container: Control = $RenderView/RenderContainer

@onready var _back_btn: Button = $RenderView/BackBtn

@onready var _folder_dialog: FileDialog = $FolderDialog # desktop only

# ── State ──────────────────────────────────────────────────────────────────────
var _built_node: Control = null
var _router: SiteRouter = null
var _web_picker: WebDirPicker = null
var _renderer: XmlPageRenderer = null

# ── Lifecycle ──────────────────────────────────────────────────────────────────

func _ready() -> void:
	_upload_btn.pressed.connect(_on_upload_pressed)
	_back_btn.pressed.connect(_on_back_pressed)
	_folder_dialog.dir_selected.connect(_on_folder_selected)
	_show_upload()
	if OS.has_feature("web"):
		_web_picker = WebDirPicker.new()
		_web_picker.completed.connect(_on_web_dir_picked)
		_web_picker.failed.connect(func(reason: String) -> void:
			_status_label.text = reason)
		_web_picker.setup()


# ── Screen transitions ─────────────────────────────────────────────────────────

func _show_upload() -> void:
	_upload_screen.visible = true
	_render_view.visible = false
	_status_label.text = ""


func _show_render() -> void:
	_upload_screen.visible = false
	_render_view.visible = true


# ── Upload button ──────────────────────────────────────────────────────────────

func _on_upload_pressed() -> void:
	_status_label.text = ""
	if OS.has_feature("web"):
		_web_picker.open()
	else:
		_folder_dialog.popup_centered_ratio(0.6)


# ── Desktop — folder FileDialog ────────────────────────────────────────────────

func _on_folder_selected(dir: String) -> void:
	var xml_path := _first_xml_in_dir(dir)
	if xml_path.is_empty():
		_status_label.text = "No .xml file found in: %s" % dir
		return

	var xml_text := FileAccess.get_file_as_string(xml_path)
	if xml_text.is_empty():
		_status_label.text = "Could not read: %s" % xml_path
		return

	var assets_dir: String = dir.path_join("assets")
	_router = SiteRouter.load_from_dir(dir, assets_dir)
	_process_xml(xml_text, assets_dir)


## Returns the path of the first [code].xml[/code] file found directly inside [param dir].
func _first_xml_in_dir(dir: String) -> String:
	var da := DirAccess.open(dir)
	if da == null:
		return ""
	da.list_dir_begin()
	var entry := da.get_next()
	while entry != "":
		if not da.current_is_dir() and entry.ends_with(".xml"):
			da.list_dir_end()
			return dir.path_join(entry)
		entry = da.get_next()
	da.list_dir_end()
	return ""


# ── Web — folder picker ────────────────────────────────────────────────────────

func _on_web_dir_picked(xml_text: String, pages: Dictionary, assets: Dictionary) -> void:
	# Write asset data-URLs into a temp folder so Image.load() can reach them.
	var tmp_assets := "user://site_assets_tmp"
	DirAccess.make_dir_recursive_absolute(tmp_assets)

	for fname: String in assets:
		var data_url: String = assets[fname]
		var comma_idx := data_url.find(",")
		if comma_idx == -1:
			continue
		var bytes := Marshalls.base64_to_raw(data_url.substr(comma_idx + 1))
		var fa := FileAccess.open(tmp_assets.path_join(fname), FileAccess.WRITE)
		if fa:
			fa.store_buffer(bytes)
			fa.close()

	var assets_abs: String = ProjectSettings.globalize_path(tmp_assets)
	_router = SiteRouter.load_from_dict(pages, assets_abs)
	_process_xml(xml_text, assets_abs)


# ── Pipeline ───────────────────────────────────────────────────────────────────

func _process_xml(xml_text: String, assets_dir: String = "") -> void:
	var parser := XmlPageParser.new()
	var root := parser.parse_string(xml_text)

	if root == null:
		_status_label.text = "Parse failed — check XML syntax."
		return

	if _renderer == null:
		_renderer = XmlPageRenderer.new()
		_renderer.link_clicked.connect(_on_link_clicked)

	var built := _renderer.build(root, assets_dir)
	if built == null:
		_status_label.text = "Render failed."
		return

	if _built_node != null:
		_render_container.remove_child(_built_node)
		_built_node.queue_free()
		_built_node = null

	_built_node = built
	_render_container.add_child(built)
	built.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_show_render()


# ── Navigation ─────────────────────────────────────────────────────────────────

func _on_back_pressed() -> void:
	_renderer = null
	_router = null
	_show_upload()


# ── Link handler ───────────────────────────────────────────────────────────────

func _on_link_clicked(url: String) -> void:
	print("LINK CLICKED:", url)
	if url.begins_with("site://"):
		_navigate(url)
	elif url.begins_with("http://") or url.begins_with("https://"):
		OS.shell_open(url)


func _navigate(url: String) -> void:
	if _router == null:
		push_warning("No router loaded.")
		return

	var xml_text := _router.resolve(url)
	if xml_text.is_empty():
		push_warning("Router: page not found for '%s'" % url)
		return

	_process_xml(xml_text, _router.assets_base)
