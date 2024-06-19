#
# BSD 3-Clause License
#
# Copyright (c) 2018 - 2023, Oleg Malyavkin
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# * Redistributions of source code must retain the above copyright notice, this
#   list of conditions and the following disclaimer.
#
# * Redistributions in binary form must reproduce the above copyright notice,
#   this list of conditions and the following disclaimer in the documentation
#   and/or other materials provided with the distribution.
#
# * Neither the name of the copyright holder nor the names of its
#   contributors may be used to endorse or promote products derived from
#   this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
# CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
# OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

# DEBUG_TAB redefine this "  " if you need, example: const DEBUG_TAB = "\t"

const PROTO_VERSION = 3

const DEBUG_TAB : String = "  "

enum PB_ERR {
	NO_ERRORS = 0,
	VARINT_NOT_FOUND = -1,
	REPEATED_COUNT_NOT_FOUND = -2,
	REPEATED_COUNT_MISMATCH = -3,
	LENGTHDEL_SIZE_NOT_FOUND = -4,
	LENGTHDEL_SIZE_MISMATCH = -5,
	PACKAGE_SIZE_MISMATCH = -6,
	UNDEFINED_STATE = -7,
	PARSE_INCOMPLETE = -8,
	REQUIRED_FIELDS = -9
}

enum PB_DATA_TYPE {
	INT32 = 0,
	SINT32 = 1,
	UINT32 = 2,
	INT64 = 3,
	SINT64 = 4,
	UINT64 = 5,
	BOOL = 6,
	ENUM = 7,
	FIXED32 = 8,
	SFIXED32 = 9,
	FLOAT = 10,
	FIXED64 = 11,
	SFIXED64 = 12,
	DOUBLE = 13,
	STRING = 14,
	BYTES = 15,
	MESSAGE = 16,
	MAP = 17
}

const DEFAULT_VALUES_2 = {
	PB_DATA_TYPE.INT32: null,
	PB_DATA_TYPE.SINT32: null,
	PB_DATA_TYPE.UINT32: null,
	PB_DATA_TYPE.INT64: null,
	PB_DATA_TYPE.SINT64: null,
	PB_DATA_TYPE.UINT64: null,
	PB_DATA_TYPE.BOOL: null,
	PB_DATA_TYPE.ENUM: null,
	PB_DATA_TYPE.FIXED32: null,
	PB_DATA_TYPE.SFIXED32: null,
	PB_DATA_TYPE.FLOAT: null,
	PB_DATA_TYPE.FIXED64: null,
	PB_DATA_TYPE.SFIXED64: null,
	PB_DATA_TYPE.DOUBLE: null,
	PB_DATA_TYPE.STRING: null,
	PB_DATA_TYPE.BYTES: null,
	PB_DATA_TYPE.MESSAGE: null,
	PB_DATA_TYPE.MAP: null
}

const DEFAULT_VALUES_3 = {
	PB_DATA_TYPE.INT32: 0,
	PB_DATA_TYPE.SINT32: 0,
	PB_DATA_TYPE.UINT32: 0,
	PB_DATA_TYPE.INT64: 0,
	PB_DATA_TYPE.SINT64: 0,
	PB_DATA_TYPE.UINT64: 0,
	PB_DATA_TYPE.BOOL: false,
	PB_DATA_TYPE.ENUM: 0,
	PB_DATA_TYPE.FIXED32: 0,
	PB_DATA_TYPE.SFIXED32: 0,
	PB_DATA_TYPE.FLOAT: 0.0,
	PB_DATA_TYPE.FIXED64: 0,
	PB_DATA_TYPE.SFIXED64: 0,
	PB_DATA_TYPE.DOUBLE: 0.0,
	PB_DATA_TYPE.STRING: "",
	PB_DATA_TYPE.BYTES: [],
	PB_DATA_TYPE.MESSAGE: null,
	PB_DATA_TYPE.MAP: []
}

enum PB_TYPE {
	VARINT = 0,
	FIX64 = 1,
	LENGTHDEL = 2,
	STARTGROUP = 3,
	ENDGROUP = 4,
	FIX32 = 5,
	UNDEFINED = 8
}

enum PB_RULE {
	OPTIONAL = 0,
	REQUIRED = 1,
	REPEATED = 2,
	RESERVED = 3
}

enum PB_SERVICE_STATE {
	FILLED = 0,
	UNFILLED = 1
}

class PBField:
	func _init(a_name : String, a_type : int, a_rule : int, a_tag : int, packed : bool, a_value = null):
		name = a_name
		type = a_type
		rule = a_rule
		tag = a_tag
		option_packed = packed
		value = a_value
		
	var name : String
	var type : int
	var rule : int
	var tag : int
	var option_packed : bool
	var value
	var is_map_field : bool = false
	var option_default : bool = false

class PBTypeTag:
	var ok : bool = false
	var type : int
	var tag : int
	var offset : int

class PBServiceField:
	var field : PBField
	var func_ref = null
	var state : int = PB_SERVICE_STATE.UNFILLED

