var constant = {
	"uInt32": 0,
	"sInt32": 0,
	"int32": 0,
	"double": 1,
	"string": 2,
	"message": 2,
	"float": 5
}

class Util:
	static func isSimpleType(type):
		return (type == "uInt32" || type == "sInt32" || type == "int32" || type=="uInt64" || type=="sInt64" || type=="float" || type=="double")

class Encoder:
	var codec
	var protos
	var constant
	var util

	func _init(codec1,constant1,util1):
		self.codec = codec1
		self.constant = constant1
		self.util = util1

	func init(protos1):
		self.protos = protos1
		if(self.protos == null):
			self.protos = {}

	func encode(route,msg):
		var protos1
		if self.protos.has(route):
			protos1 = self.protos[route]
		if not checkMsg(msg,protos1):
			return null
		var length = codec.byteLength(JSON.stringify(msg))
		var buffer = PackedByteArray()
		buffer.resize(length)
		var uInt8Array = PackedByteArray(buffer)
		var offset = 0
		if protos1 != null:
			offset = encodeMsg(uInt8Array,offset,protos1,msg)
			if offset>0:
				var arr = PackedByteArray()
				for i in range(offset):
					arr.push_back(uInt8Array[i])
				return arr
		return null

	func checkMsg(msg,protos1):
		if protos1 == null:
			return false
		for name in protos1:
			var proto = protos1[name]
			if proto.option == "required":
				if not msg.has(name):
					print("no property exist for required,name:%s",name)
					return false
			elif proto.option == "optional":
				if not msg.has(name):
					var message = protos1.__message[proto.type] || self.protos["message "+proto.type]
					if message != null && !checkMsg(msg[name],message):
						print("inner proto error! name:%s",name)
						return false
			elif proto.option == "repeated":
				var message = protos1.__message[proto.type]||self.protos["message "+proto.type]
				if msg.has(name) && message != null:
					for i in msg[name]:
						if not checkMsg(msg[name][i],message):
							return false
		return true

	func encodeMsg(buffer,offset,protos1,msg):
		var tmp
		for name in msg:
			if protos1.has(name):
				var proto = protos1[name]
				if proto.option == "required" || proto.option == "optional":
					tmp = writeBytes(buffer,offset,encodeTag(proto.type,proto.tag))
					offset = tmp.offset
					buffer = tmp.buffer
					tmp = encodeProp(msg[name],proto.type,offset,buffer,protos1)
					offset = tmp.offset
					buffer = tmp.buffer
				elif proto.option == "repeated":
					if msg[name].size() >0:
						tmp = encodeArray(msg[name],proto,offset,buffer,protos1)
						offset = tmp.offset
						buffer = tmp.buffer
		return {offset=offset,buffer=buffer}

	func encodeProp(value,type,offset,buffer,protos1):
		var tmp
		if type == 'uInt32':
			tmp = writeBytes(buffer,offset,codec.encodeUInt32(value))
			offset = tmp.offset
			buffer = tmp.buffer
		elif type == 'int32' || type == 'sInt32':
			tmp = writeBytes(buffer,offset,codec.encodeSInt32(value))
			offset = tmp.offset
			buffer = tmp.buffer
		elif type == 'float':
			tmp = writeBytes(buffer,offset,codec.encodeFloat(value))
			offset += 4
			buffer = tmp.buffer
		elif type == 'double':
			tmp = writeBytes(buffer,offset,codec.encodeDouble(value))
			offset += 8
			buffer = tmp.buffer
		elif type == 'string':
			var length = codec.byteLength(value)
			tmp = writeBytes(buffer,offset,codec.encodeUInt32(length))
			offset = tmp.offset
			buffer = tmp.buffer
			codec.encodeStr(buffer,offset,value)
			offset += length
		else:
			var message
			if protos1.__message.has(type):
				message = protos1.__message[type]
			elif self.protos1.has('message '+type):
				message = self.protos1['message '+type]
			if message != null:
				var tmpBuffer = PackedByteArray()
				tmpBuffer.resize(codec.byteLength(value.to_json())*2)
				var length = 0
				tmp = encodeMsg(tmpBuffer,length,message,value)
				length = tmp.offset
				buffer = tmp.buffer
				tmp = writeBytes(buffer,offset,codec.encodeUInt32(length))
				offset = tmp.offset
				buffer = tmp.buffer
				for i in range(length):
					buffer[offset] = tmpBuffer[i]
					offset += 1
		return {buffer=buffer,offset=offset}

	func encodeArray(array,proto,offset,buffer,protos1):
		#var i = 0
		var tmp
		if util.isSimpleType(proto.type):
			tmp = writeBytes(buffer,offset,encodeTag(proto.type,proto.tag))
			offset = tmp.offset
			buffer = tmp.buffer
			tmp = writeBytes(buffer,offset,codec.encodeUInt32(array.size()))
			offset = tmp.offset
			buffer = tmp.buffer
			for index in range(array.size()):
				tmp = encodeProp(array[index],proto.type,offset,buffer,protos1)
				offset = tmp.offset
				buffer = tmp.buffer
		else:
			for index in range(array.size()):
				tmp = writeBytes(buffer,offset,encodeTag(proto.type,proto.tag))
				offset = tmp.offset
				buffer = tmp.buffer
				tmp = encodeProp(array[index],proto.type,offset,buffer,protos1)
				offset = tmp.offset
				buffer = tmp.buffer
		return offset

	func writeBytes(buffer,offset,bytes):
		for i in range(bytes.size()):
			buffer[offset] = bytes[i]
			offset += 1
		return {buffer=buffer,offset=offset}

	func encodeTag(type,tag):
		var value = 2
		if constant.has(type):
			value = constant[type]
		return codec.encodeUInt32((tag<<3)|value)

