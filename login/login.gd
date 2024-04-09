extends Node
const loginProto = preload("res://protogd/login.gd")
#var network = load("res://network/network.gd").new()

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# 加载网络
	Network.RegisterNode(self)
	#停用_physics_process(delta)
	call_deferred("set_physics_process",false)
	%HintDlg.get_label().set_horizontal_alignment(HORIZONTAL_ALIGNMENT_CENTER)

	pass # Replace with function body.


####################################################################
func showHint(content:String,title:String="提示")->void:
	#确保网络处理在主线程外部
	call_deferred("_showHint",title,content)

func _showHint(title:String,content:String):
	%HintDlg.title = title
	%HintDlg.dialog_text = "\t"+content
	%HintDlg.visible = true

	

###########################[主动请求]#########################################
# 注意: 接口名应当与协议名一致,否则需要SendData后注明 协议名
func RegisterReq(account:String,password:String):
	var req = loginProto.RegisterReq.new()
	req.set_Name(account)
	req.set_Password(password)
	print("开始注册\n\n\n")
	if not Network.SendData(req.to_bytes()):
		showHint("网络错误")

func LoginReq(account:String,password:String):
	var req = loginProto.LoginReq.new()
	req.set_Account(account)
	req.set_Password(password)
	print("开始登录\n\n\n")
	if not Network.SendData(req.to_bytes()):
		showHint("网络错误")




############################[接收处理]########################################
func RegisterResp(data:PackedByteArray):
	var resp = loginProto.RegisterResp.new()
	var state = resp.from_bytes(data)
	if state == loginProto.PB_ERR.NO_ERRORS:
		print("注册成功\n",resp.get_Info())
		showHint("注册成功")
		
func LoginResp(data:PackedByteArray):
	var resp = loginProto.LoginResp.new()
	var state = resp.from_bytes(data)
	if state == loginProto.PB_ERR.NO_ERRORS:
		print("登录成功\n",resp)
		showHint("登录成功")
	else:
		showHint("登录失败")
		
		
func ResultResp(data:PackedByteArray):
	var resp = loginProto.ResultResp.new()
	var state = resp.from_bytes(data)
	if state == loginProto.PB_ERR.NO_ERRORS:
		print("结果\n",resp)
		showHint(resp.get_Hints())

func ResultPopResp(data:PackedByteArray):
	var resp = loginProto.ResultPopResp.new()
	var state = resp.from_bytes(data)
	if state == loginProto.PB_ERR.NO_ERRORS:
		print("结果\n",resp)
		showHint(resp.get_Hints(), resp.get_Title())


func _on_bt_register_pressed() -> void:
	var username :String = %LineEdit_username.text
	var password :String  = %LineEdit_password.text
	if username.is_empty():
		return showHint("用户名不能为空")
	if  password.is_empty() :
		return showHint("密码不能为空")
	RegisterReq(username,password)
	pass # Replace with function body.


func _on_bt_login_pressed() -> void:
	var username :String = %LineEdit_username.text
	var password :String  = %LineEdit_password.text
	if username.is_empty():
		return showHint("用户名不能为空")
	if  password.is_empty() :
		return showHint("密码不能为空")
		
	LoginReq(username, password)
	pass # Replace with function body.