class PBPacker:
	static func convert_signed(n : int) -> int:
		if n < -2147483648:
			return (n << 1) ^ (n >> 63)
		else:
			return (n << 1) ^ (n >> 31)

	static func deconvert_signed(n : int) -> int:
		if n & 0x01:
			return ~(n >> 1)
		else:
			return (n >> 1)

	static func pack_varint(value) -> PackedByteArray:
		var varint : PackedByteArray = PackedByteArray()
		if typeof(value) == TYPE_BOOL:
			if value:
				value = 1
			else:
				value = 0
		for _i in range(9):
			var b = value & 0x7F
			value >>= 7
			if value:
				varint.append(b | 0x80)
			else:
				varint.append(b)
				break
		if varint.size() == 9 && varint[8] == 0xFF:
			varint.append(0x01)
		return varint

	static func pack_bytes(value, count : int, data_type : int) -> PackedByteArray:
		var bytes : PackedByteArray = PackedByteArray()
		if data_type == PB_DATA_TYPE.FLOAT:
			var spb : StreamPeerBuffer = StreamPeerBuffer.new()
			spb.put_float(value)
			bytes = spb.get_data_array()
		elif data_type == PB_DATA_TYPE.DOUBLE:
			var spb : StreamPeerBuffer = StreamPeerBuffer.new()
			spb.put_double(value)
			bytes = spb.get_data_array()
		else:
			for _i in range(count):
				bytes.append(value & 0xFF)
				value >>= 8
		return bytes

	static func unpack_bytes(bytes : PackedByteArray, index : int, count : int, data_type : int):
		var value = 0
		if data_type == PB_DATA_TYPE.FLOAT:
			var spb : StreamPeerBuffer = StreamPeerBuffer.new()
			for i in range(index, count + index):
				spb.put_u8(bytes[i])
			spb.seek(0)
			value = spb.get_float()
		elif data_type == PB_DATA_TYPE.DOUBLE:
			var spb : StreamPeerBuffer = StreamPeerBuffer.new()
			for i in range(index, count + index):
				spb.put_u8(bytes[i])
			spb.seek(0)
			value = spb.get_double()
		else:
			for i in range(index + count - 1, index - 1, -1):
				value |= (bytes[i] & 0xFF)
				if i != index:
					value <<= 8
		return value

	static func unpack_varint(varint_bytes) -> int:
		var value : int = 0
		for i in range(varint_bytes.size() - 1, -1, -1):
			value |= varint_bytes[i] & 0x7F
			if i != 0:
				value <<= 7
		return value

	static func pack_type_tag(type : int, tag : int) -> PackedByteArray:
		return pack_varint((tag << 3) | type)

	static func isolate_varint(bytes : PackedByteArray, index : int) -> PackedByteArray:
		var result : PackedByteArray = PackedByteArray()
		for i in range(index, bytes.size()):
			result.append(bytes[i])
			if !(bytes[i] & 0x80):
				break
		return result

	static func unpack_type_tag(bytes : PackedByteArray, index : int) -> PBTypeTag:
		var varint_bytes : PackedByteArray = isolate_varint(bytes, index)
		var result : PBTypeTag = PBTypeTag.new()
		if varint_bytes.size() != 0:
			result.ok = true
			result.offset = varint_bytes.size()
			var unpacked : int = unpack_varint(varint_bytes)
			result.type = unpacked & 0x07
			result.tag = unpacked >> 3
		return result

	static func pack_length_delimeted(type : int, tag : int, bytes : PackedByteArray) -> PackedByteArray:
		var result : PackedByteArray = pack_type_tag(type, tag)
		result.append_array(pack_varint(bytes.size()))
		result.append_array(bytes)
		return result

	static func pb_type_from_data_type(data_type : int) -> int:
		if data_type == PB_DATA_TYPE.INT32 || data_type == PB_DATA_TYPE.SINT32 || data_type == PB_DATA_TYPE.UINT32 || data_type == PB_DATA_TYPE.INT64 || data_type == PB_DATA_TYPE.SINT64 || data_type == PB_DATA_TYPE.UINT64 || data_type == PB_DATA_TYPE.BOOL || data_type == PB_DATA_TYPE.ENUM:
			return PB_TYPE.VARINT
		elif data_type == PB_DATA_TYPE.FIXED32 || data_type == PB_DATA_TYPE.SFIXED32 || data_type == PB_DATA_TYPE.FLOAT:
			return PB_TYPE.FIX32
		elif data_type == PB_DATA_TYPE.FIXED64 || data_type == PB_DATA_TYPE.SFIXED64 || data_type == PB_DATA_TYPE.DOUBLE:
			return PB_TYPE.FIX64
		elif data_type == PB_DATA_TYPE.STRING || data_type == PB_DATA_TYPE.BYTES || data_type == PB_DATA_TYPE.MESSAGE || data_type == PB_DATA_TYPE.MAP:
			return PB_TYPE.LENGTHDEL
		else:
			return PB_TYPE.UNDEFINED

	static func pack_field(field : PBField) -> PackedByteArray:
		var type : int = pb_type_from_data_type(field.type)
		var type_copy : int = type
		if field.rule == PB_RULE.REPEATED && field.option_packed:
			type = PB_TYPE.LENGTHDEL
		var head : PackedByteArray = pack_type_tag(type, field.tag)
		var data : PackedByteArray = PackedByteArray()
		if type == PB_TYPE.VARINT:
			var value
			if field.rule == PB_RULE.REPEATED:
				for v in field.value:
					data.append_array(head)
					if field.type == PB_DATA_TYPE.SINT32 || field.type == PB_DATA_TYPE.SINT64:
						value = convert_signed(v)
					else:
						value = v
					data.append_array(pack_varint(value))
				return data
			else:
				if field.type == PB_DATA_TYPE.SINT32 || field.type == PB_DATA_TYPE.SINT64:
					value = convert_signed(field.value)
				else:
					value = field.value
				data = pack_varint(value)
		elif type == PB_TYPE.FIX32:
			if field.rule == PB_RULE.REPEATED:
				for v in field.value:
					data.append_array(head)
					data.append_array(pack_bytes(v, 4, field.type))
				return data
			else:
				data.append_array(pack_bytes(field.value, 4, field.type))
		elif type == PB_TYPE.FIX64:
			if field.rule == PB_RULE.REPEATED:
				for v in field.value:
					data.append_array(head)
					data.append_array(pack_bytes(v, 8, field.type))
				return data
			else:
				data.append_array(pack_bytes(field.value, 8, field.type))
		elif type == PB_TYPE.LENGTHDEL:
			if field.rule == PB_RULE.REPEATED:
				if type_copy == PB_TYPE.VARINT:
					if field.type == PB_DATA_TYPE.SINT32 || field.type == PB_DATA_TYPE.SINT64:
						var signed_value : int
						for v in field.value:
							signed_value = convert_signed(v)
							data.append_array(pack_varint(signed_value))
					else:
						for v in field.value:
							data.append_array(pack_varint(v))
					return pack_length_delimeted(type, field.tag, data)
				elif type_copy == PB_TYPE.FIX32:
					for v in field.value:
						data.append_array(pack_bytes(v, 4, field.type))
					return pack_length_delimeted(type, field.tag, data)
				elif type_copy == PB_TYPE.FIX64:
					for v in field.value:
						data.append_array(pack_bytes(v, 8, field.type))
					return pack_length_delimeted(type, field.tag, data)
				elif field.type == PB_DATA_TYPE.STRING:
					for v in field.value:
						var obj = v.to_utf8_buffer()
						data.append_array(pack_length_delimeted(type, field.tag, obj))
					return data
				elif field.type == PB_DATA_TYPE.BYTES:
					for v in field.value:
						data.append_array(pack_length_delimeted(type, field.tag, v))
					return data
				elif typeof(field.value[0]) == TYPE_OBJECT:
					for v in field.value:
						var obj : PackedByteArray = v.to_bytes()
						data.append_array(pack_length_delimeted(type, field.tag, obj))
					return data
			else:
				if field.type == PB_DATA_TYPE.STRING:
					var str_bytes : PackedByteArray = field.value.to_utf8_buffer()
					if PROTO_VERSION == 2 || (PROTO_VERSION == 3 && str_bytes.size() > 0):
						data.append_array(str_bytes)
						return pack_length_delimeted(type, field.tag, data)
				if field.type == PB_DATA_TYPE.BYTES:
					if PROTO_VERSION == 2 || (PROTO_VERSION == 3 && field.value.size() > 0):
						data.append_array(field.value)
						return pack_length_delimeted(type, field.tag, data)
				elif typeof(field.value) == TYPE_OBJECT:
					var obj : PackedByteArray = field.value.to_bytes()
					if obj.size() > 0:
						data.append_array(obj)
					return pack_length_delimeted(type, field.tag, data)
				else:
					pass
		if data.size() > 0:
			head.append_array(data)
			return head
		else:
			return data

	static func unpack_field(bytes : PackedByteArray, offset : int, field : PBField, type : int, message_func_ref) -> int:
		if field.rule == PB_RULE.REPEATED && type != PB_TYPE.LENGTHDEL && field.option_packed:
			var count = isolate_varint(bytes, offset)
			if count.size() > 0:
				offset += count.size()
				count = unpack_varint(count)
				if type == PB_TYPE.VARINT:
					var val
					var counter = offset + count
					while offset < counter:
						val = isolate_varint(bytes, offset)
						if val.size() > 0:
							offset += val.size()
							val = unpack_varint(val)
							if field.type == PB_DATA_TYPE.SINT32 || field.type == PB_DATA_TYPE.SINT64:
								val = deconvert_signed(val)
							elif field.type == PB_DATA_TYPE.BOOL:
								if val:
									val = true
								else:
									val = false
							field.value.append(val)
						else:
							return PB_ERR.REPEATED_COUNT_MISMATCH
					return offset
				elif type == PB_TYPE.FIX32 || type == PB_TYPE.FIX64:
					var type_size
					if type == PB_TYPE.FIX32:
						type_size = 4
					else:
						type_size = 8
					var val
					var counter = offset + count
					while offset < counter:
						if (offset + type_size) > bytes.size():
							return PB_ERR.REPEATED_COUNT_MISMATCH
						val = unpack_bytes(bytes, offset, type_size, field.type)
						offset += type_size
						field.value.append(val)
					return offset
			else:
				return PB_ERR.REPEATED_COUNT_NOT_FOUND
		else:
			if type == PB_TYPE.VARINT:
				var val = isolate_varint(bytes, offset)
				if val.size() > 0:
					offset += val.size()
					val = unpack_varint(val)
					if field.type == PB_DATA_TYPE.SINT32 || field.type == PB_DATA_TYPE.SINT64:
						val = deconvert_signed(val)
					elif field.type == PB_DATA_TYPE.BOOL:
						if val:
							val = true
						else:
							val = false
					if field.rule == PB_RULE.REPEATED:
						field.value.append(val)
					else:
						field.value = val
				else:
					return PB_ERR.VARINT_NOT_FOUND
				return offset
			elif type == PB_TYPE.FIX32 || type == PB_TYPE.FIX64:
				var type_size
				if type == PB_TYPE.FIX32:
					type_size = 4
				else:
					type_size = 8
				var val
				if (offset + type_size) > bytes.size():
					return PB_ERR.REPEATED_COUNT_MISMATCH
				val = unpack_bytes(bytes, offset, type_size, field.type)
				offset += type_size
				if field.rule == PB_RULE.REPEATED:
					field.value.append(val)
				else:
					field.value = val
				return offset
			elif type == PB_TYPE.LENGTHDEL:
				var inner_size = isolate_varint(bytes, offset)
				if inner_size.size() > 0:
					offset += inner_size.size()
					inner_size = unpack_varint(inner_size)
					if inner_size >= 0:
						if inner_size + offset > bytes.size():
							return PB_ERR.LENGTHDEL_SIZE_MISMATCH
						if message_func_ref != null:
							var message = message_func_ref.call()
							if inner_size > 0:
								var sub_offset = message.from_bytes(bytes, offset, inner_size + offset)
								if sub_offset > 0:
									if sub_offset - offset >= inner_size:
										offset = sub_offset
										return offset
									else:
										return PB_ERR.LENGTHDEL_SIZE_MISMATCH
								return sub_offset
							else:
								return offset
						elif field.type == PB_DATA_TYPE.STRING:
							var str_bytes : PackedByteArray = PackedByteArray()
							for i in range(offset, inner_size + offset):
								str_bytes.append(bytes[i])
							if field.rule == PB_RULE.REPEATED:
								field.value.append(str_bytes.get_string_from_utf8())
							else:
								field.value = str_bytes.get_string_from_utf8()
							return offset + inner_size
						elif field.type == PB_DATA_TYPE.BYTES:
							var val_bytes : PackedByteArray = PackedByteArray()
							for i in range(offset, inner_size + offset):
								val_bytes.append(bytes[i])
							if field.rule == PB_RULE.REPEATED:
								field.value.append(val_bytes)
							else:
								field.value = val_bytes
							return offset + inner_size
					else:
						return PB_ERR.LENGTHDEL_SIZE_NOT_FOUND
				else:
					return PB_ERR.LENGTHDEL_SIZE_NOT_FOUND
		return PB_ERR.UNDEFINED_STATE

	static func unpack_message(data, bytes : PackedByteArray, offset : int, limit : int) -> int:
		while true:
			var tt : PBTypeTag = unpack_type_tag(bytes, offset)
			if tt.ok:
				offset += tt.offset
				if data.has(tt.tag):
					var service : PBServiceField = data[tt.tag]
					var type : int = pb_type_from_data_type(service.field.type)
					if type == tt.type || (tt.type == PB_TYPE.LENGTHDEL && service.field.rule == PB_RULE.REPEATED && service.field.option_packed):
						var res : int = unpack_field(bytes, offset, service.field, type, service.func_ref)
						if res > 0:
							service.state = PB_SERVICE_STATE.FILLED
							offset = res
							if offset == limit:
								return offset
							elif offset > limit:
								return PB_ERR.PACKAGE_SIZE_MISMATCH
						elif res < 0:
							return res
						else:
							break
			else:
				return offset
		return PB_ERR.UNDEFINED_STATE

	static func pack_message(data) -> PackedByteArray:
		var DEFAULT_VALUES
		if PROTO_VERSION == 2:
			DEFAULT_VALUES = DEFAULT_VALUES_2
		elif PROTO_VERSION == 3:
			DEFAULT_VALUES = DEFAULT_VALUES_3
		var result : PackedByteArray = PackedByteArray()
		var keys : Array = data.keys()
		keys.sort()
		for i in keys:
			if data[i].field.value != null:
				if data[i].state == PB_SERVICE_STATE.UNFILLED \
				&& !data[i].field.is_map_field \
				&& typeof(data[i].field.value) == typeof(DEFAULT_VALUES[data[i].field.type]) \
				&& data[i].field.value == DEFAULT_VALUES[data[i].field.type]:
					continue
				elif data[i].field.rule == PB_RULE.REPEATED && data[i].field.value.size() == 0:
					continue
				result.append_array(pack_field(data[i].field))
			elif data[i].field.rule == PB_RULE.REQUIRED:
				print("Error: required field is not filled: Tag:", data[i].field.tag)
				return PackedByteArray()
		return result

	static func check_required(data) -> bool:
		var keys : Array = data.keys()
		for i in keys:
			if data[i].field.rule == PB_RULE.REQUIRED && data[i].state == PB_SERVICE_STATE.UNFILLED:
				return false
		return true

	static func construct_map(key_values):
		var result = {}
		for kv in key_values:
			result[kv.get_key()] = kv.get_value()
		return result
	
	static func tabulate(text : String, nesting : int) -> String:
		var tab : String = ""
		for _i in range(nesting):
			tab += DEBUG_TAB
		return tab + text
	
	static func value_to_string(value, field : PBField, nesting : int) -> String:
		var result : String = ""
		var text : String
		if field.type == PB_DATA_TYPE.MESSAGE:
			result += "{"
			nesting += 1
			text = message_to_string(value.data, nesting)
			if text != "":
				result += "\n" + text
				nesting -= 1
				result += tabulate("}", nesting)
			else:
				nesting -= 1
				result += "}"
		elif field.type == PB_DATA_TYPE.BYTES:
			result += "<"
			for i in range(value.size()):
				result += str(value[i])
				if i != (value.size() - 1):
					result += ", "
			result += ">"
		elif field.type == PB_DATA_TYPE.STRING:
			result += "\"" + value + "\""
		elif field.type == PB_DATA_TYPE.ENUM:
			result += "ENUM::" + str(value)
		else:
			result += str(value)
		return result
	
	static func field_to_string(field : PBField, nesting : int) -> String:
		var result : String = tabulate(field.name + ": ", nesting)
		if field.type == PB_DATA_TYPE.MAP:
			if field.value.size() > 0:
				result += "(\n"
				nesting += 1
				for i in range(field.value.size()):
					var local_key_value = field.value[i].data[1].field
					result += tabulate(value_to_string(local_key_value.value, local_key_value, nesting), nesting) + ": "
					local_key_value = field.value[i].data[2].field
					result += value_to_string(local_key_value.value, local_key_value, nesting)
					if i != (field.value.size() - 1):
						result += ","
					result += "\n"
				nesting -= 1
				result += tabulate(")", nesting)
			else:
				result += "()"
		elif field.rule == PB_RULE.REPEATED:
			if field.value.size() > 0:
				result += "[\n"
				nesting += 1
				for i in range(field.value.size()):
					result += tabulate(str(i) + ": ", nesting)
					result += value_to_string(field.value[i], field, nesting)
					if i != (field.value.size() - 1):
						result += ","
					result += "\n"
				nesting -= 1
				result += tabulate("]", nesting)
			else:
				result += "[]"
		else:
			result += value_to_string(field.value, field, nesting)
		result += ";\n"
		return result
		
	static func message_to_string(data, nesting : int = 0) -> String:
		var DEFAULT_VALUES
		if PROTO_VERSION == 2:
			DEFAULT_VALUES = DEFAULT_VALUES_2
		elif PROTO_VERSION == 3:
			DEFAULT_VALUES = DEFAULT_VALUES_3
		var result : String = ""
		var keys : Array = data.keys()
		keys.sort()
		for i in keys:
			if data[i].field.value != null:
				if data[i].state == PB_SERVICE_STATE.UNFILLED \
				&& !data[i].field.is_map_field \
				&& typeof(data[i].field.value) == typeof(DEFAULT_VALUES[data[i].field.type]) \
				&& data[i].field.value == DEFAULT_VALUES[data[i].field.type]:
					continue
				elif data[i].field.rule == PB_RULE.REPEATED && data[i].field.value.size() == 0:
					continue
				result += field_to_string(data[i].field, nesting)
			elif data[i].field.rule == PB_RULE.REQUIRED:
				result += data[i].field.name + ": " + "error"
		return result



