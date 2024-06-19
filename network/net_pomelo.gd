extends Node

var socket = StreamPeerTCP.new()
var socketIp: String
var socketPort: int

var _connected = false
var isHandshaked = false
var protobuf = load("res://network/pomelo_protobuf.gd").new()
var protocol = load("res://network/pomelo_protocol.gd").new()
var package = protocol.package
var message = protocol.message
var heartbeatInterval = 1000
var gapThreshold = 100
var lastServerTick = Time.get_unix_time_from_system()
var isClientTicked = false

var protoVersion
var clientProtos
var abbrs = {}
var serverProtos = {}
var _dict = {}
var reqId = 0

const ST_HEAD = 1
const ST_BODY = 2
const ST_CLOSED = 3
const headSize = 4

var headOffset = 0
var packageOffset = 0
var packageSize = 0
var packageBuffer = PackedByteArray()
var state = ST_HEAD
var headBuffer = PackedByteArray()

var signals = {}
var callbacks = {}
var routeMap = {}
var handshakeBuffer = {
	sys =
	{
		heartbeat = 60,
		dict = {},
		serializer = "protobuf",
		type = "js-websocket",
		version = "0.0.1",
		rsa = {}
	},
	user = {}
}
var rsa  #window.rsa
var localStorage = ConfigFile.new()
var useCrypto
var routes = {}


#var data
func _init():
	add_user_signal("error")
	add_user_signal("io-error")
	add_user_signal("heartbeat timeout")
	add_user_signal("disconnected")
	add_user_signal("kick")
	add_user_signal("reconnect")
	add_user_signal("close")


func _ready():
	headBuffer.resize(4)
	set_process(true)
	var err = localStorage.load("res://user_config.cfg")
	if err:
		print("load user config error. code:", err)


func on(event, instance, method):
	connect(event, Callable(instance, method))


func _process(_delta):
	var status = socket.get_status()
	if status != socket.STATUS_CONNECTED:
		return
	if (
		isHandshaked
		and (
			(Time.get_unix_time_from_system() - lastServerTick)
			> (heartbeatInterval * 2 + gapThreshold)
		)
	):
		print("heartbeat timeout.")
		emit_signal("heartbeat timeout")
		disconnected()
		#lastServerTick = Time.get_unix_time_from_system()

	if isHandshaked and (Time.get_unix_time_from_system() - lastServerTick >= heartbeatInterval):
		if not isClientTicked:
			var obj = package.encode(package.TYPE_HEARTBEAT)
			_send(obj)
			isClientTicked = true
			print("发送心跳")

	var output = socket.get_partial_data(1024)
	var errCode = output[0]
	var outputData = output[1]
	#print(output)
	if errCode != 0:
		return _onerror(errCode)
		#return print( "receive ErrCode:" + str(errCode)+"|||")
	#var outStr = outputData.get_string_from_utf8()
	#if(outStr == ""):
	if not outputData.size():
		return
	var chunk = outputData
	var offset = 0
	var end = chunk.size()
	#print('recv data size ',end)
	if state == ST_HEAD and packageBuffer == null and not _checkTypeData(chunk[0]):
		print("invalid head message")
		return
	while offset < end:
		if state == ST_HEAD:
			offset = _readHead(chunk, offset)
		if state == ST_BODY:
			offset = _readBody(chunk, offset)


func _checkTypeData(data):
	return (
		data == package.TYPE_HANDSHAKE
		|| data == package.TYPE_HANDSHAKE_ACK
		|| data == package.TYPE_HEARTBEAT
		|| data == package.TYPE_DATA
		|| data == package.TYPE_KICK
	)


func _getBodySize():
	var size = 0
	for i in [1, 2, 3]:
		if i > 1:
			size <<= 8
		#print(i,headBuffer.size())
		size += headBuffer[i]  #headBuffer.readUInt8(i)
	return size


