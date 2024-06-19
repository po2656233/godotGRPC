extends Node
#var _js_object = null
func _init():
	# 假设你有一个名为 `pomelo.js` 的文件，其中包含了Pomelo客户端库
	var script_path = "res://pomelojs/pomelo-client-protobuf.js"
	# 加载并执行JavaScript文件
	var js = JavaScriptBridge.eval(FileAccess.open(script_path, FileAccess.READ).get_as_text())
	var _onJavascriptCallback = JavaScriptBridge.create_callback(_on_js_callback)
	# 调用JavaScript中的函数 .call({"host": "localhost", "port": 10010, "path":""},_onJavascriptCallback)
	JavaScriptBridge.create_object("pomelo.init",{"host": "localhost", "port": 10010, "path":""})
	JavaScriptBridge.get_interface("pomelo")

func _on_js_callback(args):
	print("web pomelo args:",args)
