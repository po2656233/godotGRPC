extends Node
const loginProto = preload("res://protogd/login.gd")
const gameProto = preload("res://protogd/game.gd")

#var network = load("res://network/network.gd").new()
var url: String = "127.0.0.1"
var urlport: int = 8089
var gateIp: String = ""
var gatePort: int = 10011

var http_request: HTTPRequest = null
var http_url: String = ""
##
var token: String = ""
var pid: int = 0
var pomelogoPid: int = 0
var areaList: Array = []
var serverList: Array = []
var selectAreaId: int = -1
var selectServerId: int = -1


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# 加载网络
	#Network.InitLeaf("127.0.0.1",9800)
	#Network.RegisterLeafNode(self)
	#停用_physics_process(delta)
	#Network.InitPomelo(pomeloIp,pomeloPort)
	onInit()
	call_deferred("set_physics_process", false)
	%ServerList.get_popup().max_size = Vector2i(300, 200)
	%AreaList.get_popup().max_size = Vector2i(300, 200)
	%HintDlg.get_label().set_horizontal_alignment(HORIZONTAL_ALIGNMENT_CENTER)
	Network.sigAreas.connect(onAreas)
	Network.sigServers.connect(onServers)
	Network.sigFinish.connect(onFinish)
	Network.sigDisconnect.connect(onDisconnect)


# 按ESC键退出
func _unhandled_input(event):
	if event is InputEventKey:
		if event.pressed and event.keycode == KEY_ESCAPE:
			get_tree().quit()


# 按回车键登录
func _process(_delta):
	if Input.is_action_pressed("user_login"):
		_on_bt_login_pressed()


#  槽函数 #######################################
func onAreas(id, areaname, gate):
	areaList.append({"id": id, "name": areaname, "gate": gate})
	#%ServerList.set_item_metadata(id, {"areaname":areaname, "gate":gate} )
	pass


func onServers(id, servername, areaId, status):
	%ServerList.add_item(servername, id)
	serverList.append({"id": id, "name": servername, "areaId": areaId, "status": status})
	pass


func onInit():
	var config = ConfigFile.new()
	# 从文件加载数据。
	var err = config.load("user://base.cfg")
	# 如果文件没有加载，忽略它。
	if err != OK:
		return
	# 迭代所有小节。
	for player in config.get_sections():
		# 获取每个小节的数据。
		selectAreaId = config.get_value(player, "aid")
		selectServerId = config.get_value(player, "sid")


func onFinish():
	%AreaList.clear()
	var validAreas = []
	if 0 < len(areaList):
		for ser in serverList:
			var have = false
			for area in validAreas:
				if area.id == ser.areaId:
					have = true
					break
			if have:
				continue
			for area in areaList:
				if ser.areaId == area.id:
					validAreas.append(area)
					%AreaList.add_item(area.name, area.id)
					break
	validAreas.sort_custom(
		func(a: Dictionary, b: Dictionary): return true if a.id > b.id else false
	)
	areaList = validAreas
	var index = %AreaList.get_item_index(selectAreaId)
	if index != -1:
		%AreaList.select(index)
		%AreaList.emit_signal("item_selected", index)


func onDisconnect():
	showHint("网络故障")
	pass


###########################【显示提示信息】#########################################
func showHint(content: String, title: String = "提示") -> void:
	#确保网络处理在主线程外部
	call_deferred("_showHint", title, content)


func _showHint(title: String, content: String):
	%HintDlg.title = title
	%HintDlg.dialog_text = "\t" + content
	%HintDlg.visible = true


func _showPrompt(title: String, content: String):
	var prompt = preload("res://prompt.tscn").instantiate()
	add_child(prompt)
	prompt.show_message(title, content, Vector2(10, 10), prompt.Direction.Right, 3, 2)


###########################【选择服务区域】#########################################
func selectedArea(areaId):
	var isHave = false
	%ServerList.clear()
	for server in serverList:
		if server.areaId == areaId:
			%ServerList.add_item(server.name, server.id)
			isHave = true
	if !isHave:
		showHint("该区暂无服务")
		return
	_on_server_list_item_selected(0)


func saveConfig():
	# 创建新的 ConfigFile 对象。
	var config = ConfigFile.new()
	# 存储一些值。
	var aid = %AreaList.get_selected_id()
	var sid = %ServerList.get_selected_id()
	config.set_value("gameselect", "aid", aid)
	config.set_value("gameselect", "sid", sid)
	# 将其保存到文件中（如果已存在则覆盖）。
	var err = config.save("user://base.cfg")
	print("保存情况:err-> ", err)


###########################[leaf主动请求]#########################################
## 注意: 接口名应当与协议名一致,否则需要SendData后注明 协议名
#func RegisterReq(account:String,password:String):
#var req = loginProto.RegisterReq.new()
#req.set_name(account)
#req.set_password(password)
#print("开始注册\n\n\n")
#if not Network.SendLeafData(req.to_bytes()):
#showHint("网络错误")
#
#func LoginReq(account:String,password:String):
#var req = loginProto.LoginReq.new()
#req.set_account(account)
#req.set_password(password)
#print("开始登录\n\n\n")
#if not Network.SendLeafData(req.to_bytes()):
#showHint("网络错误")

