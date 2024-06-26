extends Node

# tcp实例与接收线程
var connHandle = StreamPeerTCP.new()
var recvThread = Thread.new()
var mutex: Mutex
var semaphore: Semaphore
var exit_thread := false
#服务器IP端口
var serverIP: String = ""  #"127.0.0.1"
var serverPort: int = 10011  #9968
# 重连设置
var reconnect_timer: Timer = null
var reconnect_interval = 2.0  # 重连间隔时间，单位秒

# 业务节点列表 通过外部注册进来
# 注明:【业务转至节点处理，节点脚本上务必有其回包同名的处理函数,否则业务无法处理】
var nodeList: Array[Node] = []

# 协议脚本 如需处理其他需加载
const loginProto = preload("res://protogd/login.gd")
#const commProto = preload("res://protogd/gamecomm.gd")
#const sanguoxiaoProto = preload("res://protogd/sanguoxiao.gd")

# 消息映射
var msgMap: Variant = {}
var msgTable: Variant = {}
var msgFile: String = "res://msg/message_id.json"
var loginMsg: Variant = {}
# 定义消息体信号，该部分由msgFile对应生成
var signalFile: String = "res://GlobalSignal.gd"
#数据接受大小
var revNum: int = 0
# 信号
signal connection_closed
signal connection_error


func _ready() -> void:
	print("准备")
	# 消息名称-消息ID
	loadFileContent(msgFile)
	# 根据生成全局信号
	#genGlobalSignal()
	#连接服务器
	connHandle.set_big_endian(true)
	start_reconnect()
	# 开启接受数据的线程
	start_recv()
	#定时重连
	reconnect_timer = Timer.new()
	reconnect_timer.one_shot = false
	reconnect_timer.wait_time = reconnect_interval
	reconnect_timer.connect("timeout", checkNetwork)
	add_child(reconnect_timer)
	reconnect_timer.start()


#################################【外部接口】########################################################
func Init(ip: String, port: int) -> void:
	connHandle.disconnect_from_host()
	serverIP = ip
	serverPort = port


# 注册业务节点
func RegisterNode(businessNode: Node):
	nodeList.append(businessNode)


# 发送数据
func SendData(data: PackedByteArray, msgName: String = "") -> bool:
	if connHandle.get_status() != connHandle.STATUS_CONNECTED:
		return false
	if msgName == "":
		msgName = GetFuncName(1)
	if msgTable.has(msgName):
		send_data(msgTable[msgName], data)
	return true


# 获取层级上的函数名
func GetFuncName(index: int = 0) -> String:
	# 获取当前调用堆栈
	var stack = get_stack()
	# 获取最后一个堆栈帧，即当前正在执行的函数
	var size = stack.size()
	if size - index - 2 < 0:
		return ""
	return stack[index + 1]["function"]


#################################【消息协议】########################################################
# 加载消息映射文件
func loadFileContent(fileName: String) -> void:
	# 设置要读取的文件路径
	msgMap = JSON.parse_string(FileAccess.open(fileName, FileAccess.READ).get_as_text())
	for key in msgMap:
		msgTable[msgMap[key]] = key
		if int(key) <= 56:
			loginMsg[key] = msgMap[key]


# 根据消息映射 生成全局的信号
func genGlobalSignal():
	var signalgd = FileAccess.open(signalFile, FileAccess.WRITE_READ)
	var content: String = signalgd.get_as_text()
	var data: String = "extends Node\n"
	for key in msgMap:
		if msgMap[key].contains("Resp"):
			data += "signal " + msgMap[key] + "(" + "param:PackedByteArray" + ")\n"
	if 0 != content.casecmp_to(data):
		signalgd.store_string(data)
	signalgd.close()
	print(data)


#################################【网络连接】########################################################
# 连接服务器
func start_reconnect():
	print("正在连接服务器")
	connHandle.disconnect_from_host()
	connHandle.connect_to_host(serverIP, serverPort)

	if not self.is_connected("connection_closed", _on_ConnectionClosed):
		self.connect("connection_closed", _on_ConnectionClosed)
	if not self.is_connected("connection_error", _on_ConnectionError):
		self.connect("connection_error", _on_ConnectionError)


# 当连接关闭时
func _on_ConnectionClosed():
	print("连接已关闭，准备重连")
	start_reconnect()


# 当连接错误时
func _on_ConnectionError():
	print("连接错误，准备重连")
	start_reconnect()


# 网络检测
func checkNetwork():
	connHandle.poll()
	var status = connHandle.get_status()
	match status:
		connHandle.STATUS_CONNECTED:
			print("发起心跳1")
			heartbeat()
			print("发起心跳2")
		connHandle.STATUS_NONE:
			print("服务器断开")
			emit_signal("connection_closed")
		connHandle.STATUS_CONNECTING:
			print("正在尝试连接服务器")
		connHandle.STATUS_ERROR:
			print("服务器连接出错")
			emit_signal("connection_error")

		_:
			print("不匹配任何特定条件")
	return


#################################【心跳包】########################################################
# 发送心跳
func heartbeat():
	semaphore.post()
	SendData(loginProto.PingReq.new().to_bytes(), "PingReq")


