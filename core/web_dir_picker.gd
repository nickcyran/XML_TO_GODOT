class_name WebDirPicker extends RefCounted

## Wraps the [code]JavaScriptBridge[/code] folder-picker entirely so that
## [code]control.gd[/code] never touches a line of JavaScript directly.
##
## Usage (web only — guard with [code]OS.has_feature("web")[/code]):
## [codeblock]
##   var _picker := WebDirPicker.new()
##   _picker.completed.connect(_on_dir_picked)
##   _picker.setup()          # once, in _ready
##   _picker.open()           # when the upload button is pressed
##
##   func _on_dir_picked(primary_xml: String,
##                       pages: Dictionary,
##                       assets: Dictionary) -> void:
##       pass  # primary_xml  — text of the entry-point XML file
##             # pages        — { "pagename": "<xml text>", ... }
##             # assets       — { "filename.png": "<base64 data-url>", ... }
## [/codeblock]

## Emitted when the user finishes selecting a folder.
## [param primary_xml] is the text of the entry-point page.
## [param pages] maps bare page names to their raw XML text.
## [param assets] maps asset filenames to base64 data-URLs.
signal completed(primary_xml: String, pages: Dictionary, assets: Dictionary)

## Emitted when no XML file was found in the selected folder.
signal failed(reason: String)

# Kept alive so the GC doesn't collect the JS callable.
var _callback = null


## Inject the hidden [code]<input>[/code] element once on startup.
func setup() -> void:
	JavaScriptBridge.eval("""
		if (!document.getElementById('_gd_dir_input')) {
			var inp      = document.createElement('input');
			inp.type     = 'file';
			inp.id       = '_gd_dir_input';
			inp.setAttribute('webkitdirectory', '');
			inp.setAttribute('multiple', '');
			inp.style.display = 'none';
			document.body.appendChild(inp);
		}
		window._gd_dir_callback = null;
	""", true)


## Show the OS folder picker.  [signal completed] or [signal failed] fires when done.
func open() -> void:
	_callback = JavaScriptBridge.create_callback(
		func(args: Array) -> void:
			var payload: String = str(args[0]) if args.size() > 0 else ""
			_dispatch.call_deferred(payload)
	)
	JavaScriptBridge.get_interface("window")._gd_dir_callback = _callback

	JavaScriptBridge.eval("""
		(function() {
			var inp = document.getElementById('_gd_dir_input');
			inp.onchange = function(e) {
				var files      = Array.from(e.target.files);
				var xmlFiles   = [];
				var assetFiles = [];

				files.forEach(function(f) {
					var parts = f.webkitRelativePath.split('/');
					if (parts.length === 2 && f.name.endsWith('.xml')) {
						xmlFiles.push(f);
					} else if (parts.length === 3 && parts[1].toLowerCase() === 'assets') {
						assetFiles.push(f);
					}
				});

				if (xmlFiles.length === 0) {
					if (window._gd_dir_callback) window._gd_dir_callback('');
					inp.value = '';
					return;
				}

				xmlFiles.sort(function(a, b) { return a.name < b.name ? -1 : 1; });
				var primary = xmlFiles.find(function(f) { return f.name === 'index.xml'; }) || xmlFiles[0];
				var result  = { xml: '', pages: {}, assets: {} };
				var pending = xmlFiles.length + assetFiles.length;

				function finish() {
					if (--pending === 0) {
						if (window._gd_dir_callback)
							window._gd_dir_callback(JSON.stringify(result));
						inp.value = '';
					}
				}

				xmlFiles.forEach(function(xf) {
					var r   = new FileReader();
					var key = xf.name.endsWith('.xml') ? xf.name.slice(0, -4) : xf.name;
					r.onload = function(ev) {
						result.pages[key] = ev.target.result;
						if (xf === primary) result.xml = ev.target.result;
						finish();
					};
					r.onerror = function() { finish(); };
					r.readAsText(xf);
				});

				assetFiles.forEach(function(af) {
					var r = new FileReader();
					r.onload = function(ev) {
						result.assets[af.name] = ev.target.result;
						finish();
					};
					r.onerror = function() { finish(); };
					r.readAsDataURL(af);
				});
			};
			inp.click();
		})();
	""", true)


# ── Private ────────────────────────────────────────────────────────────────────

func _dispatch(payload: String) -> void:
	if payload.is_empty():
		failed.emit("No .xml file found in the selected folder.")
		return

	var data: Variant = JSON.parse_string(payload)
	if not data is Dictionary:
		failed.emit("Invalid payload from file picker.")
		return

	var xml_text: String = data.get("xml", "")
	if xml_text.is_empty():
		failed.emit("XML file was empty.")
		return

	var pages: Dictionary = data.get("pages", {})
	print("WebDirPicker pages received: ", pages.keys())
	completed.emit(xml_text, pages, data.get("assets", {}))