############################[leaf接收处理]########################################
#func RegisterResp(data:PackedByteArray):
#var resp = loginProto.RegisterResp.new()
#var state = resp.from_bytes(data)
#if state == loginProto.PB_ERR.NO_ERRORS:
#print("注册成功\n",resp.get_Info())
#showHint("注册成功")
#
#func LoginResp(data:PackedByteArray):
#var resp = loginProto.LoginResp.new()
#var state = resp.from_bytes(data)
#if state == loginProto.PB_ERR.NO_ERRORS:
#print("登录成功\n",resp)
#showHint("登录成功")
#else:
#showHint("登录失败")
#
#
#func ResultResp(data:PackedByteArray):
#var resp = loginProto.ResultResp.new()
#var state = resp.from_bytes(data)
#if state == loginProto.PB_ERR.NO_ERRORS:
#print("结果\n",resp)
#showHint(resp.get_Hints())
#
#func ResultPopResp(data:PackedByteArray):
#var resp = loginProto.ResultPopResp.new()
#var state = resp.from_bytes(data)
#if state == loginProto.PB_ERR.NO_ERRORS:
#print("结果\n",resp)
#showHint(resp.get_Hints(), resp.get_Title())


######################[注册]#####################################
func _on_bt_register_pressed() -> void:
	var username: String = %LineEdit_username.text
	var password: String = %LineEdit_password.text
	if username.is_empty():
		return showHint("用户名不能为空")
	if password.is_empty():
		return showHint("密码不能为空")
	(
		Network
		. httpClient
		. Request(
			url,
			urlport,
			"/register",
			{
				"account": username,
				"password": password,
			},
			{instance = self, f = "registerResp"}
		)
	)
	#RegisterReq(username,password)
	pass  # Replace with function body.


func registerResp(data):
	print("registerResp#################################\n", data)
	var json = JSON.new()
	var error = json.parse(data)
	var hint = ""
	var title = "提示"
	if error == OK:
		var resp = json.data
		if resp.code == 0:
			title = "注册成功"
		elif resp.data != "":
			title = "注册失败"
			hint = resp.data
		else:
			hint = "注册失败"
	showHint(hint, title)


###########################[登录]######################################
func _on_bt_login_pressed() -> void:
	var username: String = %LineEdit_username.text
	var password: String = %LineEdit_password.text
	if username.is_empty():
		return showHint("用户名不能为空")
	if password.is_empty():
		return showHint("密码不能为空")
	self.pid = Network.GetServerPid(url, urlport)
	(
		Network
		. httpClient
		. Request(
			url,
			urlport,
			"/login",
			{
				"pid": self.pid,
				"account": username,
				"password": password,
			},
			{instance = self, f = "loginResp"}
		)
	)

	#LoginReq(username, password)
	pass  # Replace with function body.


func loginResp(data):
	print("loginResp#################################\n", data)
	var json = JSON.new()
	var error = json.parse(data)
	var hint = ""
	var title = "提示"
	if error == OK:
		var resp = json.data
		print("resp data:", resp)
		if resp.code == 0:
			title = "登录成功"
			self.token = resp.data
			############p##################
			# 服务id
			var id = %ServerList.get_selected_id()
			# 开始登录
			var req = loginProto.LoginRequest.new()
			req.set_serverId(id)
			req.set_token(self.token)
			print("开始登录\t \n\n\n", id)
			#if not Network.SendLeafData(req.to_bytes()):
			Network.Request("gate.user.login", req.to_bytes(), self, "_loginResponse")
			#get_tree().change_scene_to_file("res://home.tscn")
		elif resp.data != "":
			title = "登录失败"
			hint = resp.data
		else:
			hint = "登录失败"
	showHint(hint, title)


func _loginResponse(data):
	if data == null:
		print("_loginResponse null")
		return
	var resp = loginProto.LoginResponse.new()
	var state = resp.from_bytes(data)
	print("_loginResponse:", resp)
	if state == loginProto.PB_ERR.NO_ERRORS:
		var id = %ServerList.get_selected_id()
		#selectedServer(id)
		print("登录网关成功 uid:", resp.get_uid(), " id:", id)
		#进入游戏
		var gameReq = gameProto.EnterGameReq.new()
		gameReq.set_token("w is token")
		Network.Request("leaf.game.enter", gameReq.to_bytes(), self, "_enterResponse")
		showHint("登录成功")
	else:
		showHint("登录网关失败")


func _enterResponse(data):
	if data == null:
		return
	var resp = gameProto.EnterGameResp.new()
	var state = resp.from_bytes(data)
	print("_enterResponse:", resp)
	if state == loginProto.PB_ERR.NO_ERRORS:
		print("进入游戏成功\n", resp.get_gameID())
		showHint("进入游戏成功")
		$"../TextureRect_logo".hide()
		$"../RichTextLabel_gonggao".hide()
		$"..".hide()
		var main_root = preload("res://game.tscn").instantiate()
		self.get_parent().add_child(main_root)
		self.queue_free()

	else:
		showHint("进入游戏失败")


func _on_server_list_item_selected(_idx: int) -> void:
	saveConfig()
	pass  # Replace with function body.


func _on_area_list_item_selected(idx: int) -> void:
	var id = %AreaList.get_item_id(idx)
	for area in areaList:
		if area.id == id:
			var host = String(area.gate).split(":")
			gateIp = host[0]
			# 注意 当使用wss时，应当解开
			#gatePort = int(host[1])
			# tcp
			#Network.InitPomelo(gateIp, gatePort)
			Network.InitSimple(gateIp, gatePort)
			print("当前 网关 地址-> ", gateIp, ":", gatePort)
			break
	selectedArea(id)
	var index = %ServerList.get_item_index(selectServerId)
	if index != -1:
		%ServerList.select(index)
	selectServerId = -1
	pass  # Replace with function body.
