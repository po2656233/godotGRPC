extends Node
#@export var ip:String = "127.0.0.1"
#@export var port:int = 10011
var url = 'http://127.0.0.1'
var urlport = 8089
var pid:int = 0
# 网络格式选用
var goleaf  = null
var pomelo  = null #preload("res://network/net_pomelo.gd").new()
var httpClient  = preload("res://network/net_http.gd").new()
## 业务协议
#const loginProto = preload("res://protogd/login.gd")
signal serverArea(id,name,gate)



func _init():
	set_process(true)
	add_child(httpClient)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	set_process(false)
	httpClient.Request(url, urlport,'/pid/list',{},{instance=self,f='_pids'})
	
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	if self.pid == 0:
		httpClient.Request(url, urlport,'/pid/list',{},{instance=self,f='_pids'})
	else:
		set_process(false)
	
func _pids(data):
	print('#################################\n',data)
	var json = JSON.new()
	var error = json.parse(data)
	if error == OK:
		var data_received = json.data
		if typeof(data_received.data.pids) == TYPE_ARRAY:
			self.pid = data_received.data.pids[0]
			print('当前pid ', self.pid)
			httpClient.Request(url, urlport,'/server/list/'+var_to_str(self.pid),{},{instance=self,f='_serverlist'})

func _serverlist(data):
	print('_serverlist#################################\n',data)
	var json = JSON.new()
	var error = json.parse(data)
	if error == OK:
		var resp = json.data
		if resp.code == 0 and resp.data.areas != null:
			for area in resp.data.areas:
				print(area.areaName, area.areaId)
				emit_signal("serverArea", area.areaId, area.areaName, area.gate)
				#%OptionButton.add_item ( area.areaName, area.areaId )



			
#func _register(data):
	#print('_register#################################\n',data)
	#var json = JSON.new()
	#var error = json.parse(data)
	#if error == OK:
		#print(data)
#
#func _login(data):
	#print('login#################################\n',data)
	#var json = JSON.new()
	#var error = json.parse(data)
	#if error == OK:
		#print(data)
###############################[外部接口]#################################################

###############################[Pomelo接口]################################################
func InitPomelo(ip:String,port:int):
	pomelo  = load("res://network/net_pomelo.gd").new()
	pomelo.Init(ip,port)
	pomelo.on("error",self,"_on_errror")
	pomelo.on("heartbeat timeout",self,"_heartbeat")
	pomelo.on("disconnected",self,"_disconnected")
	pomelo.on("kick",self,"_kick")	
	add_child(pomelo)
	
func _on_errror(msg):
	print("_on_errror",msg)

func _kick(msg):
	print("_kick",msg)
	
func _heartbeat():
	print("_heartbeat")	

func _disconnected():
	print("_disconnected")	

func Request(route,msg,obj,method):
	if pomelo != null:
		self.pomelo.Quest(route,msg,obj,method)

###############################[Leaf接口]################################################
func InitLeaf(ip:String,port:int):
	goleaf = load("res://network/net_goleaf.gd").new()
	goleaf.Init(ip,port)
	add_child(goleaf)
	
func RegisterLeafNode(businessNode:Node):
	if goleaf != null:
		goleaf.RegisterNode(businessNode)
		
func SendLeafData(data:PackedByteArray):
	if goleaf != null:
		goleaf.SendData(data)
###############################[HTTP接口]################################################
func GetServerPid(host:String,port:int)->int:
	if self.pid == 0:
		httpClient.Request(host, port,'/pid/list',{},{instance=self,f='_pids'})
		#set_process(true)
	return self.pid

#func Login(username,password):
	#httpClient.Request(url, urlport,'/login',{
		#"pid":self.pid,
		#"account":username,
		#"password":password
	#},{instance=self,f='login'})
#
#func Register(username,password):
	#httpClient.Request(url, urlport,'/register?',{
		#"account":username,
		#"password":password
	#},{instance=self,f='_register'})
	#http://127.0.0.1:8089/register?account=test11&password=test11

