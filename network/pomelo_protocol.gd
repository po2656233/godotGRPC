var PKG_HEAD_BYTES = 4;
var MSG_FLAG_BYTES = 1;
var MSG_ROUTE_CODE_BYTES = 2;
var MSG_ID_MAX_BYTES = 5;
var MSG_ROUTE_LEN_BYTES = 1;

var MSG_ROUTE_CODE_MAX = 0xffff;

var MSG_COMPRESS_ROUTE_MASK = 0x1;
var MSG_TYPE_MASK = 0x7;

class Package:
	const TYPE_HANDSHAKE = 1
	const TYPE_HANDSHAKE_ACK = 2
	const TYPE_HEARTBEAT = 3
	const TYPE_DATA = 4
	const TYPE_KICK = 5
	var _parent
	
	func _init(parent):
		_parent = parent
	
	func encode_bak(type,body):
		var length = 0
		if body != null:
			length = body.size()
		var buffer = PackedByteArray()
		buffer.push_back(type)
		buffer.push_back((length>>16)&0xff)
		buffer.push_back((length>>8)&0xff)
		buffer.push_back(length&0xff)
		if body != null:
			for i in range(body.size()):
				buffer.push_back(body.get(i))
	
	func encode(type,body=null):
		var length 
		if body != null:
			length = body.size()
		else:
			length = 0
		var buffer = PackedByteArray()
		buffer.resize(_parent.PKG_HEAD_BYTES+length)
		var index = 0
		buffer[index] = type & 0xff
		index += 1
		buffer[index] = (length>>16) & 0xff
		index += 1
		buffer[index] = (length >> 8) & 0xff
		index += 1
		buffer[index] = length & 0xff
		index += 1
		if typeof(body) != null:
			buffer = _parent._copyArray(buffer,index,body,0,length)

		return buffer

	
	func decode(buffer):
		var offset = 0
		var bytes = PackedByteArray(buffer)
		var length = 0
		var rs = []
		while offset < bytes.size():
			var type = bytes[offset]
			offset += 1
			length = ((bytes[offset])) << 16
			offset += 1
			length |= (bytes[offset])<<8
			offset += 1
			length |= bytes[offset]
			offset += 1
			#length = length >> 0 # 无符号右移 >>>
			length = abs(length)# >> 0
			var body = null
			if length:
				body = PackedByteArray()
				body.resize(length)
			body = _parent._copyArray(body,0,bytes,offset,length)
			offset += length
			rs.push_back({"type":type,"body":body})
		var res = rs
		if rs.size() == 1:
			res = rs[0]
		return res
		
	
	
class Message:
	const TYPE_REQUEST = 0
	const TYPE_NOTIFY = 1
	const TYPE_RESPONSE = 2
	const TYPE_PUSH = 3
	var _parent
	
	func _init(parent):
		_parent = parent
	
	func encode(id,type,compressRoute,route,msg):
		var idBytes
		if _parent._msgHasId(type):
			idBytes = _parent._caculateMsgIdBytes(id)
		else:
			idBytes = 0
		var msgLen = _parent.MSG_FLAG_BYTES + idBytes
		if _parent._msgHasRoute(type):
			if compressRoute:
				#if route is not number ,error
				msgLen += _parent.MSG_ROUTE_CODE_BYTES
			else:
				msgLen += _parent.MSG_ROUTE_LEN_BYTES
				if route:
					route = _parent.strencode(route)
					if route.size() > 255:
						print("route maxLength is overflow.")
						return 
					msgLen += route.size()
		if msg != null:
			msgLen += msg.size()
		var buffer = PackedByteArray()
		buffer.resize(msgLen)
		var offset = 0
		var res = _parent._encodeMsgFlag(type,compressRoute,buffer,offset)
		offset = res[0]
		buffer = res[1]
		if _parent._msgHasId(type):
			var resx = _parent._encodeMsgId(id,buffer,offset)
			offset = resx[0]
			buffer = resx[1]
		if _parent._msgHasRoute(type):
			var resx = _parent._encodeMsgRoute(compressRoute,route,buffer,offset)
			offset = resx[0]
			buffer = resx[1]
		if msg != null:
			# encode msg body
			for i in range(msg.size()):
				buffer[offset+i] = msg[i]
			offset += msg.size()
		return buffer

	func decode(buffer):
		var bytes = PackedByteArray(buffer)
		var bytesLen = bytes.size()
		var offset = 0
		var id = 0
		var route = null
		var flag = bytes[offset]
		offset += 1
		var compressRoute = flag & _parent.MSG_COMPRESS_ROUTE_MASK
		var type = (flag >> 1) & _parent.MSG_TYPE_MASK
		if _parent._msgHasId(type):
			var m = int(bytes[offset])
			var i = 0
			
			m = int(bytes[offset])
			id = id + ((m & 0x7f) * pow(2,(7*i)))
			offset += 1
			i += 1
			while m>= 128:
				m = int(bytes[offset])
				id = id + ((m & 0x7f) * pow(2,(7*i)))
				offset += 1
				i += 1
		if _parent._msgHasRoute(type):
			if _parent._msgHasRoute(type):
				if compressRoute:
					route = (bytes[offset]) << 8
					offset += 1
					route |= bytes[offset]
					offset += 1
				else:
					var routeLen = bytes[offset]
					offset += 1
					if routeLen:
						route = PackedByteArray()
						route.resize(routeLen)
						route = _parent._copyArray(route,0,bytes,offset,routeLen)
						route = _parent.strdecode(route)
					else:
						route = ""
					offset += routeLen
		var bodyLen = bytesLen - offset
		var body = PackedByteArray()
		body.resize(bodyLen)
		body = _parent._copyArray(body,0,bytes,offset,bodyLen)
		return {"id":int(id),"type":int(type),"compressRoute":int(compressRoute),"route":route,"body":body}