func _readHead(data, offset):
	var hlen = headSize - headOffset
	var dlen = data.size() - offset
	var minlen = min(hlen, dlen)
	var dend = offset + minlen
	#data.copy(headBuffer,headOffset,offset,dend)
	for i in range(minlen):
		headBuffer.set(headOffset + i, data[offset + i])
		#print("set head buffer",headOffset+i,data.get(offset+i))
	headOffset += minlen
	if headOffset == headSize:
		var size = _getBodySize()
		if size < 0:
			print("invalid body size.%d", size)
			return
		packageSize = size + headSize
		#packageBuffer = Buffer.new(packageSize)
		#headBuffer.copy(packageBuffer,0,0,headSize)
		packageBuffer.resize(packageSize)
		for i in range(headSize):
			packageBuffer.set(i, headBuffer[i])
		packageOffset = headSize
		state = ST_BODY
	return dend


func _readBody(data, offset):
	#print("接收 ",data,offset)
	var blen = packageSize - packageOffset
	var dlen = data.size() - offset
	var size = min(blen, dlen)
	var dend = offset + size
	#data.copy(packageBuffer,packageOffset,offset,dend)
	for i in range(size):
		packageBuffer.set(packageOffset + i, data[offset + i])
	packageOffset += size
	if packageOffset == packageSize:
		var buffer = packageBuffer
		_onmessage(buffer)
		_reset()
	return dend


func _reset():
	headOffset = 0
	packageOffset = 0
	packageSize = 0
	packageBuffer.resize(0)
	state = ST_HEAD


func _deCompose(msg):
	var route = str(msg.route)
	if msg.compressRoute:
		if not abbrs.has(route):
			#print('aaaaaaaaaa',typeof(route),abbrs.to_json())
			return msg
		route = abbrs[route]
		msg.route = abbrs[route]
	if serverProtos != null and serverProtos.has(route):
		return protobuf.decode(route, msg.body)
	else:
		return JSON.parse_string(protocol.strdecode(msg.body))


func _decode(data):
	#print('_decode 0:',data.size())
	var msg = message.decode(data)
	#print('_decode 1: ',msg.to_json())
	if msg.id > 0:
		msg.route = routeMap[int(msg.id)]
		routeMap.erase(int(msg.id))
		if not msg.route:
			return
	#msg.body = _deCompose(msg)
	#print('_decode 2: ',msg.to_json())
	return msg


func _onopen():
	var buf = protocol.strencode(JSON.stringify(handshakeBuffer))
	var obj = package.encode(package.TYPE_HANDSHAKE, buf)
	#for i in range(obj.size()):
	#	print(obj.get(i))
	_send(obj)
	print("<--- _onOpen ")


func _onmessage(data):
	_processPackage(package.decode(data))
	#if heartbeatTimeout:
	#	nextHeartbeatTimeout = Time.get_unix_time_from_system() + heartbeatTimeout


func _onerror(code = null):
	emit_signal("io-error", code)
	if code == 1:
		_onclose()
	elif code == 18:
		_onReconnect()

	print("socket error.", code)


func _onclose():
	emit_signal("close")
	emit_signal("disconnected")
	print("socket close.")


func _onReconnect():
	emit_signal("reconnect")
	Init(self.socketIp, self.socketPort)
	print("socket reconnect.")


###############################[外部接口]#################################################
func Init(host: String, port: int) -> void:
	self.socketIp = host
	self.socketPort = port
	print("pomelo init")
	#user 数据
	#return _initSocket(host,port)
	print("connect to ", host, ":", port)
	if localStorage.has_section_key("pomelo", "protos") and protoVersion == 0:
		var protos = JSON.parse_string(localStorage.get_value("pomelo", "protos"))
		if not protoVersion:
			protoVersion = 0
		if protos.server:
			serverProtos = protos.server
		else:
			serverProtos = {}
		if protos.client:
			clientProtos = protos.client
		else:
			clientProtos = {}
		if protobuf:
			protobuf.init({encoderProtos = clientProtos, decoderProtos = serverProtos})
	handshakeBuffer.sys.protoVersion = protoVersion
	socket.disconnect_from_host()
	socket.connect_to_host(host, port)
	socket.poll()
	_connected = socket.get_status() == socket.STATUS_CONNECTED
	if _connected:
		_onopen()
	return


func Quest(route, msg, obj, method):
	if not _connected:
		print("pomelo have not connect.")
		_onReconnect()
		#return
	reqId = reqId + 1
	_sendMessage(reqId, route, msg)
	callbacks[reqId] = {}
	callbacks[reqId].instance = obj
	callbacks[reqId].f = method
	routeMap[reqId] = route


