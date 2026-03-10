class_name PageNode extends RefCounted

## Represents one node in the parsed XML tree.
##
## A tag node:  [code]<tag attr="val">children</tag>[/code]
## A text node: [code]tag == "#text"[/code], content is in [member text].

var tag: String = ""
var attrs: Dictionary[String, String] = {}
var text: String = ""
var children: Array[PageNode] = []


func _init(p_tag: String = "", p_attrs: Dictionary[String, String] = {}) -> void:
	tag = p_tag
	attrs = p_attrs


func _to_string() -> String:
	return _stringify(0)


func _stringify(depth: int) -> String:
	var indent := "  ".repeat(depth)

	if tag == "#text":
		return indent + "TEXT(\"%s\")\n" % text

	var s := indent + "<" + tag
	for k in attrs:
		s += " %s=\"%s\"" % [k, attrs[k]]
	s += ">\n"

	for child in children:
		s += child._stringify(depth + 1)

	s += indent + "</" + tag + ">\n"
	return s