class Decoder:
	var codec
	var protos
	var constant
	var util
	var offset = 0
	var buffer

	func _init(codec1,constant1,util1):
		self.codec = codec1
		self.constant = constant1
		self.util = util1

	func init(protos1):
		self.protos = protos1
		if(self.protos == null):
			self.protos = {}

	func setProtos(protos1):
		if protos1 == null:
			self.protos = protos1
	
	func decode(route,buf):
		buffer = buf
		offset = 0
		
		if protos.has(route):
			var proto = protos[route]
			return decodeMsg({},proto,buffer.size())
		return null

	func decodeMsg(msg,protos1,length):
		while offset<length:
			var head = getHead()
			var type = head.type
			var tag = head.tag

			var name = protos1.__tags[str(tag)]
			var option = protos1[name].option
			if option == "optional" || option == "required":
				msg[name] = decodeProp(protos1[name].type,protos1)
				#print('decodeMsg name:',name,' type: ',protos[name].type,' ->',msg[name])
			elif option == "repeated":
				if not msg.has(name):
					msg[name] = []
				msg[name] = decodeArray(msg[name],protos1[name].type,protos1)
		return msg

	func isFinish(_msg,protos1):
		return (!protos1.__tags[peekHead().tag])
	

	func getHead():
		var bytes = getBytes()
		var tag = codec.decodeUInt32(bytes)
		return {type=tag&0x7,tag=tag>>3}

	func peekHead():
		var tag = codec.decodeUInt32(peekBytes())
		return {type = tag&0x7,tag = tag>>3}

	func decodeProp(type,protos1=null):
		if type == 'uInt32':
			return codec.decodeUInt32(getBytes())
		elif type == 'int32' or type == 'sInt32':
			return codec.decodeSInt32(getBytes())
		elif type == 'float':
			var f = codec.decodeFloat(buffer,offset)
			offset += 4
			return f
		elif type == 'double':
			var d = codec.decodeDouble(buffer,offset)
			offset += 8
			return d
		elif type == 'string':
			var length = codec.decodeUInt32(getBytes())
			var s = codec.decodeStr(buffer,offset,length)
			offset += length
			return s
		else:
			var message = null
			if protos1 != null:
				if protos1.__messages.has(type):
					message = protos1.__messages[type]
				elif self.protos.has('message '+type):
					message = self.protos['message '+type]
			if message != null:
				var length = codec.decodeUInt32(getBytes())
				var msg = {}
				msg = decodeMsg(msg,message,offset+length)
				return msg

	func decodeArray(array,type,protos1):
		if util.isSimpleType(type):
			var length = codec.decodeUInt32(getBytes())
			for i in range(length):
				array.push_back(decodeProp(type))
		else:
			array.push_back(decodeProp(type,protos1))
		return array

	func getBytes(flag=false):
		var bytes = []
		var pos = offset
		flag = flag# || false
		var b
		b = buffer[pos]
		bytes.push_back(b)
		pos+=1
		while b>= 128:
			b = buffer[pos]
			bytes.push_back(b)
			pos+=1
		if not flag:
			offset = pos
		return bytes

	func peekBytes():
		return getBytes(true)