#################################【线程: 接收数据】########################################################
# 开启接收线程 【注意:由心跳决定是否接收数据】
func start_recv():
	mutex = Mutex.new()
	semaphore = Semaphore.new()
	exit_thread = false
	recvThread.start(Callable(self, "_recv_thread"))


# 线程接收网络数据
func _recv_thread():
	print("接收数据-->开始")
	while true:
		semaphore.wait()  # Wait until posted.
		mutex.lock()
		var should_exit = exit_thread  # Protect with Mutex.
		mutex.unlock()
		if should_exit:
			break
		# 处理请求
		mutex.lock()
		recv_data()
		mutex.unlock()


# 退出线程
func _exit_thread_():
	# Set exit condition to true.
	mutex.lock()
	exit_thread = true  # Protect with Mutex.
	mutex.unlock()
	# Unblock by posting.
	semaphore.post()
	# Wait until it exits.
	recvThread.wait_to_finish()


#################################【网络数据处理：核心】########################################################
# 消息处理函数
func handleMsg(id: int, data: PackedByteArray):
	var strID = var_to_str(id)
	if msgMap.has(strID):
		print("收到 消息ID:", id, " 消息类型:", msgMap[strID], " 内容大小:", data.size())
		#解析消息
		for tempNode in nodeList:
			#分派给(含处理函数）节点
			if tempNode.has_method(msgMap[strID]):
				tempNode.call(msgMap[strID], data)
			#emit_signal(msgMap[strID])
	else:
		print("收到的数据有误", id, " data:", data)
	pass


# 发送数据
func send_data(packet_id: Variant, data: PackedByteArray):
	# 将数据转换为字节格式
	var id = int(packet_id)
	# 获取数据内容的长度
	var size = data.size()
	var data_length = size
	var packet = PackedByteArray()
	data_length += 2
	# 首四位的字节，前两位表示字节长度 这两位大小不计算在长度内；后两位表示消息ID,其大小计算在长度内
	# 长度占两字节 大端模式 因此取高位字节
	packet.append(data_length >> 8 & 0xff)
	packet.append(data_length & 0xff)
	# id占两字节
	packet.append(id >> 8 & 0xff)
	packet.append(id & 0xff)

	packet.append_array(data)
	# 发送数据包
	connHandle.put_partial_data(packet)
	if size > 0:
		print(
			"len:",
			data_length,
			" id:",
			packet_id,
			" size:",
			size,
			" data:",
			data,
			" packet:",
			packet
		)


# 处理接收数据
func recv_data():
	revNum = connHandle.get_available_bytes()
	if revNum > 0:
		var recvData = connHandle.get_data(revNum)
		if recvData[0] == OK:
			print("接收到:", recvData[1], revNum)
			var index: int = 0
			var data: Array = recvData[1]
			var allSize = data.size()
			# 取前四字节来判是否需要分包解析
			while allSize - 4 >= 0:
				# 减去本身两字节，求剩下的数据长度
				var msgLen: int = data[index] * 256 + data[index + 1] - 2
				var msgId: int = data[index + 2] * 256 + data[index + 3]
				if msgLen > 0:  #过滤心跳打印
					print("收到的msgID:", msgId, " 消息长度:", msgLen)
				# 消息处理，即信号派发
				handleMsg(msgId, data.slice(index + 4, index + 4 + msgLen))
				allSize -= 4 + msgLen
				index += 4 + msgLen
		else:
			print("收到的数据有误，错误码:", recvData[0])


#################################【测试数据】########################################################
# 测试发送协议
func test_send():
	# 测试数据
	# 账号注册
	#var regist = loginProto.RegisterReq.new()
	#regist.set_Name("KKK")
	#regist.set_Password("123456")
	#send_data_packet(msgTable["RegisterReq"],regist.to_bytes())
	# 账号登录
	var req = loginProto.LoginReq.new()
	req.set_Account("KKK")
	req.set_Password("123456")
	send_data(msgTable["LoginReq"], req.to_bytes())

#func _on_btn_link_pressed() -> void:
#var ip = %text_ip.text
#var port :int = int(%text_port.text)
#if ip == "":
#ip = "127.0.0.1"
#if port == 0:
#port = 9968
#connHandle.disconnect_from_host()
#connHandle.connect_to_host(ip, port)
#connHandle.poll()
#var status = connHandle.get_status()
#if status == connHandle.STATUS_CONNECTED:
#print("recv---!!!---XXX")
#%richlab_hint.text =  "连接成功 {ip}:{port}".format({ "ip":ip, "port":port })
#if !recvThread.is_started():
#recvThread.start(Callable(self, "recv"))
#else:
#%richlab_hint.text =  "连接失败 请检查地址是否正确 {ip}:{port} {status}".format({ "ip":ip, "port":port,"status":status })
#print( "ip:",ip, " port:",port," status:",status)
#status = connHandle.STATUS_NONE
#pass

## 转换为小端输出 一般不用
#func swap_endian(val):
#return ((val & 0xFF) << 24) | ((val & 0xFF00) << 8) | ((val & 0xFF0000) >> 8) | ((val & 0xFF000000) >> 24)
#
#func toEndianByte(val:int)->PackedByteArray:
#var packet = PackedByteArray()
#packet.append(val>> 24 & 0xff)
#packet.append(val>> 16 & 0xff)
#packet.append(val>> 8 & 0xff)
#packet.append(val & 0xff)
#return packet
