class_name XmlPageParser extends RefCounted

## Parse an XML file at [param path] and return its [PageNode] root.
func parse_file(path: String) -> PageNode:
	var parser := XMLParser.new()
	if parser.open(path) != OK:
		push_error("XmlPageParser: failed to open '%s'" % path)
		return null
	return _parse(parser)


## Parse XML from a raw [String] and return its [PageNode] root.
## Used on web where file content is received from JavaScript.
func parse_string(xml_text: String) -> PageNode:
	var parser := XMLParser.new()
	if parser.open_buffer(xml_text.to_utf8_buffer()) != OK:
		push_error("XmlPageParser: failed to parse string buffer.")
		return null
	return _parse(parser)


# ── Shared parse logic ─────────────────────────────────────────────────────────

func _parse(parser: XMLParser) -> PageNode:
	var root: PageNode = null
	var stack: Array[PageNode] = []

	while parser.read() == OK:
		match parser.get_node_type():
			XMLParser.NODE_ELEMENT:
				var tag := parser.get_node_name()
				var attrs := _read_attrs(parser)
				var node := PageNode.new(tag, attrs)

				if stack.is_empty():
					root = node
				else:
					stack[-1].children.append(node)

				if not parser.is_empty():
					stack.append(node)

			XMLParser.NODE_TEXT:
				var txt := parser.get_node_data().strip_edges()
				if txt != "" and not stack.is_empty():
					var text_node := PageNode.new("#text")
					text_node.text = txt
					stack[-1].children.append(text_node)

			XMLParser.NODE_ELEMENT_END:
				var closing_tag := parser.get_node_name()

				if stack.is_empty():
					push_error("Unexpected closing tag: %s" % closing_tag)
				elif stack[-1].tag != closing_tag:
					push_error("Mismatched closing tag. Expected </%s> but got </%s>" % [stack[-1].tag, closing_tag])
					stack.pop_back()
				else:
					stack.pop_back()

	return root


## Collect all attributes from the current element into a [Dictionary].
func _read_attrs(parser: XMLParser) -> Dictionary[String, String]:
	var attrs: Dictionary[String, String] = {}
	for i: int in parser.get_attribute_count():
		attrs[parser.get_attribute_name(i)] = parser.get_attribute_value(i)
	return attrs
