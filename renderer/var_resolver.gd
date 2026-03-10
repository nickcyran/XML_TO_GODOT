class_name VarResolver extends RefCounted

## Resolves @variable tokens in text strings.
##
## Built-in variables:
##   @year      @month    @day
##   @date      @time     @datetime
##
## Call [method resolve] to substitute all tokens in a single pass.


func resolve(text: String) -> String:
	if not "@" in text:
		return text

	var now: Dictionary = Time.get_datetime_dict_from_system()
	var year: String = str(now["year"])
	var month: String = "%02d" % now["month"]
	var day: String = "%02d" % now["day"]
	var hour: String = "%02d" % now["hour"]
	var minute: String = "%02d" % now["minute"]
	var second: String = "%02d" % now["second"]

	# Longest tokens first prevents @datetime being partially replaced by @date.
	const TOKEN_COUNT := 6
	var tokens: Array[PackedStringArray] = [
		PackedStringArray(["@datetime", "%s-%s-%s %s:%s:%s"]),
		PackedStringArray(["@date", "%s-%s-%s"]),
		PackedStringArray(["@time", "%s:%s:%s"]),
		PackedStringArray(["@year", "%s"]),
		PackedStringArray(["@month", "%s"]),
		PackedStringArray(["@day", "%s"]),
	]
	var values: Array[String] = [
		"%s-%s-%s %s:%s:%s" % [year, month, day, hour, minute, second],
		"%s-%s-%s" % [year, month, day],
		"%s:%s:%s" % [hour, minute, second],
		year, month, day,
	]

	for i: int in TOKEN_COUNT:
		text = text.replace(tokens[i][0], values[i])
	return text