func Notify(route, msg):
	if not msg:
		msg = {}
	_sendMessage(0, route, msg)


func disconnected():
	_connected = false
	socket.disconnect_from_host()
	_onclose()


##############################[内部]############################################
func _connect(host, port):
	return socket.connect_to_host(host, port)


func _sendMessage(reqid, route, msg):
	print("send data->id: ", reqid, " route:", route, " msg:", str(msg))
	if useCrypto:
		print("no imp crypto now")
		return
	var type = message.TYPE_NOTIFY
	if reqid:
		type = message.TYPE_REQUEST

	if clientProtos != null and clientProtos.has(route):
		msg = protobuf.encode(route, msg)
	elif typeof(msg) == TYPE_STRING:
		msg = protocol.strencode(msg)

	var compressRoute = 0
	if _dict != null and _dict.has("route"):
		route = _dict[route]
		compressRoute = 1
	msg = message.encode(reqId, type, compressRoute, route, msg)
	var packet = package.encode(package.TYPE_DATA, msg)
	_send(packet)
	print("<--- _sendMessage ")


func _send(msg):
	#for i in range(msg.size()):
	#print(msg[i])
	var rets = socket.put_data(msg)
	var bytedata = PackedByteArray()
	bytedata.append_array(msg)
	print("发送 ", msg, "结果", rets)


func _handshake(data):
	var strData = protocol.strdecode(data)
	var res = JSON.parse_string(strData)
	if res.code == 501:
		emit_signal("error", "client version not fullfill")
		return
	if res.code != 200:
		emit_signal("error", "handshake fail.")
		return
	if res.sys != null:
		if res.sys.has("heartbeat"):
			if res.sys.heartbeat != 0:
				heartbeatInterval = res.sys.heartbeat * 1000
				print("set hartbeatInterval:", heartbeatInterval)
				#heartbeatTimeout = heartbeatInterval*2
	#_initData(res) 暂不保存配置
	var obj = package.encode(package.TYPE_HANDSHAKE_ACK)
	_send(obj)
	print("<--- _handshake 握手数据....")
	#init(socket.get_connected_host(),socket.get_connected_port())
	#emit_signal("init",socket)


func _onData(data):
	var msg = data
	#if _decode:
	msg = _decode(msg)
	_processMessage(msg)


func _onKick(data):
	var msg = data
	#if _decode:
	msg = _decode(msg)
	emit_signal("kick", msg)


func _handlers(type, body):
	if type == package.TYPE_HANDSHAKE:
		_handshake(body)
		isHandshaked = true
	elif type == package.TYPE_HEARTBEAT:
		if heartbeatInterval != 0:
			lastServerTick = Time.get_unix_time_from_system()
			isClientTicked = false
			return
	elif type == package.TYPE_DATA:
		_onData(body)
	elif type == package.TYPE_KICK:
		_onKick(body)
	else:
		pass


func _processPackage(msgs):
	if typeof(msgs) == TYPE_ARRAY:
		for i in msgs:
			var msg = msgs[i]
			_handlers(msg.type, msg.body)
	else:
		_handlers(msgs.type, msgs.body)


func _processMessage(msg):
	print("recv： ", msg)
	if not msg.has("id") or not msg.id:
		return emit_signal(str(msg.route), msg.body)
	var cb = callbacks[msg.id]
	var f = Callable(cb.instance, cb.f)
	f.call(msg.body)
	callbacks.erase(msg.id)
	return


func _initData(data):
	if data == null or data.sys == null:
		return
	if not data.sys.has("dict"):
		return
	if not data.sys.has("protos"):
		return
	_dict = data.sys["dict"]
	var protos = data.sys.protos
	if _dict != null:
		abbrs = {}
		for route in _dict:
			abbrs[_dict[route]] = route
	if protos != null:
		if protos.version:
			protoVersion = protos.version
		else:
			protoVersion = 0
		if protos.server != null:
			serverProtos = protos.server
		else:
			serverProtos = {}
		if protos.client != null:
			clientProtos = protos.client
		else:
			clientProtos = {}
		if protobuf != null:
			var d = {encoderProtos = protos.client, decoderProtos = protos.server}
			protobuf.init(d)
		localStorage.set_value("pomelo", "protos", JSON.parse_string(protos))
	localStorage.save("res://network/user_config.cfg")
