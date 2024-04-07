extends Node
const loginProto = preload("res://protogd/login.gd")

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass

func LoginReq(account:String,password:String):
	var req = loginProto.LoginReq.new()
	req.set_Account(account)
	req.set_Password(password)
	print("开始登录\n\n\n")
	$"..".SendData("LoginReq", req.to_bytes())

func LoginResp(data:PackedByteArray):
	var resp = loginProto.LoginResp.new()
	var state = resp.from_bytes(data)
	if state == loginProto.PB_ERR.NO_ERRORS:
		print("登录成功\n",resp)
		
		
func ResultResp(data:PackedByteArray):
	var resp = loginProto.ResultResp.new()
	var state = resp.from_bytes(data)
	if state == loginProto.PB_ERR.NO_ERRORS:
		print("结果\n",resp)

	