###########
var package = Package.new(self)
var message = Message.new(self)

func _copyArray(dest,doffset,src,soffset,length):
	for i in range(length):
		dest[doffset+i] = src[soffset+i]
		#print(src[soffset])
	#for i in range(dest.size()):
	#	print(dest.get(i))
	return dest

func _msgHasId(type):
	return type == message.TYPE_REQUEST || type == message.TYPE_RESPONSE

func _msgHasRoute(type) :
	return type == message.TYPE_REQUEST || type == message.TYPE_NOTIFY|| type == message.TYPE_PUSH

func _caculateMsgIdBytes(id):
	var size = 0
	size += 1
	id >>= 7
	while id >0:
		size += 1
		id >>= 7
	return size

func _encodeMsgFlag(type,compressRoute,buffer,offset):
	if type != message.TYPE_REQUEST && type != message.TYPE_NOTIFY && type != message.TYPE_RESPONSE && type != message.TYPE_PUSH:
		print("unkonw message type.",type)
		return 
	var tmp
	if compressRoute:
		tmp = 1
	else:
		tmp = 0
	buffer[offset] = (type << 1) | tmp
	return [offset+MSG_FLAG_BYTES,buffer]

func _encodeMsgId(id,buffer,offset):
	var tmp
	var next
	tmp = id%128
	next = floor(id/128)
	if next != 0:
		tmp = tmp + 128
	buffer[offset] = tmp
	offset += 1
	id = next
	while id != 0:
		tmp = id%128
		next = floor(id/128)
		if next != 0:
			tmp = tmp + 128
		buffer[offset] = tmp
		offset += 1
		id = next
	return [offset,buffer]

func _encodeMsgRoute(compressRoute,route,buffer,offset):
	if compressRoute:
		if route > MSG_ROUTE_CODE_MAX:
			print("route number is overflow.")
			return 
		buffer[offset] = (route>>8) & 0xff
		offset += 1
		buffer[offset] = route & 0xff
		offset +=1
	else:
		if route != null:
			buffer[offset] = route.size() & 0xff
			offset += 1
			buffer = _copyArray(buffer,offset,route,0,route.size())
			offset += route.size()
		else:
			buffer[offset] = 0
			offset += 1
	return [offset,buffer]

func strencode(s:String):
	var raw = PackedByteArray()
	for i in range(s.length()):
		raw.push_back(s.unicode_at(i))
	return raw

func strdecode(buffer):
	return buffer.get_string_from_utf8()
	
func strdecode_old(buffer):
	var bytes = buffer#PackedByteArray()
	var array = PackedByteArray()#[]
	var offset = 0
	var charCode = 0
	var end = bytes.size()
	while offset < end:
		if bytes[offset] < 128:
			charCode = bytes[offset]
			offset += 1
		elif bytes[offset]<224:
			charCode = ((bytes[offset] & 0x3f)<<6) + (bytes[offset+1] & 0x3f)
			offset +=2
		else:
			charCode = ((bytes[offset] & 0x0f)<<12) + ((bytes[offset+1] & 0x3f)<<6) + (bytes[offset+2] & 0x3f)
			offset +=3
		array.push_back(int(charCode))
	#return String.fromCharCode.apply(null, array);
	return array.get_string_from_ascii()
	#return array.get_string_from_utf8()