class Codec:
	var buffer = PackedByteArray()
	var float32Array
	var float64Array
	var uInt8Array

	func _init():
		buffer.resize(8)
		float32Array = []#RealArray.new()
		float64Array = []#RealArray.new()
		uInt8Array = PackedByteArray(buffer) 

	func encodeUInt32(xn):
		var n = floor(xn)
		var result = []
		var tmp = n%128
		var next = floor(n/128)
		if next != 0:
			tmp = tmp + 128
		result.push(tmp)
		n = next
		while n!=0:
			tmp = n%128
			next = floor(n/128)
			if next != 0:
				tmp = tmp + 128
			result.push(tmp)
			n = next
		return result

	func encodeSInt32(xn):
		var n = int(xn)
		n = n*2
		if n<0:
			n = abs(n)*2-1
		return encodeUInt32(n)

	func decodeUInt32(bytes):
		var n = 0
		for i in range(bytes.size()):
			var m = int(bytes[i])
			n = n+(m&0x7f)*int(pow(2,(7*i)))
			if m<128:
				return n
		return n

	func decodeSInt32(bytes):
		var n = decodeUInt32(bytes)
		var flag:int = 1
		var yu:int = n%2
		if yu == 1:
			flag = -1
		n = (float(yu + n)/2)*flag
		return n

	func encodeFloat(f):
		float32Array[0] = f
		return uInt8Array

	func decodeFloat(bytes,offset):
		if bytes!=null or bytes.size()<(offset+4):
			return null
		for i in range(4):
			uInt8Array[i] = bytes[offset + i]
		return float32Array[0]

	func encodeDouble(d):
		float64Array[0] = d
		#return uInt8Array.subarray(0,8)
		return uInt8Array

	func decodeDouble(bytes,offset):
		if bytes!=null or bytes.size()<(offset+8):
			return null
		for i in range(8):
			uInt8Array[i] = bytes[offset + i]
		return float64Array[0]

	func encodeStr(bytes,offset,s):
		for i in range(s.length()):
			var code = s.ord_at(i)
			var codes = encode2UTF8(code)
			for j in range(codes.size()):
				bytes[offset] = codes[j]
				offset += 1
		return offset

	func decodeStr(bytes,offset,length):
		var array = PackedByteArray()
		var end = offset + length
		while offset<end:
			var code = 0
			if bytes[offset]<128:
				code = bytes[offset]
				offset+=1
			elif bytes[offset] < 224:
				code = ((bytes[offset] & 0x3f)<<6) + (bytes[offset+1] & 0x3f)
				offset += 2
			else:
				code = ((bytes[offset]&0x0f)<<12) + ((bytes[offset+1]&0x3f)<<6) + (bytes[offset+2]&0x3f)
				offset += 3
			array.push_back(code)
		return array.get_string_from_utf8()

	func byteLength(s):
		if typeof(s) != TYPE_STRING:
			return -1
		var length = 0
		for i in range(s.length()):
			var code = s.ord_at(i)
			length += codeLength(code)
		return s.length()

	func encode2UTF8(charCode):
		if charCode <= 0x7f:
			return [charCode]
		elif charCode <= 0x7ff:
			return [0xc0|(charCode>>6),0x80|(charCode&0x3f)]
		else:
			return [0xe0|(charCode>>12),0x80|((charCode&0xfc0)>>6),0x80|(charCode&0x3f)]

	func codeLength(code):
		if code <= 0x7f:
			return 1
		elif code <= 0x7ff:
			return 2
		else:
			return 3

var util = Util.new()
var codec = Codec.new()
var encoder = Encoder.new(codec,constant,util)
var decoder = Decoder.new(codec,constant,util)

func init(opts):
	encoder.init(opts.encoderProtos)
	decoder.init(opts.decoderProtos)

func encode(key,msg):
	return encoder.encode(key,msg)
	
func decode(key,msg):
	#print('protobuf decode route:',key,', msg: ',msg.size())
	return decoder.decode(key,msg)
	
