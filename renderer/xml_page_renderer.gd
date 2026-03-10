class_name XmlPageRenderer extends RefCounted

signal link_clicked(url: String)

var _builder: NodeBuilder


func _init() -> void:
	_builder = NodeBuilder.new()
	_builder.link_clicked.connect(func(url: String) -> void: link_clicked.emit(url))


## Convert a [PageNode] tree into a ready-to-add [Control] tree.
## [param p_assets_base] is the absolute path to the site[code]/assets[/code] folder.
func build(node: PageNode, p_assets_base: String = "") -> Control:
	_builder.assets_base = p_assets_base
	return _builder.build(node)
