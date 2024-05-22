extends Node
const loginProto = preload("res://protogd/login.gd")
#var network = load("res://network/network.gd").new()
var url = "127.0.0.1"
var urlport = 8089
var pomeloIp = "127.0.0.1"
var pomeloPort = 10011
var token :String
var pid:int = 0
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# 加载网络
	#Network.InitLeaf("127.0.0.1",9800)
	#Network.RegisterLeafNode(self)
	#停用_physics_process(delta)
	Network.InitPomelo(pomeloIp,pomeloPort)
		
	call_deferred("set_physics_process",false)
	%OptionButton.get_popup().max_size = Vector2i(300, 200)
	%HintDlg.get_label().set_horizontal_alignment(HORIZONTAL_ALIGNMENT_CENTER)
	Network.serverArea.connect(_on_serverArea)


# 按ESC键退出
func _unhandled_input(event):
	if event is InputEventKey:
		if event.pressed and event.keycode == KEY_ESCAPE:
			get_tree().quit()
			

# 按回车键登录		
func _process(_delta):
	if Input.is_action_pressed("user_login"):
		_on_bt_login_pressed()

	#pass # Replace with function body.
func _on_serverArea(id, servername, _gate):
	%OptionButton.add_item(servername,id)
	pass


###########################【显示提示信息】#########################################
func showHint(content:String,title:String="提示")->void:
	#确保网络处理在主线程外部
	call_deferred("_showHint",title,content)

func _showHint(title:String,content:String):
	%HintDlg.title = title
	%HintDlg.dialog_text = "\t"+content
	%HintDlg.visible = true

	
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
	var username :String = %LineEdit_username.text
	var password :String  = %LineEdit_password.text
	if username.is_empty():
		return showHint("用户名不能为空")
	if  password.is_empty() :
		return showHint("密码不能为空")
	Network.httpClient.Request(url, urlport,'/register',{
		"account":username,
		"password":password,
		},{instance=self,f='registerResp'})
	#RegisterReq(username,password)
	pass # Replace with function body.
	
func registerResp(data):
	print('registerResp#################################\n',data)
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
	showHint(hint,title)

###########################[登录]######################################
func _on_bt_login_pressed() -> void:
	var username :String = %LineEdit_username.text
	var password :String  = %LineEdit_password.text
	if username.is_empty():
		return showHint("用户名不能为空")
	if  password.is_empty() :
		return showHint("密码不能为空")
	self.pid = Network.GetServerPid(url, urlport)
	Network.httpClient.Request(url, urlport,'/login',{
		"pid":self.pid,
		"account":username,
		"password":password,
		},{instance=self,f='loginResp'})

	#LoginReq(username, password)
	pass # Replace with function body.

func loginResp(data):
	print('loginResp#################################\n',data)
	var json = JSON.new()
	var error = json.parse(data)
	var hint = ""
	var title = "提示"
	if error == OK:
		var resp = json.data
		if resp.code == 0:
			title = "登录成功"
			self.token = resp.data
			############p##################
		
			var req = loginProto.LoginRequest.new()
			req.set_serverId(self.pid)
			req.set_token(self.token)
			print("开始登录\n\n\n")
			#if not Network.SendLeafData(req.to_bytes()):
			Network.Request("gate.user.login",req.to_bytes(),self,"_loginResponse")
			#get_tree().change_scene_to_file("res://home.tscn")
		elif resp.data != "":
			title = "登录失败"
			hint = resp.data
		else:
			hint = "登录失败"
	showHint(hint,title)


func _loginResponse(data):
	if data == null:
		return
	var resp = loginProto.LoginResponse.new()
	var state = resp.from_bytes(data)
	print("_loginResponse",data)
	if state == loginProto.PB_ERR.NO_ERRORS:
		print("登录网关成功\n",resp.get_uid())
		showHint("登录成功")
	else:
		showHint("登录网关失败")