############### USER DATA BEGIN ################


enum NTFLevel {
	GeneralNTF = 0,
	UrgencyNTF = 1,
	NTMaintainNTF = 2,
	ServeStopNTF = 3,
	PraiseNTF = 4,
	STrumpetNTF = 5,
	MTrumpetNTF = 6,
	BTrumpetNTF = 7
}

enum Direct {
	Centre = 0,
	EAST = 1,
	South = 2,
	West = 3,
	North = 4,
	EASTSouth = 5,
	WestSouth = 6,
	EASTNorth = 7,
	WestNorth = 8
}

enum MJOperate {
	NULL = 0,
	Pass = 1,
	Chi = 2,
	Pong = 3,
	Gang = 4,
	MingGang = 5,
	AnGang = 6,
	BuHua = 7,
	Ting = 8,
	Hu = 9,
	ZiMo = 10
}

enum PHZOperate {
	PhzNull = 0,
	PhzTi = 1,
	PhzWei = 2,
	PhzHe = 3,
	PhzPao = 4,
	PhzPong = 5,
	PhzChi = 6
}

class TimeInfo:
	func _init():
		var service
		
		__timeStamp = PBField.new("timeStamp", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __timeStamp
		data[__timeStamp.tag] = service
		
		__waitTime = PBField.new("waitTime", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __waitTime
		data[__waitTime.tag] = service
		
		__outTime = PBField.new("outTime", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __outTime
		data[__outTime.tag] = service
		
		__totalTime = PBField.new("totalTime", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __totalTime
		data[__totalTime.tag] = service
		
	var data = {}
	
	var __timeStamp: PBField
	func get_timeStamp() -> int:
		return __timeStamp.value
	func clear_timeStamp() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__timeStamp.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_timeStamp(value : int) -> void:
		__timeStamp.value = value
	
	var __waitTime: PBField
	func get_waitTime() -> int:
		return __waitTime.value
	func clear_waitTime() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__waitTime.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_waitTime(value : int) -> void:
		__waitTime.value = value
	
	var __outTime: PBField
	func get_outTime() -> int:
		return __outTime.value
	func clear_outTime() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__outTime.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_outTime(value : int) -> void:
		__outTime.value = value
	
	var __totalTime: PBField
	func get_totalTime() -> int:
		return __totalTime.value
	func clear_totalTime() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__totalTime.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_totalTime(value : int) -> void:
		__totalTime.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class InningInfo:
	func _init():
		var service
		
		__gameID = PBField.new("gameID", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __gameID
		data[__gameID.tag] = service
		
		__gameName = PBField.new("gameName", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __gameName
		data[__gameName.tag] = service
		
		__number = PBField.new("number", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __number
		data[__number.tag] = service
		
		__winnerID = PBField.new("winnerID", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __winnerID
		data[__winnerID.tag] = service
		
		__loserID = PBField.new("loserID", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 5, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __loserID
		data[__loserID.tag] = service
		
		__payoff = PBField.new("payoff", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 6, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __payoff
		data[__payoff.tag] = service
		
		__timeStamp = PBField.new("timeStamp", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 7, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __timeStamp
		data[__timeStamp.tag] = service
		
		__result = PBField.new("result", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 8, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __result
		data[__result.tag] = service
		
	var data = {}
	
	var __gameID: PBField
	func get_gameID() -> int:
		return __gameID.value
	func clear_gameID() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__gameID.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_gameID(value : int) -> void:
		__gameID.value = value
	
	var __gameName: PBField
	func get_gameName() -> String:
		return __gameName.value
	func clear_gameName() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__gameName.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_gameName(value : String) -> void:
		__gameName.value = value
	
	var __number: PBField
	func get_number() -> String:
		return __number.value
	func clear_number() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__number.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_number(value : String) -> void:
		__number.value = value
	
	var __winnerID: PBField
	func get_winnerID() -> int:
		return __winnerID.value
	func clear_winnerID() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__winnerID.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_winnerID(value : int) -> void:
		__winnerID.value = value
	
	var __loserID: PBField
	func get_loserID() -> int:
		return __loserID.value
	func clear_loserID() -> void:
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__loserID.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_loserID(value : int) -> void:
		__loserID.value = value
	
	var __payoff: PBField
	func get_payoff() -> int:
		return __payoff.value
	func clear_payoff() -> void:
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__payoff.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_payoff(value : int) -> void:
		__payoff.value = value
	
	var __timeStamp: PBField
	func get_timeStamp() -> int:
		return __timeStamp.value
	func clear_timeStamp() -> void:
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__timeStamp.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_timeStamp(value : int) -> void:
		__timeStamp.value = value
	
	var __result: PBField
	func get_result() -> String:
		return __result.value
	func clear_result() -> void:
		data[8].state = PB_SERVICE_STATE.UNFILLED
		__result.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_result(value : String) -> void:
		__result.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class CardInfo:
	func _init():
		var service
		
		__cards = PBField.new("cards", PB_DATA_TYPE.BYTES, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.BYTES])
		service = PBServiceField.new()
		service.field = __cards
		data[__cards.tag] = service
		
		__cardType = PBField.new("cardType", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __cardType
		data[__cardType.tag] = service
		
		__cardValue = PBField.new("cardValue", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __cardValue
		data[__cardValue.tag] = service
		
	var data = {}
	
	var __cards: PBField
	func get_cards() -> PackedByteArray:
		return __cards.value
	func clear_cards() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__cards.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BYTES]
	func set_cards(value : PackedByteArray) -> void:
		__cards.value = value
	
	var __cardType: PBField
	func get_cardType() -> int:
		return __cardType.value
	func clear_cardType() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__cardType.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_cardType(value : int) -> void:
		__cardType.value = value
	
	var __cardValue: PBField
	func get_cardValue() -> int:
		return __cardValue.value
	func clear_cardValue() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__cardValue.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_cardValue(value : int) -> void:
		__cardValue.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class AreaInfo:
	func _init():
		var service
		
		__iD = PBField.new("iD", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __iD
		data[__iD.tag] = service
		
		__myGold = PBField.new("myGold", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __myGold
		data[__myGold.tag] = service
		
		__totalGold = PBField.new("totalGold", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __totalGold
		data[__totalGold.tag] = service
		
		__awardGold = PBField.new("awardGold", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __awardGold
		data[__awardGold.tag] = service
		
	var data = {}
	
	var __iD: PBField
	func get_iD() -> int:
		return __iD.value
	func clear_iD() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__iD.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_iD(value : int) -> void:
		__iD.value = value
	
	var __myGold: PBField
	func get_myGold() -> int:
		return __myGold.value
	func clear_myGold() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__myGold.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_myGold(value : int) -> void:
		__myGold.value = value
	
	var __totalGold: PBField
	func get_totalGold() -> int:
		return __totalGold.value
	func clear_totalGold() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__totalGold.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_totalGold(value : int) -> void:
		__totalGold.value = value
	
	var __awardGold: PBField
	func get_awardGold() -> int:
		return __awardGold.value
	func clear_awardGold() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__awardGold.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_awardGold(value : int) -> void:
		__awardGold.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class GameRecord:
	func _init():
		var service
		
		__cardInfo = PBField.new("cardInfo", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __cardInfo
		service.func_ref = Callable(self, "new_cardInfo")
		data[__cardInfo.tag] = service
		
		__isWon = PBField.new("isWon", PB_DATA_TYPE.BOOL, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL])
		service = PBServiceField.new()
		service.field = __isWon
		data[__isWon.tag] = service
		
	var data = {}
	
	var __cardInfo: PBField
	func get_cardInfo() -> CardInfo:
		return __cardInfo.value
	func clear_cardInfo() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__cardInfo.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_cardInfo() -> CardInfo:
		__cardInfo.value = CardInfo.new()
		return __cardInfo.value
	
	var __isWon: PBField
	func get_isWon() -> bool:
		return __isWon.value
	func clear_isWon() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__isWon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL]
	func set_isWon(value : bool) -> void:
		__isWon.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class GameRecordList:
	func _init():
		var service
		
		var __list_default: Array[GameRecord] = []
		__list = PBField.new("list", PB_DATA_TYPE.MESSAGE, PB_RULE.REPEATED, 1, true, __list_default)
		service = PBServiceField.new()
		service.field = __list
		service.func_ref = Callable(self, "add_list")
		data[__list.tag] = service
		
	var data = {}
	
	var __list: PBField
	func get_list() -> Array[GameRecord]:
		return __list.value
	func clear_list() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__list.value = []
	func add_list() -> GameRecord:
		var element = GameRecord.new()
		__list.value.append(element)
		return element
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class EnterGameReq:
	func _init():
		var service
		
		__gameID = PBField.new("gameID", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __gameID
		data[__gameID.tag] = service
		
		__password = PBField.new("password", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __password
		data[__password.tag] = service
		
		__chairNum = PBField.new("chairNum", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __chairNum
		data[__chairNum.tag] = service
		
		__token = PBField.new("token", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __token
		data[__token.tag] = service
		
	var data = {}
	
	var __gameID: PBField
	func get_gameID() -> int:
		return __gameID.value
	func clear_gameID() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__gameID.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_gameID(value : int) -> void:
		__gameID.value = value
	
	var __password: PBField
	func get_password() -> String:
		return __password.value
	func clear_password() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__password.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_password(value : String) -> void:
		__password.value = value
	
	var __chairNum: PBField
	func get_chairNum() -> int:
		return __chairNum.value
	func clear_chairNum() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__chairNum.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_chairNum(value : int) -> void:
		__chairNum.value = value
	
	var __token: PBField
	func get_token() -> String:
		return __token.value
	func clear_token() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__token.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_token(value : String) -> void:
		__token.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class EnterGameResp:
	func _init():
		var service
		
		__gameID = PBField.new("gameID", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __gameID
		data[__gameID.tag] = service
		
		__chairNum = PBField.new("chairNum", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __chairNum
		data[__chairNum.tag] = service
		
		__userInfo = PBField.new("userInfo", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __userInfo
		service.func_ref = Callable(self, "new_userInfo")
		data[__userInfo.tag] = service
		
	var data = {}
	
	var __gameID: PBField
	func get_gameID() -> int:
		return __gameID.value
	func clear_gameID() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__gameID.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_gameID(value : int) -> void:
		__gameID.value = value
	
	var __chairNum: PBField
	func get_chairNum() -> int:
		return __chairNum.value
	func clear_chairNum() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__chairNum.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_chairNum(value : int) -> void:
		__chairNum.value = value
	
	var __userInfo: PBField
	func get_userInfo() -> PlayerInfo:
		return __userInfo.value
	func clear_userInfo() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__userInfo.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_userInfo() -> PlayerInfo:
		__userInfo.value = PlayerInfo.new()
		return __userInfo.value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class ExitGameReq:
	func _init():
		var service
		
		__gameID = PBField.new("gameID", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __gameID
		data[__gameID.tag] = service
		
	var data = {}
	
	var __gameID: PBField
	func get_gameID() -> int:
		return __gameID.value
	func clear_gameID() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__gameID.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_gameID(value : int) -> void:
		__gameID.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class ExitGameResp:
	func _init():
		var service
		
		__gameID = PBField.new("gameID", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __gameID
		data[__gameID.tag] = service
		
		__userID = PBField.new("userID", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __userID
		data[__userID.tag] = service
		
	var data = {}
	
	var __gameID: PBField
	func get_gameID() -> int:
		return __gameID.value
	func clear_gameID() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__gameID.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_gameID(value : int) -> void:
		__gameID.value = value
	
	var __userID: PBField
	func get_userID() -> int:
		return __userID.value
	func clear_userID() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__userID.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_userID(value : int) -> void:
		__userID.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class DisbandedGameReq:
	func _init():
		var service
		
		__gameID = PBField.new("gameID", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __gameID
		data[__gameID.tag] = service
		
	var data = {}
	
	var __gameID: PBField
	func get_gameID() -> int:
		return __gameID.value
	func clear_gameID() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__gameID.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_gameID(value : int) -> void:
		__gameID.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class DisbandedGameResp:
	func _init():
		var service
		
		__gameID = PBField.new("gameID", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __gameID
		data[__gameID.tag] = service
		
		__userID = PBField.new("userID", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __userID
		data[__userID.tag] = service
		
	var data = {}
	
	var __gameID: PBField
	func get_gameID() -> int:
		return __gameID.value
	func clear_gameID() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__gameID.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_gameID(value : int) -> void:
		__gameID.value = value
	
	var __userID: PBField
	func get_userID() -> int:
		return __userID.value
	func clear_userID() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__userID.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_userID(value : int) -> void:
		__userID.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class ChangeTableReq:
	func _init():
		var service
		
		__gameID = PBField.new("gameID", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __gameID
		data[__gameID.tag] = service
		
	var data = {}
	
	var __gameID: PBField
	func get_gameID() -> int:
		return __gameID.value
	func clear_gameID() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__gameID.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_gameID(value : int) -> void:
		__gameID.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class ChangeTableResp:
	func _init():
		var service
		
		__gameID = PBField.new("gameID", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __gameID
		data[__gameID.tag] = service
		
		__tableNum = PBField.new("tableNum", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __tableNum
		data[__tableNum.tag] = service
		
		__userID = PBField.new("userID", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __userID
		data[__userID.tag] = service
		
	var data = {}
	
	var __gameID: PBField
	func get_gameID() -> int:
		return __gameID.value
	func clear_gameID() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__gameID.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_gameID(value : int) -> void:
		__gameID.value = value
	
	var __tableNum: PBField
	func get_tableNum() -> int:
		return __tableNum.value
	func clear_tableNum() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__tableNum.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_tableNum(value : int) -> void:
		__tableNum.value = value
	
	var __userID: PBField
	func get_userID() -> int:
		return __userID.value
	func clear_userID() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__userID.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_userID(value : int) -> void:
		__userID.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class GetBackPasswordReq:
	func _init():
		var service
		
		__gameID = PBField.new("gameID", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __gameID
		data[__gameID.tag] = service
		
	var data = {}
	
	var __gameID: PBField
	func get_gameID() -> int:
		return __gameID.value
	func clear_gameID() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__gameID.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_gameID(value : int) -> void:
		__gameID.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class GetBackPasswordResp:
	func _init():
		var service
		
		__gameID = PBField.new("gameID", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __gameID
		data[__gameID.tag] = service
		
		__password = PBField.new("password", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __password
		data[__password.tag] = service
		
	var data = {}
	
	var __gameID: PBField
	func get_gameID() -> int:
		return __gameID.value
	func clear_gameID() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__gameID.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_gameID(value : int) -> void:
		__gameID.value = value
	
	var __password: PBField
	func get_password() -> String:
		return __password.value
	func clear_password() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__password.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_password(value : String) -> void:
		__password.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class RankingListReq:
	func _init():
		var service
		
		__topCount = PBField.new("topCount", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __topCount
		data[__topCount.tag] = service
		
	var data = {}
	
	var __topCount: PBField
	func get_topCount() -> int:
		return __topCount.value
	func clear_topCount() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__topCount.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_topCount(value : int) -> void:
		__topCount.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class RankingListResp:
	func _init():
		var service
		
		__userInfo = PBField.new("userInfo", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __userInfo
		service.func_ref = Callable(self, "new_userInfo")
		data[__userInfo.tag] = service
		
	var data = {}
	
	var __userInfo: PBField
	func get_userInfo() -> PlayerInfo:
		return __userInfo.value
	func clear_userInfo() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__userInfo.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_userInfo() -> PlayerInfo:
		__userInfo.value = PlayerInfo.new()
		return __userInfo.value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class TrusteeReq:
	func _init():
		var service
		
		__isTrustee = PBField.new("isTrustee", PB_DATA_TYPE.BOOL, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL])
		service = PBServiceField.new()
		service.field = __isTrustee
		data[__isTrustee.tag] = service
		
	var data = {}
	
	var __isTrustee: PBField
	func get_isTrustee() -> bool:
		return __isTrustee.value
	func clear_isTrustee() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__isTrustee.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL]
	func set_isTrustee(value : bool) -> void:
		__isTrustee.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class TrusteeResp:
	func _init():
		var service
		
		__userID = PBField.new("userID", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __userID
		data[__userID.tag] = service
		
		__isTrustee = PBField.new("isTrustee", PB_DATA_TYPE.BOOL, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL])
		service = PBServiceField.new()
		service.field = __isTrustee
		data[__isTrustee.tag] = service
		
	var data = {}
	
	var __userID: PBField
	func get_userID() -> int:
		return __userID.value
	func clear_userID() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__userID.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_userID(value : int) -> void:
		__userID.value = value
	
	var __isTrustee: PBField
	func get_isTrustee() -> bool:
		return __isTrustee.value
	func clear_isTrustee() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__isTrustee.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL]
	func set_isTrustee(value : bool) -> void:
		__isTrustee.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class RollDiceReq:
	func _init():
		var service
		
		__diceCount = PBField.new("diceCount", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __diceCount
		data[__diceCount.tag] = service
		
	var data = {}
	
	var __diceCount: PBField
	func get_diceCount() -> int:
		return __diceCount.value
	func clear_diceCount() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__diceCount.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_diceCount(value : int) -> void:
		__diceCount.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class RollDiceResp:
	func _init():
		var service
		
		__userID = PBField.new("userID", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __userID
		data[__userID.tag] = service
		
		__diceCount = PBField.new("diceCount", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __diceCount
		data[__diceCount.tag] = service
		
		__dice = PBField.new("dice", PB_DATA_TYPE.BYTES, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.BYTES])
		service = PBServiceField.new()
		service.field = __dice
		data[__dice.tag] = service
		
	var data = {}
	
	var __userID: PBField
	func get_userID() -> int:
		return __userID.value
	func clear_userID() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__userID.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_userID(value : int) -> void:
		__userID.value = value
	
	var __diceCount: PBField
	func get_diceCount() -> int:
		return __diceCount.value
	func clear_diceCount() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__diceCount.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_diceCount(value : int) -> void:
		__diceCount.value = value
	
	var __dice: PBField
	func get_dice() -> PackedByteArray:
		return __dice.value
	func clear_dice() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__dice.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BYTES]
	func set_dice(value : PackedByteArray) -> void:
		__dice.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class GameOverReq:
	func _init():
		var service
		
		__gameID = PBField.new("gameID", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __gameID
		data[__gameID.tag] = service
		
	var data = {}
	
	var __gameID: PBField
	func get_gameID() -> int:
		return __gameID.value
	func clear_gameID() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__gameID.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_gameID(value : int) -> void:
		__gameID.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class GameOverResp:
	func _init():
		var service
		
		__gameID = PBField.new("gameID", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __gameID
		data[__gameID.tag] = service
		
		var __innings_default: Array[InningInfo] = []
		__innings = PBField.new("innings", PB_DATA_TYPE.MESSAGE, PB_RULE.REPEATED, 2, true, __innings_default)
		service = PBServiceField.new()
		service.field = __innings
		service.func_ref = Callable(self, "add_innings")
		data[__innings.tag] = service
		
		__pageNum = PBField.new("pageNum", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __pageNum
		data[__pageNum.tag] = service
		
	var data = {}
	
	var __gameID: PBField
	func get_gameID() -> int:
		return __gameID.value
	func clear_gameID() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__gameID.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_gameID(value : int) -> void:
		__gameID.value = value
	
	var __innings: PBField
	func get_innings() -> Array[InningInfo]:
		return __innings.value
	func clear_innings() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__innings.value = []
	func add_innings() -> InningInfo:
		var element = InningInfo.new()
		__innings.value.append(element)
		return element
	
	var __pageNum: PBField
	func get_pageNum() -> int:
		return __pageNum.value
	func clear_pageNum() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__pageNum.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_pageNum(value : int) -> void:
		__pageNum.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class UpdateGoldReq:
	func _init():
		pass
		
	var data = {}
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class UpdateGoldResp:
	func _init():
		var service
		
		__userID = PBField.new("userID", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __userID
		data[__userID.tag] = service
		
		__gold = PBField.new("gold", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __gold
		data[__gold.tag] = service
		
	var data = {}
	
	var __userID: PBField
	func get_userID() -> int:
		return __userID.value
	func clear_userID() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__userID.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_userID(value : int) -> void:
		__userID.value = value
	
	var __gold: PBField
	func get_gold() -> int:
		return __gold.value
	func clear_gold() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__gold.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_gold(value : int) -> void:
		__gold.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class GetRecordReq:
	func _init():
		var service
		
		__kindID = PBField.new("kindID", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __kindID
		data[__kindID.tag] = service
		
		__level = PBField.new("level", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __level
		data[__level.tag] = service
		
		__startTimeStamp = PBField.new("startTimeStamp", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __startTimeStamp
		data[__startTimeStamp.tag] = service
		
		__endTimeStamp = PBField.new("endTimeStamp", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __endTimeStamp
		data[__endTimeStamp.tag] = service
		
	var data = {}
	
	var __kindID: PBField
	func get_kindID() -> int:
		return __kindID.value
	func clear_kindID() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__kindID.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_kindID(value : int) -> void:
		__kindID.value = value
	
	var __level: PBField
	func get_level() -> int:
		return __level.value
	func clear_level() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__level.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_level(value : int) -> void:
		__level.value = value
	
	var __startTimeStamp: PBField
	func get_startTimeStamp() -> int:
		return __startTimeStamp.value
	func clear_startTimeStamp() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__startTimeStamp.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_startTimeStamp(value : int) -> void:
		__startTimeStamp.value = value
	
	var __endTimeStamp: PBField
	func get_endTimeStamp() -> int:
		return __endTimeStamp.value
	func clear_endTimeStamp() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__endTimeStamp.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_endTimeStamp(value : int) -> void:
		__endTimeStamp.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class GetRecordResp:
	func _init():
		var service
		
		__userID = PBField.new("userID", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __userID
		data[__userID.tag] = service
		
		__kindID = PBField.new("kindID", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __kindID
		data[__kindID.tag] = service
		
		__level = PBField.new("level", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __level
		data[__level.tag] = service
		
		__startTimeStamp = PBField.new("startTimeStamp", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __startTimeStamp
		data[__startTimeStamp.tag] = service
		
		__endTimeStamp = PBField.new("endTimeStamp", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 5, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __endTimeStamp
		data[__endTimeStamp.tag] = service
		
		var __innings_default: Array[InningInfo] = []
		__innings = PBField.new("innings", PB_DATA_TYPE.MESSAGE, PB_RULE.REPEATED, 6, true, __innings_default)
		service = PBServiceField.new()
		service.field = __innings
		service.func_ref = Callable(self, "add_innings")
		data[__innings.tag] = service
		
		__pageNum = PBField.new("pageNum", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 7, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __pageNum
		data[__pageNum.tag] = service
		
	var data = {}
	
	var __userID: PBField
	func get_userID() -> int:
		return __userID.value
	func clear_userID() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__userID.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_userID(value : int) -> void:
		__userID.value = value
	
	var __kindID: PBField
	func get_kindID() -> int:
		return __kindID.value
	func clear_kindID() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__kindID.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_kindID(value : int) -> void:
		__kindID.value = value
	
	var __level: PBField
	func get_level() -> int:
		return __level.value
	func clear_level() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__level.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_level(value : int) -> void:
		__level.value = value
	
	var __startTimeStamp: PBField
	func get_startTimeStamp() -> int:
		return __startTimeStamp.value
	func clear_startTimeStamp() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__startTimeStamp.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_startTimeStamp(value : int) -> void:
		__startTimeStamp.value = value
	
	var __endTimeStamp: PBField
	func get_endTimeStamp() -> int:
		return __endTimeStamp.value
	func clear_endTimeStamp() -> void:
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__endTimeStamp.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_endTimeStamp(value : int) -> void:
		__endTimeStamp.value = value
	
	var __innings: PBField
	func get_innings() -> Array[InningInfo]:
		return __innings.value
	func clear_innings() -> void:
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__innings.value = []
	func add_innings() -> InningInfo:
		var element = InningInfo.new()
		__innings.value.append(element)
		return element
	
	var __pageNum: PBField
	func get_pageNum() -> int:
		return __pageNum.value
	func clear_pageNum() -> void:
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__pageNum.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_pageNum(value : int) -> void:
		__pageNum.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class GetInningsInfoReq:
	func _init():
		var service
		
		__gameID = PBField.new("gameID", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __gameID
		data[__gameID.tag] = service
		
	var data = {}
	
	var __gameID: PBField
	func get_gameID() -> int:
		return __gameID.value
	func clear_gameID() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__gameID.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_gameID(value : int) -> void:
		__gameID.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class GetInningsInfoResp:
	func _init():
		var service
		
		__gameID = PBField.new("gameID", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __gameID
		data[__gameID.tag] = service
		
		var __innings_default: Array[InningInfo] = []
		__innings = PBField.new("innings", PB_DATA_TYPE.MESSAGE, PB_RULE.REPEATED, 2, true, __innings_default)
		service = PBServiceField.new()
		service.field = __innings
		service.func_ref = Callable(self, "add_innings")
		data[__innings.tag] = service
		
		__pageNum = PBField.new("pageNum", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __pageNum
		data[__pageNum.tag] = service
		
	var data = {}
	
	var __gameID: PBField
	func get_gameID() -> int:
		return __gameID.value
	func clear_gameID() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__gameID.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_gameID(value : int) -> void:
		__gameID.value = value
	
	var __innings: PBField
	func get_innings() -> Array[InningInfo]:
		return __innings.value
	func clear_innings() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__innings.value = []
	func add_innings() -> InningInfo:
		var element = InningInfo.new()
		__innings.value.append(element)
		return element
	
	var __pageNum: PBField
	func get_pageNum() -> int:
		return __pageNum.value
	func clear_pageNum() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__pageNum.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_pageNum(value : int) -> void:
		__pageNum.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class NotifyBeOut:
	func _init():
		var service
		
		__userID = PBField.new("userID", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __userID
		data[__userID.tag] = service
		
		__gameID = PBField.new("gameID", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __gameID
		data[__gameID.tag] = service
		
		__code = PBField.new("code", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __code
		data[__code.tag] = service
		
		__hints = PBField.new("hints", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __hints
		data[__hints.tag] = service
		
	var data = {}
	
	var __userID: PBField
	func get_userID() -> int:
		return __userID.value
	func clear_userID() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__userID.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_userID(value : int) -> void:
		__userID.value = value
	
	var __gameID: PBField
	func get_gameID() -> int:
		return __gameID.value
	func clear_gameID() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__gameID.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_gameID(value : int) -> void:
		__gameID.value = value
	
	var __code: PBField
	func get_code() -> int:
		return __code.value
	func clear_code() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__code.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_code(value : int) -> void:
		__code.value = value
	
	var __hints: PBField
	func get_hints() -> String:
		return __hints.value
	func clear_hints() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__hints.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_hints(value : String) -> void:
		__hints.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class NotifyBalanceChange:
	func _init():
		var service
		
		__userID = PBField.new("userID", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __userID
		data[__userID.tag] = service
		
		__yuanBao = PBField.new("yuanBao", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __yuanBao
		data[__yuanBao.tag] = service
		
		__alterYuanBao = PBField.new("alterYuanBao", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __alterYuanBao
		data[__alterYuanBao.tag] = service
		
		__coin = PBField.new("coin", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __coin
		data[__coin.tag] = service
		
		__alterCoin = PBField.new("alterCoin", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 5, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __alterCoin
		data[__alterCoin.tag] = service
		
		__code = PBField.new("code", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 6, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __code
		data[__code.tag] = service
		
		__reason = PBField.new("reason", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 7, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __reason
		data[__reason.tag] = service
		
	var data = {}
	
	var __userID: PBField
	func get_userID() -> int:
		return __userID.value
	func clear_userID() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__userID.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_userID(value : int) -> void:
		__userID.value = value
	
	var __yuanBao: PBField
	func get_yuanBao() -> int:
		return __yuanBao.value
	func clear_yuanBao() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__yuanBao.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_yuanBao(value : int) -> void:
		__yuanBao.value = value
	
	var __alterYuanBao: PBField
	func get_alterYuanBao() -> int:
		return __alterYuanBao.value
	func clear_alterYuanBao() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__alterYuanBao.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_alterYuanBao(value : int) -> void:
		__alterYuanBao.value = value
	
	var __coin: PBField
	func get_coin() -> int:
		return __coin.value
	func clear_coin() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__coin.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_coin(value : int) -> void:
		__coin.value = value
	
	var __alterCoin: PBField
	func get_alterCoin() -> int:
		return __alterCoin.value
	func clear_alterCoin() -> void:
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__alterCoin.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_alterCoin(value : int) -> void:
		__alterCoin.value = value
	
	var __code: PBField
	func get_code() -> int:
		return __code.value
	func clear_code() -> void:
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__code.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_code(value : int) -> void:
		__code.value = value
	
	var __reason: PBField
	func get_reason() -> String:
		return __reason.value
	func clear_reason() -> void:
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__reason.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_reason(value : String) -> void:
		__reason.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class NotifyNoticeReq:
	func _init():
		var service
		
		__gameID = PBField.new("gameID", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __gameID
		data[__gameID.tag] = service
		
		__title = PBField.new("title", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __title
		data[__title.tag] = service
		
		__content = PBField.new("content", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __content
		data[__content.tag] = service
		
		__level = PBField.new("level", PB_DATA_TYPE.ENUM, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.ENUM])
		service = PBServiceField.new()
		service.field = __level
		data[__level.tag] = service
		
		__timeout = PBField.new("timeout", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 5, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __timeout
		data[__timeout.tag] = service
		
	var data = {}
	
	var __gameID: PBField
	func get_gameID() -> int:
		return __gameID.value
	func clear_gameID() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__gameID.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_gameID(value : int) -> void:
		__gameID.value = value
	
	var __title: PBField
	func get_title() -> String:
		return __title.value
	func clear_title() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__title.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_title(value : String) -> void:
		__title.value = value
	
	var __content: PBField
	func get_content() -> String:
		return __content.value
	func clear_content() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__content.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_content(value : String) -> void:
		__content.value = value
	
	var __level: PBField
	func get_level():
		return __level.value
	func clear_level() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__level.value = DEFAULT_VALUES_3[PB_DATA_TYPE.ENUM]
	func set_level(value) -> void:
		__level.value = value
	
	var __timeout: PBField
	func get_timeout() -> int:
		return __timeout.value
	func clear_timeout() -> void:
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__timeout.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_timeout(value : int) -> void:
		__timeout.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class NotifyNoticeResp:
	func _init():
		var service
		
		__userID = PBField.new("userID", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __userID
		data[__userID.tag] = service
		
		__gameID = PBField.new("gameID", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __gameID
		data[__gameID.tag] = service
		
		__level = PBField.new("level", PB_DATA_TYPE.ENUM, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.ENUM])
		service = PBServiceField.new()
		service.field = __level
		data[__level.tag] = service
		
		__timeInfo = PBField.new("timeInfo", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __timeInfo
		service.func_ref = Callable(self, "new_timeInfo")
		data[__timeInfo.tag] = service
		
		__title = PBField.new("title", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 5, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __title
		data[__title.tag] = service
		
		__content = PBField.new("content", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 6, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __content
		data[__content.tag] = service
		
	var data = {}
	
	var __userID: PBField
	func get_userID() -> int:
		return __userID.value
	func clear_userID() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__userID.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_userID(value : int) -> void:
		__userID.value = value
	
	var __gameID: PBField
	func get_gameID() -> int:
		return __gameID.value
	func clear_gameID() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__gameID.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_gameID(value : int) -> void:
		__gameID.value = value
	
	var __level: PBField
	func get_level():
		return __level.value
	func clear_level() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__level.value = DEFAULT_VALUES_3[PB_DATA_TYPE.ENUM]
	func set_level(value) -> void:
		__level.value = value
	
	var __timeInfo: PBField
	func get_timeInfo() -> TimeInfo:
		return __timeInfo.value
	func clear_timeInfo() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__timeInfo.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_timeInfo() -> TimeInfo:
		__timeInfo.value = TimeInfo.new()
		return __timeInfo.value
	
	var __title: PBField
	func get_title() -> String:
		return __title.value
	func clear_title() -> void:
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__title.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_title(value : String) -> void:
		__title.value = value
	
	var __content: PBField
	func get_content() -> String:
		return __content.value
	func clear_content() -> void:
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__content.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_content(value : String) -> void:
		__content.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
enum PlayerState {
	PlayerLookOn = 0,
	PlayerSitDown = 1,
	PlayerAgree = 2,
	PlayerPlaying = 3,
	PlayerPickUp = 4,
	PlayerCall = 5,
	PlayerFollow = 6,
	PlayerRaise = 7,
	PlayerLook = 8,
	PlayerCompare = 9,
	PlayerCompareLose = 10,
	PlayerOutCard = 11,
	PlayerPass = 12,
	PlayerChi = 13,
	PlayerPong = 14,
	PlayerMingGang = 15,
	PlayerAnGang = 16,
	PlayerTing = 17,
	PlayerHu = 18,
	PlayerZiMo = 19,
	PlayerTrustee = 97,
	PlayerGiveUp = 98,
	PlayerStandUp = 99
}

class PlayerInfo:
	func _init():
		var service
		
		__userID = PBField.new("userID", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __userID
		data[__userID.tag] = service
		
		__account = PBField.new("account", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __account
		data[__account.tag] = service
		
		__name = PBField.new("name", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __name
		data[__name.tag] = service
		
		__faceID = PBField.new("faceID", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __faceID
		data[__faceID.tag] = service
		
		__age = PBField.new("age", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 5, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __age
		data[__age.tag] = service
		
		__sex = PBField.new("sex", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 6, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __sex
		data[__sex.tag] = service
		
		__yuanBao = PBField.new("yuanBao", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 7, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __yuanBao
		data[__yuanBao.tag] = service
		
		__coin = PBField.new("coin", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 8, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __coin
		data[__coin.tag] = service
		
		__level = PBField.new("level", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 9, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __level
		data[__level.tag] = service
		
		__ranking = PBField.new("ranking", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 10, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __ranking
		data[__ranking.tag] = service
		
		__state = PBField.new("state", PB_DATA_TYPE.ENUM, PB_RULE.OPTIONAL, 11, true, DEFAULT_VALUES_3[PB_DATA_TYPE.ENUM])
		service = PBServiceField.new()
		service.field = __state
		data[__state.tag] = service
		
		__gold = PBField.new("gold", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 12, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __gold
		data[__gold.tag] = service
		
		__money = PBField.new("money", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 13, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __money
		data[__money.tag] = service
		
		__bindInfo = PBField.new("bindInfo", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 14, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __bindInfo
		data[__bindInfo.tag] = service
		
		__gameState = PBField.new("gameState", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 15, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __gameState
		data[__gameState.tag] = service
		
		__platformID = PBField.new("platformID", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 16, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __platformID
		data[__platformID.tag] = service
		
		__roomNum = PBField.new("roomNum", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 17, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __roomNum
		data[__roomNum.tag] = service
		
		__gameID = PBField.new("gameID", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 18, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __gameID
		data[__gameID.tag] = service
		
		__tableID = PBField.new("tableID", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 19, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __tableID
		data[__tableID.tag] = service
		
		__chairID = PBField.new("chairID", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 20, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __chairID
		data[__chairID.tag] = service
		
	var data = {}
	
	var __userID: PBField
	func get_userID() -> int:
		return __userID.value
	func clear_userID() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__userID.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_userID(value : int) -> void:
		__userID.value = value
	
	var __account: PBField
	func get_account() -> String:
		return __account.value
	func clear_account() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__account.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_account(value : String) -> void:
		__account.value = value
	
	var __name: PBField
	func get_name() -> String:
		return __name.value
	func clear_name() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__name.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_name(value : String) -> void:
		__name.value = value
	
	var __faceID: PBField
	func get_faceID() -> int:
		return __faceID.value
	func clear_faceID() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__faceID.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_faceID(value : int) -> void:
		__faceID.value = value
	
	var __age: PBField
	func get_age() -> int:
		return __age.value
	func clear_age() -> void:
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__age.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_age(value : int) -> void:
		__age.value = value
	
	var __sex: PBField
	func get_sex() -> int:
		return __sex.value
	func clear_sex() -> void:
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__sex.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_sex(value : int) -> void:
		__sex.value = value
	
	var __yuanBao: PBField
	func get_yuanBao() -> int:
		return __yuanBao.value
	func clear_yuanBao() -> void:
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__yuanBao.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_yuanBao(value : int) -> void:
		__yuanBao.value = value
	
	var __coin: PBField
	func get_coin() -> int:
		return __coin.value
	func clear_coin() -> void:
		data[8].state = PB_SERVICE_STATE.UNFILLED
		__coin.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_coin(value : int) -> void:
		__coin.value = value
	
	var __level: PBField
	func get_level() -> int:
		return __level.value
	func clear_level() -> void:
		data[9].state = PB_SERVICE_STATE.UNFILLED
		__level.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_level(value : int) -> void:
		__level.value = value
	
	var __ranking: PBField
	func get_ranking() -> int:
		return __ranking.value
	func clear_ranking() -> void:
		data[10].state = PB_SERVICE_STATE.UNFILLED
		__ranking.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_ranking(value : int) -> void:
		__ranking.value = value
	
	var __state: PBField
	func get_state():
		return __state.value
	func clear_state() -> void:
		data[11].state = PB_SERVICE_STATE.UNFILLED
		__state.value = DEFAULT_VALUES_3[PB_DATA_TYPE.ENUM]
	func set_state(value) -> void:
		__state.value = value
	
	var __gold: PBField
	func get_gold() -> int:
		return __gold.value
	func clear_gold() -> void:
		data[12].state = PB_SERVICE_STATE.UNFILLED
		__gold.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_gold(value : int) -> void:
		__gold.value = value
	
	var __money: PBField
	func get_money() -> int:
		return __money.value
	func clear_money() -> void:
		data[13].state = PB_SERVICE_STATE.UNFILLED
		__money.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_money(value : int) -> void:
		__money.value = value
	
	var __bindInfo: PBField
	func get_bindInfo() -> String:
		return __bindInfo.value
	func clear_bindInfo() -> void:
		data[14].state = PB_SERVICE_STATE.UNFILLED
		__bindInfo.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_bindInfo(value : String) -> void:
		__bindInfo.value = value
	
	var __gameState: PBField
	func get_gameState() -> int:
		return __gameState.value
	func clear_gameState() -> void:
		data[15].state = PB_SERVICE_STATE.UNFILLED
		__gameState.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_gameState(value : int) -> void:
		__gameState.value = value
	
	var __platformID: PBField
	func get_platformID() -> int:
		return __platformID.value
	func clear_platformID() -> void:
		data[16].state = PB_SERVICE_STATE.UNFILLED
		__platformID.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_platformID(value : int) -> void:
		__platformID.value = value
	
	var __roomNum: PBField
	func get_roomNum() -> int:
		return __roomNum.value
	func clear_roomNum() -> void:
		data[17].state = PB_SERVICE_STATE.UNFILLED
		__roomNum.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_roomNum(value : int) -> void:
		__roomNum.value = value
	
	var __gameID: PBField
	func get_gameID() -> int:
		return __gameID.value
	func clear_gameID() -> void:
		data[18].state = PB_SERVICE_STATE.UNFILLED
		__gameID.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_gameID(value : int) -> void:
		__gameID.value = value
	
	var __tableID: PBField
	func get_tableID() -> int:
		return __tableID.value
	func clear_tableID() -> void:
		data[19].state = PB_SERVICE_STATE.UNFILLED
		__tableID.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_tableID(value : int) -> void:
		__tableID.value = value
	
	var __chairID: PBField
	func get_chairID() -> int:
		return __chairID.value
	func clear_chairID() -> void:
		data[20].state = PB_SERVICE_STATE.UNFILLED
		__chairID.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_chairID(value : int) -> void:
		__chairID.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class PlayerListInfo:
	func _init():
		var service
		
		var __allInfos_default: Array[PlayerInfo] = []
		__allInfos = PBField.new("allInfos", PB_DATA_TYPE.MESSAGE, PB_RULE.REPEATED, 1, true, __allInfos_default)
		service = PBServiceField.new()
		service.field = __allInfos
		service.func_ref = Callable(self, "add_allInfos")
		data[__allInfos.tag] = service
		
	var data = {}
	
	var __allInfos: PBField
	func get_allInfos() -> Array[PlayerInfo]:
		return __allInfos.value
	func clear_allInfos() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__allInfos.value = []
	func add_allInfos() -> PlayerInfo:
		var element = PlayerInfo.new()
		__allInfos.value.append(element)
		return element
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class PlayerRecord:
	func _init():
		var service
		
		__user = PBField.new("user", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __user
		service.func_ref = Callable(self, "new_user")
		data[__user.tag] = service
		
		__twice = PBField.new("twice", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __twice
		data[__twice.tag] = service
		
		__ranking = PBField.new("ranking", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __ranking
		data[__ranking.tag] = service
		
		__bankroll = PBField.new("bankroll", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __bankroll
		data[__bankroll.tag] = service
		
		__winLos = PBField.new("winLos", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 5, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __winLos
		data[__winLos.tag] = service
		
	var data = {}
	
	var __user: PBField
	func get_user() -> PlayerInfo:
		return __user.value
	func clear_user() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__user.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_user() -> PlayerInfo:
		__user.value = PlayerInfo.new()
		return __user.value
	
	var __twice: PBField
	func get_twice() -> int:
		return __twice.value
	func clear_twice() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__twice.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_twice(value : int) -> void:
		__twice.value = value
	
	var __ranking: PBField
	func get_ranking() -> int:
		return __ranking.value
	func clear_ranking() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__ranking.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_ranking(value : int) -> void:
		__ranking.value = value
	
	var __bankroll: PBField
	func get_bankroll() -> int:
		return __bankroll.value
	func clear_bankroll() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__bankroll.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_bankroll(value : int) -> void:
		__bankroll.value = value
	
	var __winLos: PBField
	func get_winLos() -> int:
		return __winLos.value
	func clear_winLos() -> void:
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__winLos.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_winLos(value : int) -> void:
		__winLos.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class UpdateMoneyReq:
	func _init():
		pass
		
	var data = {}
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class UpdateMoneyResp:
	func _init():
		var service
		
		__userID = PBField.new("userID", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __userID
		data[__userID.tag] = service
		
		__money = PBField.new("money", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __money
		data[__money.tag] = service
		
	var data = {}
	
	var __userID: PBField
	func get_userID() -> int:
		return __userID.value
	func clear_userID() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__userID.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_userID(value : int) -> void:
		__userID.value = value
	
	var __money: PBField
	func get_money() -> int:
		return __money.value
	func clear_money() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__money.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_money(value : int) -> void:
		__money.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
################ USER DATA END #################
