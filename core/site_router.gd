class_name SiteRouter extends RefCounted

## Maps [code]site://pagename[/code] links to raw XML strings.
##
## Both desktop and web ultimately use the same [member _page_cache] dictionary.
## On desktop, [method load_from_dir] fills the cache by scanning the filesystem.
## On web, [method load_from_dict] fills it from data already in memory.
##
## [codeblock]
## # Desktop
## var router := SiteRouter.load_from_dir("/abs/path/to/site", "/abs/path/to/site/assets")
##
## # Web
## var router := SiteRouter.load_from_dict(pages_dict, assets_abs_path)
##
## var xml := router.resolve("site://about")   # "" if not found
## [/codeblock]

## Absolute path to the assets sub-folder.
var assets_base: String = ""

var _page_cache: Dictionary[String, String] = {}


# ── Factories ──────────────────────────────────────────────────────────────────

## Create a router by scanning every [code].xml[/code] file in [param site_dir].
static func load_from_dir(site_dir: String, p_assets_base: String) -> SiteRouter:
	var router := SiteRouter.new()
	router.assets_base = p_assets_base

	var da := DirAccess.open(site_dir)
	if da == null:
		push_error("SiteRouter: cannot open directory '%s'" % site_dir)
		return router

	da.list_dir_begin()
	var fname := da.get_next()
	while fname != "":
		if not da.current_is_dir() and fname.ends_with(".xml"):
			var key := fname.get_basename()
			router._page_cache[key] = FileAccess.get_file_as_string(site_dir.path_join(fname))
		fname = da.get_next()
	da.list_dir_end()
	return router


## Create a router from an in-memory [param pages] dictionary ([code]name → xml_text[/code]).
static func load_from_dict(pages: Dictionary, p_assets_base: String) -> SiteRouter:
	var router := SiteRouter.new()
	router.assets_base   = p_assets_base
	router._page_cache   = pages.duplicate()
	return router


# ── Public API ─────────────────────────────────────────────────────────────────

## Resolve a [code]site://pagename[/code] URL.
## Returns the raw XML string, or [code]""[/code] if not found.
func resolve(url: String) -> String:
	if not url.begins_with("site://"):
		return ""
	var page_name := url.trim_prefix("site://").strip_edges()
	if page_name.is_empty():
		return ""
	if not _page_cache.has(page_name):
		push_warning("SiteRouter: no page cached for '%s'" % page_name)
		return ""
	return _page_cache[page_name]
