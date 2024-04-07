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
					var _service_  : PBServiceField = data[tt.tag]
					var type : int = pb_type_from_data_type(_service_ .field.type)
					if type == tt.type || (tt.type == PB_TYPE.LENGTHDEL && _service_ .field.rule == PB_RULE.REPEATED && _service_ .field.option_packed):
						var res : int = unpack_field(bytes, offset, _service_ .field, type, _service_ .func_ref)
						if res > 0:
							_service_ .state = PB_SERVICE_STATE.FILLED
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


enum HeroType {
	Hero_null = 0,
	JIN = 1,
	MU = 2,
	SHUI = 3,
	HUO = 4,
	TU = 5
}

enum GameScene {
	Free = 0,
	Start = 1,
	Playing = 2,
	Opening = 3,
	Over = 4,
	Closing = 5
}

class UserInfo:
	func _init():
		var service
		
		__UserID = PBField.new("UserID", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __UserID
		data[__UserID.tag] = service
		
		__Name = PBField.new("Name", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __Name
		data[__Name.tag] = service
		
		__Account = PBField.new("Account", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __Account
		data[__Account.tag] = service
		
		__Password = PBField.new("Password", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __Password
		data[__Password.tag] = service
		
		__FaceID = PBField.new("FaceID", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 5, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __FaceID
		data[__FaceID.tag] = service
		
		__Gender = PBField.new("Gender", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 6, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __Gender
		data[__Gender.tag] = service
		
		__Age = PBField.new("Age", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 7, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __Age
		data[__Age.tag] = service
		
		__VIP = PBField.new("VIP", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 8, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __VIP
		data[__VIP.tag] = service
		
		__Level = PBField.new("Level", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 9, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __Level
		data[__Level.tag] = service
		
		__YuanBao = PBField.new("YuanBao", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 10, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __YuanBao
		data[__YuanBao.tag] = service
		
		__Coin = PBField.new("Coin", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 11, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __Coin
		data[__Coin.tag] = service
		
		__Money = PBField.new("Money", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 12, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __Money
		data[__Money.tag] = service
		
		__PassPortID = PBField.new("PassPortID", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 13, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __PassPortID
		data[__PassPortID.tag] = service
		
		__RealName = PBField.new("RealName", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 14, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __RealName
		data[__RealName.tag] = service
		
		__PhoneNum = PBField.new("PhoneNum", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 15, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __PhoneNum
		data[__PhoneNum.tag] = service
		
		__Email = PBField.new("Email", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 16, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __Email
		data[__Email.tag] = service
		
		__Address = PBField.new("Address", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 17, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __Address
		data[__Address.tag] = service
		
		__IDentity = PBField.new("IDentity", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 18, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __IDentity
		data[__IDentity.tag] = service
		
		__AgentID = PBField.new("AgentID", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 19, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __AgentID
		data[__AgentID.tag] = service
		
		__ReferralCode = PBField.new("ReferralCode", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 20, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __ReferralCode
		data[__ReferralCode.tag] = service
		
		__ClientAddr = PBField.new("ClientAddr", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 21, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __ClientAddr
		data[__ClientAddr.tag] = service
		
		__ServerAddr = PBField.new("ServerAddr", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 22, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __ServerAddr
		data[__ServerAddr.tag] = service
		
		__MachineCode = PBField.new("MachineCode", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 23, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __MachineCode
		data[__MachineCode.tag] = service
		
	var data = {}
	
	var __UserID: PBField
	func get_UserID() -> int:
		return __UserID.value
	func clear_UserID() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__UserID.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_UserID(value : int) -> void:
		__UserID.value = value
	
	var __Name: PBField
	func get_Name() -> String:
		return __Name.value
	func clear_Name() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__Name.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_Name(value : String) -> void:
		__Name.value = value
	
	var __Account: PBField
	func get_Account() -> String:
		return __Account.value
	func clear_Account() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__Account.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_Account(value : String) -> void:
		__Account.value = value
	
	var __Password: PBField
	func get_Password() -> String:
		return __Password.value
	func clear_Password() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__Password.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_Password(value : String) -> void:
		__Password.value = value
	
	var __FaceID: PBField
	func get_FaceID() -> int:
		return __FaceID.value
	func clear_FaceID() -> void:
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__FaceID.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_FaceID(value : int) -> void:
		__FaceID.value = value
	
	var __Gender: PBField
	func get_Gender() -> int:
		return __Gender.value
	func clear_Gender() -> void:
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__Gender.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_Gender(value : int) -> void:
		__Gender.value = value
	
	var __Age: PBField
	func get_Age() -> int:
		return __Age.value
	func clear_Age() -> void:
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__Age.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_Age(value : int) -> void:
		__Age.value = value
	
	var __VIP: PBField
	func get_VIP() -> int:
		return __VIP.value
	func clear_VIP() -> void:
		data[8].state = PB_SERVICE_STATE.UNFILLED
		__VIP.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_VIP(value : int) -> void:
		__VIP.value = value
	
	var __Level: PBField
	func get_Level() -> int:
		return __Level.value
	func clear_Level() -> void:
		data[9].state = PB_SERVICE_STATE.UNFILLED
		__Level.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_Level(value : int) -> void:
		__Level.value = value
	
	var __YuanBao: PBField
	func get_YuanBao() -> int:
		return __YuanBao.value
	func clear_YuanBao() -> void:
		data[10].state = PB_SERVICE_STATE.UNFILLED
		__YuanBao.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_YuanBao(value : int) -> void:
		__YuanBao.value = value
	
	var __Coin: PBField
	func get_Coin() -> int:
		return __Coin.value
	func clear_Coin() -> void:
		data[11].state = PB_SERVICE_STATE.UNFILLED
		__Coin.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_Coin(value : int) -> void:
		__Coin.value = value
	
	var __Money: PBField
	func get_Money() -> int:
		return __Money.value
	func clear_Money() -> void:
		data[12].state = PB_SERVICE_STATE.UNFILLED
		__Money.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_Money(value : int) -> void:
		__Money.value = value
	
	var __PassPortID: PBField
	func get_PassPortID() -> String:
		return __PassPortID.value
	func clear_PassPortID() -> void:
		data[13].state = PB_SERVICE_STATE.UNFILLED
		__PassPortID.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_PassPortID(value : String) -> void:
		__PassPortID.value = value
	
	var __RealName: PBField
	func get_RealName() -> String:
		return __RealName.value
	func clear_RealName() -> void:
		data[14].state = PB_SERVICE_STATE.UNFILLED
		__RealName.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_RealName(value : String) -> void:
		__RealName.value = value
	
	var __PhoneNum: PBField
	func get_PhoneNum() -> String:
		return __PhoneNum.value
	func clear_PhoneNum() -> void:
		data[15].state = PB_SERVICE_STATE.UNFILLED
		__PhoneNum.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_PhoneNum(value : String) -> void:
		__PhoneNum.value = value
	
	var __Email: PBField
	func get_Email() -> String:
		return __Email.value
	func clear_Email() -> void:
		data[16].state = PB_SERVICE_STATE.UNFILLED
		__Email.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_Email(value : String) -> void:
		__Email.value = value
	
	var __Address: PBField
	func get_Address() -> String:
		return __Address.value
	func clear_Address() -> void:
		data[17].state = PB_SERVICE_STATE.UNFILLED
		__Address.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_Address(value : String) -> void:
		__Address.value = value
	
	var __IDentity: PBField
	func get_IDentity() -> String:
		return __IDentity.value
	func clear_IDentity() -> void:
		data[18].state = PB_SERVICE_STATE.UNFILLED
		__IDentity.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_IDentity(value : String) -> void:
		__IDentity.value = value
	
	var __AgentID: PBField
	func get_AgentID() -> int:
		return __AgentID.value
	func clear_AgentID() -> void:
		data[19].state = PB_SERVICE_STATE.UNFILLED
		__AgentID.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_AgentID(value : int) -> void:
		__AgentID.value = value
	
	var __ReferralCode: PBField
	func get_ReferralCode() -> String:
		return __ReferralCode.value
	func clear_ReferralCode() -> void:
		data[20].state = PB_SERVICE_STATE.UNFILLED
		__ReferralCode.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_ReferralCode(value : String) -> void:
		__ReferralCode.value = value
	
	var __ClientAddr: PBField
	func get_ClientAddr() -> String:
		return __ClientAddr.value
	func clear_ClientAddr() -> void:
		data[21].state = PB_SERVICE_STATE.UNFILLED
		__ClientAddr.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_ClientAddr(value : String) -> void:
		__ClientAddr.value = value
	
	var __ServerAddr: PBField
	func get_ServerAddr() -> String:
		return __ServerAddr.value
	func clear_ServerAddr() -> void:
		data[22].state = PB_SERVICE_STATE.UNFILLED
		__ServerAddr.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_ServerAddr(value : String) -> void:
		__ServerAddr.value = value
	
	var __MachineCode: PBField
	func get_MachineCode() -> String:
		return __MachineCode.value
	func clear_MachineCode() -> void:
		data[23].state = PB_SERVICE_STATE.UNFILLED
		__MachineCode.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_MachineCode(value : String) -> void:
		__MachineCode.value = value
	
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
	
class HeroInfo:
	func _init():
		var service
		
		__ID = PBField.new("ID", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __ID
		data[__ID.tag] = service
		
		__HeadId = PBField.new("HeadId", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __HeadId
		data[__HeadId.tag] = service
		
		__Name = PBField.new("Name", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __Name
		data[__Name.tag] = service
		
		__Sex = PBField.new("Sex", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __Sex
		data[__Sex.tag] = service
		
		__Rarity = PBField.new("Rarity", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 5, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __Rarity
		data[__Rarity.tag] = service
		
		__Faction = PBField.new("Faction", PB_DATA_TYPE.ENUM, PB_RULE.OPTIONAL, 6, true, DEFAULT_VALUES_3[PB_DATA_TYPE.ENUM])
		service = PBServiceField.new()
		service.field = __Faction
		data[__Faction.tag] = service
		
		__HealthPoint = PBField.new("HealthPoint", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 7, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __HealthPoint
		data[__HealthPoint.tag] = service
		
		__HealthPointFull = PBField.new("HealthPointFull", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 8, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __HealthPointFull
		data[__HealthPointFull.tag] = service
		
		__Strength = PBField.new("Strength", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 9, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __Strength
		data[__Strength.tag] = service
		
		__Agility = PBField.new("Agility", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 10, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __Agility
		data[__Agility.tag] = service
		
		__Intelligence = PBField.new("Intelligence", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 11, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __Intelligence
		data[__Intelligence.tag] = service
		
		__AttackPoint = PBField.new("AttackPoint", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 12, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __AttackPoint
		data[__AttackPoint.tag] = service
		
		__ArmorPoint = PBField.new("ArmorPoint", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 13, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __ArmorPoint
		data[__ArmorPoint.tag] = service
		
		__SpellPower = PBField.new("SpellPower", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 14, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __SpellPower
		data[__SpellPower.tag] = service
		
		var __Skills_default: Array[int] = []
		__Skills = PBField.new("Skills", PB_DATA_TYPE.INT64, PB_RULE.REPEATED, 15, true, __Skills_default)
		service = PBServiceField.new()
		service.field = __Skills
		data[__Skills.tag] = service
		
	var data = {}
	
	var __ID: PBField
	func get_ID() -> int:
		return __ID.value
	func clear_ID() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__ID.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_ID(value : int) -> void:
		__ID.value = value
	
	var __HeadId: PBField
	func get_HeadId() -> int:
		return __HeadId.value
	func clear_HeadId() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__HeadId.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_HeadId(value : int) -> void:
		__HeadId.value = value
	
	var __Name: PBField
	func get_Name() -> String:
		return __Name.value
	func clear_Name() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__Name.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_Name(value : String) -> void:
		__Name.value = value
	
	var __Sex: PBField
	func get_Sex() -> int:
		return __Sex.value
	func clear_Sex() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__Sex.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_Sex(value : int) -> void:
		__Sex.value = value
	
	var __Rarity: PBField
	func get_Rarity() -> int:
		return __Rarity.value
	func clear_Rarity() -> void:
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__Rarity.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_Rarity(value : int) -> void:
		__Rarity.value = value
	
	var __Faction: PBField
	func get_Faction():
		return __Faction.value
	func clear_Faction() -> void:
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__Faction.value = DEFAULT_VALUES_3[PB_DATA_TYPE.ENUM]
	func set_Faction(value) -> void:
		__Faction.value = value
	
	var __HealthPoint: PBField
	func get_HealthPoint() -> int:
		return __HealthPoint.value
	func clear_HealthPoint() -> void:
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__HealthPoint.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_HealthPoint(value : int) -> void:
		__HealthPoint.value = value
	
	var __HealthPointFull: PBField
	func get_HealthPointFull() -> int:
		return __HealthPointFull.value
	func clear_HealthPointFull() -> void:
		data[8].state = PB_SERVICE_STATE.UNFILLED
		__HealthPointFull.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_HealthPointFull(value : int) -> void:
		__HealthPointFull.value = value
	
	var __Strength: PBField
	func get_Strength() -> int:
		return __Strength.value
	func clear_Strength() -> void:
		data[9].state = PB_SERVICE_STATE.UNFILLED
		__Strength.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_Strength(value : int) -> void:
		__Strength.value = value
	
	var __Agility: PBField
	func get_Agility() -> int:
		return __Agility.value
	func clear_Agility() -> void:
		data[10].state = PB_SERVICE_STATE.UNFILLED
		__Agility.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_Agility(value : int) -> void:
		__Agility.value = value
	
	var __Intelligence: PBField
	func get_Intelligence() -> int:
		return __Intelligence.value
	func clear_Intelligence() -> void:
		data[11].state = PB_SERVICE_STATE.UNFILLED
		__Intelligence.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_Intelligence(value : int) -> void:
		__Intelligence.value = value
	
	var __AttackPoint: PBField
	func get_AttackPoint() -> int:
		return __AttackPoint.value
	func clear_AttackPoint() -> void:
		data[12].state = PB_SERVICE_STATE.UNFILLED
		__AttackPoint.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_AttackPoint(value : int) -> void:
		__AttackPoint.value = value
	
	var __ArmorPoint: PBField
	func get_ArmorPoint() -> int:
		return __ArmorPoint.value
	func clear_ArmorPoint() -> void:
		data[13].state = PB_SERVICE_STATE.UNFILLED
		__ArmorPoint.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_ArmorPoint(value : int) -> void:
		__ArmorPoint.value = value
	
	var __SpellPower: PBField
	func get_SpellPower() -> int:
		return __SpellPower.value
	func clear_SpellPower() -> void:
		data[14].state = PB_SERVICE_STATE.UNFILLED
		__SpellPower.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_SpellPower(value : int) -> void:
		__SpellPower.value = value
	
	var __Skills: PBField
	func get_Skills() -> Array[int]:
		return __Skills.value
	func clear_Skills() -> void:
		data[15].state = PB_SERVICE_STATE.UNFILLED
		__Skills.value = []
	func add_Skills(value : int) -> void:
		__Skills.value.append(value)
	
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
	
class WeaponInfo:
	func _init():
		var service
		
		__ID = PBField.new("ID", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __ID
		data[__ID.tag] = service
		
		__Name = PBField.new("Name", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __Name
		data[__Name.tag] = service
		
		__Type = PBField.new("Type", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __Type
		data[__Type.tag] = service
		
		__Level = PBField.new("Level", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __Level
		data[__Level.tag] = service
		
		__Damage = PBField.new("Damage", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 5, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __Damage
		data[__Damage.tag] = service
		
		__Prob = PBField.new("Prob", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 6, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __Prob
		data[__Prob.tag] = service
		
		__Count = PBField.new("Count", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 7, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __Count
		data[__Count.tag] = service
		
	var data = {}
	
	var __ID: PBField
	func get_ID() -> int:
		return __ID.value
	func clear_ID() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__ID.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_ID(value : int) -> void:
		__ID.value = value
	
	var __Name: PBField
	func get_Name() -> String:
		return __Name.value
	func clear_Name() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__Name.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_Name(value : String) -> void:
		__Name.value = value
	
	var __Type: PBField
	func get_Type() -> int:
		return __Type.value
	func clear_Type() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__Type.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_Type(value : int) -> void:
		__Type.value = value
	
	var __Level: PBField
	func get_Level() -> int:
		return __Level.value
	func clear_Level() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__Level.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_Level(value : int) -> void:
		__Level.value = value
	
	var __Damage: PBField
	func get_Damage() -> int:
		return __Damage.value
	func clear_Damage() -> void:
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__Damage.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_Damage(value : int) -> void:
		__Damage.value = value
	
	var __Prob: PBField
	func get_Prob() -> int:
		return __Prob.value
	func clear_Prob() -> void:
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__Prob.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_Prob(value : int) -> void:
		__Prob.value = value
	
	var __Count: PBField
	func get_Count() -> int:
		return __Count.value
	func clear_Count() -> void:
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__Count.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_Count(value : int) -> void:
		__Count.value = value
	
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
	
class GoodsInfo:
	func _init():
		var service
		
		__ID = PBField.new("ID", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __ID
		data[__ID.tag] = service
		
		__Name = PBField.new("Name", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __Name
		data[__Name.tag] = service
		
		__Kind = PBField.new("Kind", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __Kind
		data[__Kind.tag] = service
		
		__Level = PBField.new("Level", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __Level
		data[__Level.tag] = service
		
		__Price = PBField.new("Price", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 5, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __Price
		data[__Price.tag] = service
		
		__Store = PBField.new("Store", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 6, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __Store
		data[__Store.tag] = service
		
		__Sold = PBField.new("Sold", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 7, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __Sold
		data[__Sold.tag] = service
		
		__Amount = PBField.new("Amount", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 8, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __Amount
		data[__Amount.tag] = service
		
	var data = {}
	
	var __ID: PBField
	func get_ID() -> int:
		return __ID.value
	func clear_ID() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__ID.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_ID(value : int) -> void:
		__ID.value = value
	
	var __Name: PBField
	func get_Name() -> String:
		return __Name.value
	func clear_Name() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__Name.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_Name(value : String) -> void:
		__Name.value = value
	
	var __Kind: PBField
	func get_Kind() -> int:
		return __Kind.value
	func clear_Kind() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__Kind.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_Kind(value : int) -> void:
		__Kind.value = value
	
	var __Level: PBField
	func get_Level() -> int:
		return __Level.value
	func clear_Level() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__Level.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_Level(value : int) -> void:
		__Level.value = value
	
	var __Price: PBField
	func get_Price() -> int:
		return __Price.value
	func clear_Price() -> void:
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__Price.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_Price(value : int) -> void:
		__Price.value = value
	
	var __Store: PBField
	func get_Store() -> int:
		return __Store.value
	func clear_Store() -> void:
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__Store.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_Store(value : int) -> void:
		__Store.value = value
	
	var __Sold: PBField
	func get_Sold() -> int:
		return __Sold.value
	func clear_Sold() -> void:
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__Sold.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_Sold(value : int) -> void:
		__Sold.value = value
	
	var __Amount: PBField
	func get_Amount() -> int:
		return __Amount.value
	func clear_Amount() -> void:
		data[8].state = PB_SERVICE_STATE.UNFILLED
		__Amount.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_Amount(value : int) -> void:
		__Amount.value = value
	
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
	
class GoodsList:
	func _init():
		var service
		
		var __AllGoods_default: Array[GoodsInfo] = []
		__AllGoods = PBField.new("AllGoods", PB_DATA_TYPE.MESSAGE, PB_RULE.REPEATED, 1, true, __AllGoods_default)
		service = PBServiceField.new()
		service.field = __AllGoods
		service.func_ref = Callable(self, "add_AllGoods")
		data[__AllGoods.tag] = service
		
	var data = {}
	
	var __AllGoods: PBField
	func get_AllGoods() -> Array[GoodsInfo]:
		return __AllGoods.value
	func clear_AllGoods() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__AllGoods.value = []
	func add_AllGoods() -> GoodsInfo:
		var element = GoodsInfo.new()
		__AllGoods.value.append(element)
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
	
class KnapsackInfo:
	func _init():
		var service
		
		__ID = PBField.new("ID", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __ID
		data[__ID.tag] = service
		
		__Name = PBField.new("Name", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __Name
		data[__Name.tag] = service
		
		var __MyWeaponry_default: Array[WeaponInfo] = []
		__MyWeaponry = PBField.new("MyWeaponry", PB_DATA_TYPE.MESSAGE, PB_RULE.REPEATED, 3, true, __MyWeaponry_default)
		service = PBServiceField.new()
		service.field = __MyWeaponry
		service.func_ref = Callable(self, "add_MyWeaponry")
		data[__MyWeaponry.tag] = service
		
		var __MyGoods_default: Array[GoodsInfo] = []
		__MyGoods = PBField.new("MyGoods", PB_DATA_TYPE.MESSAGE, PB_RULE.REPEATED, 4, true, __MyGoods_default)
		service = PBServiceField.new()
		service.field = __MyGoods
		service.func_ref = Callable(self, "add_MyGoods")
		data[__MyGoods.tag] = service
		
		var __MyHeroList_default: Array[HeroInfo] = []
		__MyHeroList = PBField.new("MyHeroList", PB_DATA_TYPE.MESSAGE, PB_RULE.REPEATED, 5, true, __MyHeroList_default)
		service = PBServiceField.new()
		service.field = __MyHeroList
		service.func_ref = Callable(self, "add_MyHeroList")
		data[__MyHeroList.tag] = service
		
		__Number = PBField.new("Number", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 6, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __Number
		data[__Number.tag] = service
		
	var data = {}
	
	var __ID: PBField
	func get_ID() -> int:
		return __ID.value
	func clear_ID() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__ID.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_ID(value : int) -> void:
		__ID.value = value
	
	var __Name: PBField
	func get_Name() -> String:
		return __Name.value
	func clear_Name() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__Name.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_Name(value : String) -> void:
		__Name.value = value
	
	var __MyWeaponry: PBField
	func get_MyWeaponry() -> Array[WeaponInfo]:
		return __MyWeaponry.value
	func clear_MyWeaponry() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__MyWeaponry.value = []
	func add_MyWeaponry() -> WeaponInfo:
		var element = WeaponInfo.new()
		__MyWeaponry.value.append(element)
		return element
	
	var __MyGoods: PBField
	func get_MyGoods() -> Array[GoodsInfo]:
		return __MyGoods.value
	func clear_MyGoods() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__MyGoods.value = []
	func add_MyGoods() -> GoodsInfo:
		var element = GoodsInfo.new()
		__MyGoods.value.append(element)
		return element
	
	var __MyHeroList: PBField
	func get_MyHeroList() -> Array[HeroInfo]:
		return __MyHeroList.value
	func clear_MyHeroList() -> void:
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__MyHeroList.value = []
	func add_MyHeroList() -> HeroInfo:
		var element = HeroInfo.new()
		__MyHeroList.value.append(element)
		return element
	
	var __Number: PBField
	func get_Number() -> int:
		return __Number.value
	func clear_Number() -> void:
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__Number.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_Number(value : int) -> void:
		__Number.value = value
	
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
	
class EmailInfo:
	func _init():
		var service
		
		__EmailID = PBField.new("EmailID", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __EmailID
		data[__EmailID.tag] = service
		
		__AcceptName = PBField.new("AcceptName", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __AcceptName
		data[__AcceptName.tag] = service
		
		__Sender = PBField.new("Sender", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __Sender
		data[__Sender.tag] = service
		
		__Cc = PBField.new("Cc", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __Cc
		data[__Cc.tag] = service
		
		__Topic = PBField.new("Topic", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 5, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __Topic
		data[__Topic.tag] = service
		
		__Content = PBField.new("Content", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 6, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __Content
		data[__Content.tag] = service
		
		__IsRead = PBField.new("IsRead", PB_DATA_TYPE.BOOL, PB_RULE.OPTIONAL, 7, true, DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL])
		service = PBServiceField.new()
		service.field = __IsRead
		data[__IsRead.tag] = service
		
		__AwardList = PBField.new("AwardList", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 8, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __AwardList
		service.func_ref = Callable(self, "new_AwardList")
		data[__AwardList.tag] = service
		
		__TimeStamp = PBField.new("TimeStamp", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 9, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __TimeStamp
		data[__TimeStamp.tag] = service
		
	var data = {}
	
	var __EmailID: PBField
	func get_EmailID() -> int:
		return __EmailID.value
	func clear_EmailID() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__EmailID.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_EmailID(value : int) -> void:
		__EmailID.value = value
	
	var __AcceptName: PBField
	func get_AcceptName() -> String:
		return __AcceptName.value
	func clear_AcceptName() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__AcceptName.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_AcceptName(value : String) -> void:
		__AcceptName.value = value
	
	var __Sender: PBField
	func get_Sender() -> String:
		return __Sender.value
	func clear_Sender() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__Sender.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_Sender(value : String) -> void:
		__Sender.value = value
	
	var __Cc: PBField
	func get_Cc() -> String:
		return __Cc.value
	func clear_Cc() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__Cc.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_Cc(value : String) -> void:
		__Cc.value = value
	
	var __Topic: PBField
	func get_Topic() -> String:
		return __Topic.value
	func clear_Topic() -> void:
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__Topic.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_Topic(value : String) -> void:
		__Topic.value = value
	
	var __Content: PBField
	func get_Content() -> String:
		return __Content.value
	func clear_Content() -> void:
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__Content.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_Content(value : String) -> void:
		__Content.value = value
	
	var __IsRead: PBField
	func get_IsRead() -> bool:
		return __IsRead.value
	func clear_IsRead() -> void:
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__IsRead.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL]
	func set_IsRead(value : bool) -> void:
		__IsRead.value = value
	
	var __AwardList: PBField
	func get_AwardList() -> GoodsList:
		return __AwardList.value
	func clear_AwardList() -> void:
		data[8].state = PB_SERVICE_STATE.UNFILLED
		__AwardList.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_AwardList() -> GoodsList:
		__AwardList.value = GoodsList.new()
		return __AwardList.value
	
	var __TimeStamp: PBField
	func get_TimeStamp() -> int:
		return __TimeStamp.value
	func clear_TimeStamp() -> void:
		data[9].state = PB_SERVICE_STATE.UNFILLED
		__TimeStamp.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_TimeStamp(value : int) -> void:
		__TimeStamp.value = value
	
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
	
class MasterInfo:
	func _init():
		var service
		
		__UserInfo = PBField.new("UserInfo", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __UserInfo
		service.func_ref = Callable(self, "new_UserInfo")
		data[__UserInfo.tag] = service
		
	var data = {}
	
	var __UserInfo: PBField
	func get_UserInfo() -> UserInfo:
		return __UserInfo.value
	func clear_UserInfo() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__UserInfo.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_UserInfo() -> UserInfo:
		__UserInfo.value = UserInfo.new()
		return __UserInfo.value
	
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
	
class RegisterReq:
	func _init():
		var service
		
		__Name = PBField.new("Name", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __Name
		data[__Name.tag] = service
		
		__Password = PBField.new("Password", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __Password
		data[__Password.tag] = service
		
		__SecurityCode = PBField.new("SecurityCode", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __SecurityCode
		data[__SecurityCode.tag] = service
		
		__MachineCode = PBField.new("MachineCode", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __MachineCode
		data[__MachineCode.tag] = service
		
		__InvitationCode = PBField.new("InvitationCode", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 5, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __InvitationCode
		data[__InvitationCode.tag] = service
		
		__PlatformID = PBField.new("PlatformID", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 6, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __PlatformID
		data[__PlatformID.tag] = service
		
		__Gender = PBField.new("Gender", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 7, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __Gender
		data[__Gender.tag] = service
		
		__Age = PBField.new("Age", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 8, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __Age
		data[__Age.tag] = service
		
		__FaceID = PBField.new("FaceID", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 9, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __FaceID
		data[__FaceID.tag] = service
		
		__PassPortID = PBField.new("PassPortID", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 10, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __PassPortID
		data[__PassPortID.tag] = service
		
		__RealName = PBField.new("RealName", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 11, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __RealName
		data[__RealName.tag] = service
		
		__PhoneNum = PBField.new("PhoneNum", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 12, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __PhoneNum
		data[__PhoneNum.tag] = service
		
		__Email = PBField.new("Email", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 13, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __Email
		data[__Email.tag] = service
		
		__Address = PBField.new("Address", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 14, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __Address
		data[__Address.tag] = service
		
	var data = {}
	
	var __Name: PBField
	func get_Name() -> String:
		return __Name.value
	func clear_Name() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__Name.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_Name(value : String) -> void:
		__Name.value = value
	
	var __Password: PBField
	func get_Password() -> String:
		return __Password.value
	func clear_Password() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__Password.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_Password(value : String) -> void:
		__Password.value = value
	
	var __SecurityCode: PBField
	func get_SecurityCode() -> String:
		return __SecurityCode.value
	func clear_SecurityCode() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__SecurityCode.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_SecurityCode(value : String) -> void:
		__SecurityCode.value = value
	
	var __MachineCode: PBField
	func get_MachineCode() -> String:
		return __MachineCode.value
	func clear_MachineCode() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__MachineCode.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_MachineCode(value : String) -> void:
		__MachineCode.value = value
	
	var __InvitationCode: PBField
	func get_InvitationCode() -> String:
		return __InvitationCode.value
	func clear_InvitationCode() -> void:
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__InvitationCode.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_InvitationCode(value : String) -> void:
		__InvitationCode.value = value
	
	var __PlatformID: PBField
	func get_PlatformID() -> int:
		return __PlatformID.value
	func clear_PlatformID() -> void:
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__PlatformID.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_PlatformID(value : int) -> void:
		__PlatformID.value = value
	
	var __Gender: PBField
	func get_Gender() -> int:
		return __Gender.value
	func clear_Gender() -> void:
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__Gender.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_Gender(value : int) -> void:
		__Gender.value = value
	
	var __Age: PBField
	func get_Age() -> int:
		return __Age.value
	func clear_Age() -> void:
		data[8].state = PB_SERVICE_STATE.UNFILLED
		__Age.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_Age(value : int) -> void:
		__Age.value = value
	
	var __FaceID: PBField
	func get_FaceID() -> int:
		return __FaceID.value
	func clear_FaceID() -> void:
		data[9].state = PB_SERVICE_STATE.UNFILLED
		__FaceID.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_FaceID(value : int) -> void:
		__FaceID.value = value
	
	var __PassPortID: PBField
	func get_PassPortID() -> String:
		return __PassPortID.value
	func clear_PassPortID() -> void:
		data[10].state = PB_SERVICE_STATE.UNFILLED
		__PassPortID.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_PassPortID(value : String) -> void:
		__PassPortID.value = value
	
	var __RealName: PBField
	func get_RealName() -> String:
		return __RealName.value
	func clear_RealName() -> void:
		data[11].state = PB_SERVICE_STATE.UNFILLED
		__RealName.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_RealName(value : String) -> void:
		__RealName.value = value
	
	var __PhoneNum: PBField
	func get_PhoneNum() -> String:
		return __PhoneNum.value
	func clear_PhoneNum() -> void:
		data[12].state = PB_SERVICE_STATE.UNFILLED
		__PhoneNum.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_PhoneNum(value : String) -> void:
		__PhoneNum.value = value
	
	var __Email: PBField
	func get_Email() -> String:
		return __Email.value
	func clear_Email() -> void:
		data[13].state = PB_SERVICE_STATE.UNFILLED
		__Email.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_Email(value : String) -> void:
		__Email.value = value
	
	var __Address: PBField
	func get_Address() -> String:
		return __Address.value
	func clear_Address() -> void:
		data[14].state = PB_SERVICE_STATE.UNFILLED
		__Address.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_Address(value : String) -> void:
		__Address.value = value
	
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
	
class RegisterResp:
	func _init():
		var service
		
		__Info = PBField.new("Info", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __Info
		service.func_ref = Callable(self, "new_Info")
		data[__Info.tag] = service
		
	var data = {}
	
	var __Info: PBField
	func get_Info() -> UserInfo:
		return __Info.value
	func clear_Info() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__Info.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_Info() -> UserInfo:
		__Info.value = UserInfo.new()
		return __Info.value
	
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
	
class LoginReq:
	func _init():
		var service
		
		__Account = PBField.new("Account", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __Account
		data[__Account.tag] = service
		
		__Password = PBField.new("Password", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __Password
		data[__Password.tag] = service
		
		__SecurityCode = PBField.new("SecurityCode", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __SecurityCode
		data[__SecurityCode.tag] = service
		
		__MachineCode = PBField.new("MachineCode", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __MachineCode
		data[__MachineCode.tag] = service
		
		__PlatformID = PBField.new("PlatformID", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 5, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __PlatformID
		data[__PlatformID.tag] = service
		
	var data = {}
	
	var __Account: PBField
	func get_Account() -> String:
		return __Account.value
	func clear_Account() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__Account.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_Account(value : String) -> void:
		__Account.value = value
	
	var __Password: PBField
	func get_Password() -> String:
		return __Password.value
	func clear_Password() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__Password.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_Password(value : String) -> void:
		__Password.value = value
	
	var __SecurityCode: PBField
	func get_SecurityCode() -> String:
		return __SecurityCode.value
	func clear_SecurityCode() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__SecurityCode.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_SecurityCode(value : String) -> void:
		__SecurityCode.value = value
	
	var __MachineCode: PBField
	func get_MachineCode() -> String:
		return __MachineCode.value
	func clear_MachineCode() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__MachineCode.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_MachineCode(value : String) -> void:
		__MachineCode.value = value
	
	var __PlatformID: PBField
	func get_PlatformID() -> int:
		return __PlatformID.value
	func clear_PlatformID() -> void:
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__PlatformID.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_PlatformID(value : int) -> void:
		__PlatformID.value = value
	
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
	
class LoginResp:
	func _init():
		var service
		
		__MainInfo = PBField.new("MainInfo", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __MainInfo
		service.func_ref = Callable(self, "new_MainInfo")
		data[__MainInfo.tag] = service
		
		__InGameID = PBField.new("InGameID", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __InGameID
		data[__InGameID.tag] = service
		
		__InTableNum = PBField.new("InTableNum", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __InTableNum
		data[__InTableNum.tag] = service
		
		__Token = PBField.new("Token", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __Token
		data[__Token.tag] = service
		
	var data = {}
	
	var __MainInfo: PBField
	func get_MainInfo() -> MasterInfo:
		return __MainInfo.value
	func clear_MainInfo() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__MainInfo.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_MainInfo() -> MasterInfo:
		__MainInfo.value = MasterInfo.new()
		return __MainInfo.value
	
	var __InGameID: PBField
	func get_InGameID() -> int:
		return __InGameID.value
	func clear_InGameID() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__InGameID.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_InGameID(value : int) -> void:
		__InGameID.value = value
	
	var __InTableNum: PBField
	func get_InTableNum() -> int:
		return __InTableNum.value
	func clear_InTableNum() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__InTableNum.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_InTableNum(value : int) -> void:
		__InTableNum.value = value
	
	var __Token: PBField
	func get_Token() -> String:
		return __Token.value
	func clear_Token() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__Token.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_Token(value : String) -> void:
		__Token.value = value
	
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
	
class AllopatricResp:
	func _init():
		var service
		
		__UserID = PBField.new("UserID", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __UserID
		data[__UserID.tag] = service
		
	var data = {}
	
	var __UserID: PBField
	func get_UserID() -> int:
		return __UserID.value
	func clear_UserID() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__UserID.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_UserID(value : int) -> void:
		__UserID.value = value
	
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
	
class ReconnectReq:
	func _init():
		var service
		
		__Account = PBField.new("Account", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __Account
		data[__Account.tag] = service
		
		__Password = PBField.new("Password", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __Password
		data[__Password.tag] = service
		
		__MachineCode = PBField.new("MachineCode", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __MachineCode
		data[__MachineCode.tag] = service
		
		__PlatformID = PBField.new("PlatformID", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __PlatformID
		data[__PlatformID.tag] = service
		
	var data = {}
	
	var __Account: PBField
	func get_Account() -> String:
		return __Account.value
	func clear_Account() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__Account.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_Account(value : String) -> void:
		__Account.value = value
	
	var __Password: PBField
	func get_Password() -> String:
		return __Password.value
	func clear_Password() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__Password.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_Password(value : String) -> void:
		__Password.value = value
	
	var __MachineCode: PBField
	func get_MachineCode() -> String:
		return __MachineCode.value
	func clear_MachineCode() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__MachineCode.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_MachineCode(value : String) -> void:
		__MachineCode.value = value
	
	var __PlatformID: PBField
	func get_PlatformID() -> int:
		return __PlatformID.value
	func clear_PlatformID() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__PlatformID.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_PlatformID(value : int) -> void:
		__PlatformID.value = value
	
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
	
class ReconnectResp:
	func _init():
		var service
		
		__MainInfo = PBField.new("MainInfo", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __MainInfo
		service.func_ref = Callable(self, "new_MainInfo")
		data[__MainInfo.tag] = service
		
		__InGameID = PBField.new("InGameID", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __InGameID
		data[__InGameID.tag] = service
		
		__InTableNum = PBField.new("InTableNum", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __InTableNum
		data[__InTableNum.tag] = service
		
		__Token = PBField.new("Token", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __Token
		data[__Token.tag] = service
		
	var data = {}
	
	var __MainInfo: PBField
	func get_MainInfo() -> MasterInfo:
		return __MainInfo.value
	func clear_MainInfo() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__MainInfo.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_MainInfo() -> MasterInfo:
		__MainInfo.value = MasterInfo.new()
		return __MainInfo.value
	
	var __InGameID: PBField
	func get_InGameID() -> int:
		return __InGameID.value
	func clear_InGameID() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__InGameID.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_InGameID(value : int) -> void:
		__InGameID.value = value
	
	var __InTableNum: PBField
	func get_InTableNum() -> int:
		return __InTableNum.value
	func clear_InTableNum() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__InTableNum.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_InTableNum(value : int) -> void:
		__InTableNum.value = value
	
	var __Token: PBField
	func get_Token() -> String:
		return __Token.value
	func clear_Token() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__Token.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_Token(value : String) -> void:
		__Token.value = value
	
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
	
class CheckInReq:
	func _init():
		var service
		
		__UserID = PBField.new("UserID", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __UserID
		data[__UserID.tag] = service
		
		__Remark = PBField.new("Remark", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __Remark
		data[__Remark.tag] = service
		
	var data = {}
	
	var __UserID: PBField
	func get_UserID() -> int:
		return __UserID.value
	func clear_UserID() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__UserID.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_UserID(value : int) -> void:
		__UserID.value = value
	
	var __Remark: PBField
	func get_Remark() -> String:
		return __Remark.value
	func clear_Remark() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__Remark.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_Remark(value : String) -> void:
		__Remark.value = value
	
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
	
class CheckInResp:
	func _init():
		var service
		
		__UserID = PBField.new("UserID", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __UserID
		data[__UserID.tag] = service
		
		__Remark = PBField.new("Remark", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __Remark
		data[__Remark.tag] = service
		
		__Timestamp = PBField.new("Timestamp", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __Timestamp
		data[__Timestamp.tag] = service
		
		__AwardList = PBField.new("AwardList", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __AwardList
		service.func_ref = Callable(self, "new_AwardList")
		data[__AwardList.tag] = service
		
	var data = {}
	
	var __UserID: PBField
	func get_UserID() -> int:
		return __UserID.value
	func clear_UserID() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__UserID.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_UserID(value : int) -> void:
		__UserID.value = value
	
	var __Remark: PBField
	func get_Remark() -> String:
		return __Remark.value
	func clear_Remark() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__Remark.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_Remark(value : String) -> void:
		__Remark.value = value
	
	var __Timestamp: PBField
	func get_Timestamp() -> int:
		return __Timestamp.value
	func clear_Timestamp() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__Timestamp.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_Timestamp(value : int) -> void:
		__Timestamp.value = value
	
	var __AwardList: PBField
	func get_AwardList() -> GoodsList:
		return __AwardList.value
	func clear_AwardList() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__AwardList.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_AwardList() -> GoodsList:
		__AwardList.value = GoodsList.new()
		return __AwardList.value
	
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
	
class GetCheckInReq:
	func _init():
		var service
		
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
	
class GetCheckInResp:
	func _init():
		var service
		
		__UserID = PBField.new("UserID", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __UserID
		data[__UserID.tag] = service
		
		var __AllCheckin_default: Array[CheckInResp] = []
		__AllCheckin = PBField.new("AllCheckin", PB_DATA_TYPE.MESSAGE, PB_RULE.REPEATED, 2, true, __AllCheckin_default)
		service = PBServiceField.new()
		service.field = __AllCheckin
		service.func_ref = Callable(self, "add_AllCheckin")
		data[__AllCheckin.tag] = service
		
		__PageNum = PBField.new("PageNum", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __PageNum
		data[__PageNum.tag] = service
		
	var data = {}
	
	var __UserID: PBField
	func get_UserID() -> int:
		return __UserID.value
	func clear_UserID() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__UserID.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_UserID(value : int) -> void:
		__UserID.value = value
	
	var __AllCheckin: PBField
	func get_AllCheckin() -> Array[CheckInResp]:
		return __AllCheckin.value
	func clear_AllCheckin() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__AllCheckin.value = []
	func add_AllCheckin() -> CheckInResp:
		var element = CheckInResp.new()
		__AllCheckin.value.append(element)
		return element
	
	var __PageNum: PBField
	func get_PageNum() -> int:
		return __PageNum.value
	func clear_PageNum() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__PageNum.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_PageNum(value : int) -> void:
		__PageNum.value = value
	
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
	
class DrawHeroReq:
	func _init():
		var service
		
		__Amount = PBField.new("Amount", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __Amount
		data[__Amount.tag] = service
		
	var data = {}
	
	var __Amount: PBField
	func get_Amount() -> int:
		return __Amount.value
	func clear_Amount() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__Amount.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_Amount(value : int) -> void:
		__Amount.value = value
	
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
	
class DrawHeroResp:
	func _init():
		var service
		
		__UserID = PBField.new("UserID", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __UserID
		data[__UserID.tag] = service
		
		var __HeroList_default: Array[HeroInfo] = []
		__HeroList = PBField.new("HeroList", PB_DATA_TYPE.MESSAGE, PB_RULE.REPEATED, 2, true, __HeroList_default)
		service = PBServiceField.new()
		service.field = __HeroList
		service.func_ref = Callable(self, "add_HeroList")
		data[__HeroList.tag] = service
		
	var data = {}
	
	var __UserID: PBField
	func get_UserID() -> int:
		return __UserID.value
	func clear_UserID() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__UserID.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_UserID(value : int) -> void:
		__UserID.value = value
	
	var __HeroList: PBField
	func get_HeroList() -> Array[HeroInfo]:
		return __HeroList.value
	func clear_HeroList() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__HeroList.value = []
	func add_HeroList() -> HeroInfo:
		var element = HeroInfo.new()
		__HeroList.value.append(element)
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
	
class GetMyHeroReq:
	func _init():
		var service
		
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
	
class GetMyHeroResp:
	func _init():
		var service
		
		__UserID = PBField.new("UserID", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __UserID
		data[__UserID.tag] = service
		
		var __HeroList_default: Array[HeroInfo] = []
		__HeroList = PBField.new("HeroList", PB_DATA_TYPE.MESSAGE, PB_RULE.REPEATED, 2, true, __HeroList_default)
		service = PBServiceField.new()
		service.field = __HeroList
		service.func_ref = Callable(self, "add_HeroList")
		data[__HeroList.tag] = service
		
	var data = {}
	
	var __UserID: PBField
	func get_UserID() -> int:
		return __UserID.value
	func clear_UserID() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__UserID.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_UserID(value : int) -> void:
		__UserID.value = value
	
	var __HeroList: PBField
	func get_HeroList() -> Array[HeroInfo]:
		return __HeroList.value
	func clear_HeroList() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__HeroList.value = []
	func add_HeroList() -> HeroInfo:
		var element = HeroInfo.new()
		__HeroList.value.append(element)
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
	
class ChooseHeroReq:
	func _init():
		var service
		
		var __HeroIDs_default: Array[int] = []
		__HeroIDs = PBField.new("HeroIDs", PB_DATA_TYPE.INT64, PB_RULE.REPEATED, 1, true, __HeroIDs_default)
		service = PBServiceField.new()
		service.field = __HeroIDs
		data[__HeroIDs.tag] = service
		
	var data = {}
	
	var __HeroIDs: PBField
	func get_HeroIDs() -> Array[int]:
		return __HeroIDs.value
	func clear_HeroIDs() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__HeroIDs.value = []
	func add_HeroIDs(value : int) -> void:
		__HeroIDs.value.append(value)
	
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
	
class ChooseHeroResp:
	func _init():
		var service
		
		var __HeroList_default: Array[HeroInfo] = []
		__HeroList = PBField.new("HeroList", PB_DATA_TYPE.MESSAGE, PB_RULE.REPEATED, 1, true, __HeroList_default)
		service = PBServiceField.new()
		service.field = __HeroList
		service.func_ref = Callable(self, "add_HeroList")
		data[__HeroList.tag] = service
		
		__Hint = PBField.new("Hint", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __Hint
		data[__Hint.tag] = service
		
	var data = {}
	
	var __HeroList: PBField
	func get_HeroList() -> Array[HeroInfo]:
		return __HeroList.value
	func clear_HeroList() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__HeroList.value = []
	func add_HeroList() -> HeroInfo:
		var element = HeroInfo.new()
		__HeroList.value.append(element)
		return element
	
	var __Hint: PBField
	func get_Hint() -> String:
		return __Hint.value
	func clear_Hint() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__Hint.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_Hint(value : String) -> void:
		__Hint.value = value
	
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
	
class GetAllHeroReq:
	func _init():
		var service
		
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
	
class GetAllHeroResp:
	func _init():
		var service
		
		var __HeroList_default: Array[HeroInfo] = []
		__HeroList = PBField.new("HeroList", PB_DATA_TYPE.MESSAGE, PB_RULE.REPEATED, 1, true, __HeroList_default)
		service = PBServiceField.new()
		service.field = __HeroList
		service.func_ref = Callable(self, "add_HeroList")
		data[__HeroList.tag] = service
		
	var data = {}
	
	var __HeroList: PBField
	func get_HeroList() -> Array[HeroInfo]:
		return __HeroList.value
	func clear_HeroList() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__HeroList.value = []
	func add_HeroList() -> HeroInfo:
		var element = HeroInfo.new()
		__HeroList.value.append(element)
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
	
class CheckHeroReq:
	func _init():
		var service
		
		var __HeroIDs_default: Array[int] = []
		__HeroIDs = PBField.new("HeroIDs", PB_DATA_TYPE.INT32, PB_RULE.REPEATED, 1, true, __HeroIDs_default)
		service = PBServiceField.new()
		service.field = __HeroIDs
		data[__HeroIDs.tag] = service
		
		__Name = PBField.new("Name", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __Name
		data[__Name.tag] = service
		
		__Sex = PBField.new("Sex", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __Sex
		data[__Sex.tag] = service
		
		__Country = PBField.new("Country", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __Country
		data[__Country.tag] = service
		
		__Faction = PBField.new("Faction", PB_DATA_TYPE.ENUM, PB_RULE.OPTIONAL, 5, true, DEFAULT_VALUES_3[PB_DATA_TYPE.ENUM])
		service = PBServiceField.new()
		service.field = __Faction
		data[__Faction.tag] = service
		
	var data = {}
	
	var __HeroIDs: PBField
	func get_HeroIDs() -> Array[int]:
		return __HeroIDs.value
	func clear_HeroIDs() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__HeroIDs.value = []
	func add_HeroIDs(value : int) -> void:
		__HeroIDs.value.append(value)
	
	var __Name: PBField
	func get_Name() -> String:
		return __Name.value
	func clear_Name() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__Name.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_Name(value : String) -> void:
		__Name.value = value
	
	var __Sex: PBField
	func get_Sex() -> int:
		return __Sex.value
	func clear_Sex() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__Sex.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_Sex(value : int) -> void:
		__Sex.value = value
	
	var __Country: PBField
	func get_Country() -> String:
		return __Country.value
	func clear_Country() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__Country.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_Country(value : String) -> void:
		__Country.value = value
	
	var __Faction: PBField
	func get_Faction():
		return __Faction.value
	func clear_Faction() -> void:
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__Faction.value = DEFAULT_VALUES_3[PB_DATA_TYPE.ENUM]
	func set_Faction(value) -> void:
		__Faction.value = value
	
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
	
class CheckHeroResp:
	func _init():
		var service
		
		var __HeroList_default: Array[HeroInfo] = []
		__HeroList = PBField.new("HeroList", PB_DATA_TYPE.MESSAGE, PB_RULE.REPEATED, 1, true, __HeroList_default)
		service = PBServiceField.new()
		service.field = __HeroList
		service.func_ref = Callable(self, "add_HeroList")
		data[__HeroList.tag] = service
		
	var data = {}
	
	var __HeroList: PBField
	func get_HeroList() -> Array[HeroInfo]:
		return __HeroList.value
	func clear_HeroList() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__HeroList.value = []
	func add_HeroList() -> HeroInfo:
		var element = HeroInfo.new()
		__HeroList.value.append(element)
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
	
class RechargeReq:
	func _init():
		var service
		
		__UserID = PBField.new("UserID", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __UserID
		data[__UserID.tag] = service
		
		__ByiD = PBField.new("ByiD", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __ByiD
		data[__ByiD.tag] = service
		
		__Payment = PBField.new("Payment", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __Payment
		data[__Payment.tag] = service
		
		__Method = PBField.new("Method", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __Method
		data[__Method.tag] = service
		
		__Switch = PBField.new("Switch", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 5, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __Switch
		data[__Switch.tag] = service
		
		__Reason = PBField.new("Reason", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 6, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __Reason
		data[__Reason.tag] = service
		
	var data = {}
	
	var __UserID: PBField
	func get_UserID() -> int:
		return __UserID.value
	func clear_UserID() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__UserID.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_UserID(value : int) -> void:
		__UserID.value = value
	
	var __ByiD: PBField
	func get_ByiD() -> int:
		return __ByiD.value
	func clear_ByiD() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__ByiD.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_ByiD(value : int) -> void:
		__ByiD.value = value
	
	var __Payment: PBField
	func get_Payment() -> int:
		return __Payment.value
	func clear_Payment() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__Payment.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_Payment(value : int) -> void:
		__Payment.value = value
	
	var __Method: PBField
	func get_Method() -> int:
		return __Method.value
	func clear_Method() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__Method.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_Method(value : int) -> void:
		__Method.value = value
	
	var __Switch: PBField
	func get_Switch() -> int:
		return __Switch.value
	func clear_Switch() -> void:
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__Switch.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_Switch(value : int) -> void:
		__Switch.value = value
	
	var __Reason: PBField
	func get_Reason() -> String:
		return __Reason.value
	func clear_Reason() -> void:
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__Reason.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_Reason(value : String) -> void:
		__Reason.value = value
	
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
	
class RechargeResp:
	func _init():
		var service
		
		__UserID = PBField.new("UserID", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __UserID
		data[__UserID.tag] = service
		
		__ByiD = PBField.new("ByiD", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __ByiD
		data[__ByiD.tag] = service
		
		__PreMoney = PBField.new("PreMoney", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __PreMoney
		data[__PreMoney.tag] = service
		
		__Payment = PBField.new("Payment", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __Payment
		data[__Payment.tag] = service
		
		__Money = PBField.new("Money", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 5, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __Money
		data[__Money.tag] = service
		
		__YuanBao = PBField.new("YuanBao", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 6, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __YuanBao
		data[__YuanBao.tag] = service
		
		__Coin = PBField.new("Coin", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 7, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __Coin
		data[__Coin.tag] = service
		
		__Method = PBField.new("Method", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 8, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __Method
		data[__Method.tag] = service
		
		__IsSuccess = PBField.new("IsSuccess", PB_DATA_TYPE.BOOL, PB_RULE.OPTIONAL, 9, true, DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL])
		service = PBServiceField.new()
		service.field = __IsSuccess
		data[__IsSuccess.tag] = service
		
		__Order = PBField.new("Order", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 10, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __Order
		data[__Order.tag] = service
		
		__TimeStamp = PBField.new("TimeStamp", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 11, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __TimeStamp
		data[__TimeStamp.tag] = service
		
		__Reason = PBField.new("Reason", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 12, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __Reason
		data[__Reason.tag] = service
		
	var data = {}
	
	var __UserID: PBField
	func get_UserID() -> int:
		return __UserID.value
	func clear_UserID() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__UserID.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_UserID(value : int) -> void:
		__UserID.value = value
	
	var __ByiD: PBField
	func get_ByiD() -> int:
		return __ByiD.value
	func clear_ByiD() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__ByiD.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_ByiD(value : int) -> void:
		__ByiD.value = value
	
	var __PreMoney: PBField
	func get_PreMoney() -> int:
		return __PreMoney.value
	func clear_PreMoney() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__PreMoney.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_PreMoney(value : int) -> void:
		__PreMoney.value = value
	
	var __Payment: PBField
	func get_Payment() -> int:
		return __Payment.value
	func clear_Payment() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__Payment.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_Payment(value : int) -> void:
		__Payment.value = value
	
	var __Money: PBField
	func get_Money() -> int:
		return __Money.value
	func clear_Money() -> void:
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__Money.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_Money(value : int) -> void:
		__Money.value = value
	
	var __YuanBao: PBField
	func get_YuanBao() -> int:
		return __YuanBao.value
	func clear_YuanBao() -> void:
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__YuanBao.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_YuanBao(value : int) -> void:
		__YuanBao.value = value
	
	var __Coin: PBField
	func get_Coin() -> int:
		return __Coin.value
	func clear_Coin() -> void:
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__Coin.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_Coin(value : int) -> void:
		__Coin.value = value
	
	var __Method: PBField
	func get_Method() -> int:
		return __Method.value
	func clear_Method() -> void:
		data[8].state = PB_SERVICE_STATE.UNFILLED
		__Method.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_Method(value : int) -> void:
		__Method.value = value
	
	var __IsSuccess: PBField
	func get_IsSuccess() -> bool:
		return __IsSuccess.value
	func clear_IsSuccess() -> void:
		data[9].state = PB_SERVICE_STATE.UNFILLED
		__IsSuccess.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL]
	func set_IsSuccess(value : bool) -> void:
		__IsSuccess.value = value
	
	var __Order: PBField
	func get_Order() -> String:
		return __Order.value
	func clear_Order() -> void:
		data[10].state = PB_SERVICE_STATE.UNFILLED
		__Order.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_Order(value : String) -> void:
		__Order.value = value
	
	var __TimeStamp: PBField
	func get_TimeStamp() -> int:
		return __TimeStamp.value
	func clear_TimeStamp() -> void:
		data[11].state = PB_SERVICE_STATE.UNFILLED
		__TimeStamp.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_TimeStamp(value : int) -> void:
		__TimeStamp.value = value
	
	var __Reason: PBField
	func get_Reason() -> String:
		return __Reason.value
	func clear_Reason() -> void:
		data[12].state = PB_SERVICE_STATE.UNFILLED
		__Reason.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_Reason(value : String) -> void:
		__Reason.value = value
	
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
	
class GetRechargesReq:
	func _init():
		var service
		
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
	
class GetRechargesResp:
	func _init():
		var service
		
		__UserID = PBField.new("UserID", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __UserID
		data[__UserID.tag] = service
		
		var __AllRecharges_default: Array[RechargeResp] = []
		__AllRecharges = PBField.new("AllRecharges", PB_DATA_TYPE.MESSAGE, PB_RULE.REPEATED, 2, true, __AllRecharges_default)
		service = PBServiceField.new()
		service.field = __AllRecharges
		service.func_ref = Callable(self, "add_AllRecharges")
		data[__AllRecharges.tag] = service
		
		__PageNum = PBField.new("PageNum", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __PageNum
		data[__PageNum.tag] = service
		
	var data = {}
	
	var __UserID: PBField
	func get_UserID() -> int:
		return __UserID.value
	func clear_UserID() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__UserID.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_UserID(value : int) -> void:
		__UserID.value = value
	
	var __AllRecharges: PBField
	func get_AllRecharges() -> Array[RechargeResp]:
		return __AllRecharges.value
	func clear_AllRecharges() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__AllRecharges.value = []
	func add_AllRecharges() -> RechargeResp:
		var element = RechargeResp.new()
		__AllRecharges.value.append(element)
		return element
	
	var __PageNum: PBField
	func get_PageNum() -> int:
		return __PageNum.value
	func clear_PageNum() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__PageNum.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_PageNum(value : int) -> void:
		__PageNum.value = value
	
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
	
class GetGoodsReq:
	func _init():
		var service
		
		__ID = PBField.new("ID", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __ID
		data[__ID.tag] = service
		
	var data = {}
	
	var __ID: PBField
	func get_ID() -> int:
		return __ID.value
	func clear_ID() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__ID.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_ID(value : int) -> void:
		__ID.value = value
	
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
	
class GetGoodsResp:
	func _init():
		var service
		
		__UserID = PBField.new("UserID", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __UserID
		data[__UserID.tag] = service
		
		__Info = PBField.new("Info", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __Info
		service.func_ref = Callable(self, "new_Info")
		data[__Info.tag] = service
		
	var data = {}
	
	var __UserID: PBField
	func get_UserID() -> int:
		return __UserID.value
	func clear_UserID() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__UserID.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_UserID(value : int) -> void:
		__UserID.value = value
	
	var __Info: PBField
	func get_Info() -> GoodsInfo:
		return __Info.value
	func clear_Info() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__Info.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_Info() -> GoodsInfo:
		__Info.value = GoodsInfo.new()
		return __Info.value
	
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
	
class GetAllGoodsReq:
	func _init():
		var service
		
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
	
class GetAllGoodsResp:
	func _init():
		var service
		
		__UserID = PBField.new("UserID", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __UserID
		data[__UserID.tag] = service
		
		var __Info_default: Array[GoodsInfo] = []
		__Info = PBField.new("Info", PB_DATA_TYPE.MESSAGE, PB_RULE.REPEATED, 2, true, __Info_default)
		service = PBServiceField.new()
		service.field = __Info
		service.func_ref = Callable(self, "add_Info")
		data[__Info.tag] = service
		
		__PageNum = PBField.new("PageNum", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __PageNum
		data[__PageNum.tag] = service
		
	var data = {}
	
	var __UserID: PBField
	func get_UserID() -> int:
		return __UserID.value
	func clear_UserID() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__UserID.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_UserID(value : int) -> void:
		__UserID.value = value
	
	var __Info: PBField
	func get_Info() -> Array[GoodsInfo]:
		return __Info.value
	func clear_Info() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__Info.value = []
	func add_Info() -> GoodsInfo:
		var element = GoodsInfo.new()
		__Info.value.append(element)
		return element
	
	var __PageNum: PBField
	func get_PageNum() -> int:
		return __PageNum.value
	func clear_PageNum() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__PageNum.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_PageNum(value : int) -> void:
		__PageNum.value = value
	
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
	
class BuyGoodsReq:
	func _init():
		var service
		
		__ID = PBField.new("ID", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __ID
		data[__ID.tag] = service
		
		__Payment = PBField.new("Payment", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __Payment
		data[__Payment.tag] = service
		
		__Count = PBField.new("Count", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __Count
		data[__Count.tag] = service
		
	var data = {}
	
	var __ID: PBField
	func get_ID() -> int:
		return __ID.value
	func clear_ID() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__ID.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_ID(value : int) -> void:
		__ID.value = value
	
	var __Payment: PBField
	func get_Payment() -> int:
		return __Payment.value
	func clear_Payment() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__Payment.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_Payment(value : int) -> void:
		__Payment.value = value
	
	var __Count: PBField
	func get_Count() -> int:
		return __Count.value
	func clear_Count() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__Count.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_Count(value : int) -> void:
		__Count.value = value
	
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
	
class BuyGoodsResp:
	func _init():
		var service
		
		__UserID = PBField.new("UserID", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __UserID
		data[__UserID.tag] = service
		
		__Info = PBField.new("Info", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __Info
		service.func_ref = Callable(self, "new_Info")
		data[__Info.tag] = service
		
	var data = {}
	
	var __UserID: PBField
	func get_UserID() -> int:
		return __UserID.value
	func clear_UserID() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__UserID.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_UserID(value : int) -> void:
		__UserID.value = value
	
	var __Info: PBField
	func get_Info() -> GoodsInfo:
		return __Info.value
	func clear_Info() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__Info.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_Info() -> GoodsInfo:
		__Info.value = GoodsInfo.new()
		return __Info.value
	
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
	
class CheckKnapsackReq:
	func _init():
		var service
		
		__ID = PBField.new("ID", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __ID
		data[__ID.tag] = service
		
		__Number = PBField.new("Number", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __Number
		data[__Number.tag] = service
		
	var data = {}
	
	var __ID: PBField
	func get_ID() -> int:
		return __ID.value
	func clear_ID() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__ID.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_ID(value : int) -> void:
		__ID.value = value
	
	var __Number: PBField
	func get_Number() -> int:
		return __Number.value
	func clear_Number() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__Number.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_Number(value : int) -> void:
		__Number.value = value
	
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
	
class CheckKnapsackResp:
	func _init():
		var service
		
		__UserID = PBField.new("UserID", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __UserID
		data[__UserID.tag] = service
		
		__Info = PBField.new("Info", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __Info
		service.func_ref = Callable(self, "new_Info")
		data[__Info.tag] = service
		
	var data = {}
	
	var __UserID: PBField
	func get_UserID() -> int:
		return __UserID.value
	func clear_UserID() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__UserID.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_UserID(value : int) -> void:
		__UserID.value = value
	
	var __Info: PBField
	func get_Info() -> KnapsackInfo:
		return __Info.value
	func clear_Info() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__Info.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_Info() -> KnapsackInfo:
		__Info.value = KnapsackInfo.new()
		return __Info.value
	
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
	
class BarterReq:
	func _init():
		var service
		
		__ID = PBField.new("ID", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __ID
		data[__ID.tag] = service
		
		__ToID = PBField.new("ToID", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __ToID
		data[__ToID.tag] = service
		
		__Amount = PBField.new("Amount", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __Amount
		data[__Amount.tag] = service
		
	var data = {}
	
	var __ID: PBField
	func get_ID() -> int:
		return __ID.value
	func clear_ID() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__ID.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_ID(value : int) -> void:
		__ID.value = value
	
	var __ToID: PBField
	func get_ToID() -> int:
		return __ToID.value
	func clear_ToID() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__ToID.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_ToID(value : int) -> void:
		__ToID.value = value
	
	var __Amount: PBField
	func get_Amount() -> int:
		return __Amount.value
	func clear_Amount() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__Amount.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_Amount(value : int) -> void:
		__Amount.value = value
	
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
	
class BarterResp:
	func _init():
		var service
		
		__UserID = PBField.new("UserID", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __UserID
		data[__UserID.tag] = service
		
		__Info = PBField.new("Info", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __Info
		service.func_ref = Callable(self, "new_Info")
		data[__Info.tag] = service
		
	var data = {}
	
	var __UserID: PBField
	func get_UserID() -> int:
		return __UserID.value
	func clear_UserID() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__UserID.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_UserID(value : int) -> void:
		__UserID.value = value
	
	var __Info: PBField
	func get_Info() -> KnapsackInfo:
		return __Info.value
	func clear_Info() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__Info.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_Info() -> KnapsackInfo:
		__Info.value = KnapsackInfo.new()
		return __Info.value
	
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
	
class ToShoppingResp:
	func _init():
		var service
		
		__ID = PBField.new("ID", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __ID
		data[__ID.tag] = service
		
		__Count = PBField.new("Count", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __Count
		data[__Count.tag] = service
		
		__Reason = PBField.new("Reason", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __Reason
		data[__Reason.tag] = service
		
	var data = {}
	
	var __ID: PBField
	func get_ID() -> int:
		return __ID.value
	func clear_ID() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__ID.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_ID(value : int) -> void:
		__ID.value = value
	
	var __Count: PBField
	func get_Count() -> int:
		return __Count.value
	func clear_Count() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__Count.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_Count(value : int) -> void:
		__Count.value = value
	
	var __Reason: PBField
	func get_Reason() -> String:
		return __Reason.value
	func clear_Reason() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__Reason.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_Reason(value : String) -> void:
		__Reason.value = value
	
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
	
class EmailReq:
	func _init():
		var service
		
		__PageNum = PBField.new("PageNum", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __PageNum
		data[__PageNum.tag] = service
		
	var data = {}
	
	var __PageNum: PBField
	func get_PageNum() -> int:
		return __PageNum.value
	func clear_PageNum() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__PageNum.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_PageNum(value : int) -> void:
		__PageNum.value = value
	
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
	
class EmailResp:
	func _init():
		var service
		
		__UserID = PBField.new("UserID", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __UserID
		data[__UserID.tag] = service
		
		var __Infos_default: Array[EmailInfo] = []
		__Infos = PBField.new("Infos", PB_DATA_TYPE.MESSAGE, PB_RULE.REPEATED, 2, true, __Infos_default)
		service = PBServiceField.new()
		service.field = __Infos
		service.func_ref = Callable(self, "add_Infos")
		data[__Infos.tag] = service
		
		__PageNum = PBField.new("PageNum", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __PageNum
		data[__PageNum.tag] = service
		
	var data = {}
	
	var __UserID: PBField
	func get_UserID() -> int:
		return __UserID.value
	func clear_UserID() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__UserID.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_UserID(value : int) -> void:
		__UserID.value = value
	
	var __Infos: PBField
	func get_Infos() -> Array[EmailInfo]:
		return __Infos.value
	func clear_Infos() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__Infos.value = []
	func add_Infos() -> EmailInfo:
		var element = EmailInfo.new()
		__Infos.value.append(element)
		return element
	
	var __PageNum: PBField
	func get_PageNum() -> int:
		return __PageNum.value
	func clear_PageNum() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__PageNum.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_PageNum(value : int) -> void:
		__PageNum.value = value
	
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
	
class ClaimReq:
	func _init():
		var service
		
		__EmailID = PBField.new("EmailID", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __EmailID
		data[__EmailID.tag] = service
		
	var data = {}
	
	var __EmailID: PBField
	func get_EmailID() -> int:
		return __EmailID.value
	func clear_EmailID() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__EmailID.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_EmailID(value : int) -> void:
		__EmailID.value = value
	
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
	
class ClaimResp:
	func _init():
		var service
		
		__UserID = PBField.new("UserID", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __UserID
		data[__UserID.tag] = service
		
		__EmailID = PBField.new("EmailID", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __EmailID
		data[__EmailID.tag] = service
		
	var data = {}
	
	var __UserID: PBField
	func get_UserID() -> int:
		return __UserID.value
	func clear_UserID() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__UserID.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_UserID(value : int) -> void:
		__UserID.value = value
	
	var __EmailID: PBField
	func get_EmailID() -> int:
		return __EmailID.value
	func clear_EmailID() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__EmailID.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_EmailID(value : int) -> void:
		__EmailID.value = value
	
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
	
class SuggestReq:
	func _init():
		var service
		
		__Content = PBField.new("Content", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __Content
		data[__Content.tag] = service
		
	var data = {}
	
	var __Content: PBField
	func get_Content() -> String:
		return __Content.value
	func clear_Content() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__Content.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_Content(value : String) -> void:
		__Content.value = value
	
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
	
class SuggestResp:
	func _init():
		var service
		
		__UserID = PBField.new("UserID", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __UserID
		data[__UserID.tag] = service
		
		__Feedback = PBField.new("Feedback", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __Feedback
		service.func_ref = Callable(self, "new_Feedback")
		data[__Feedback.tag] = service
		
	var data = {}
	
	var __UserID: PBField
	func get_UserID() -> int:
		return __UserID.value
	func clear_UserID() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__UserID.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_UserID(value : int) -> void:
		__UserID.value = value
	
	var __Feedback: PBField
	func get_Feedback() -> EmailInfo:
		return __Feedback.value
	func clear_Feedback() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__Feedback.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_Feedback() -> EmailInfo:
		__Feedback.value = EmailInfo.new()
		return __Feedback.value
	
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
	
class EmailReadReq:
	func _init():
		var service
		
		__EmailID = PBField.new("EmailID", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __EmailID
		data[__EmailID.tag] = service
		
	var data = {}
	
	var __EmailID: PBField
	func get_EmailID() -> int:
		return __EmailID.value
	func clear_EmailID() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__EmailID.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_EmailID(value : int) -> void:
		__EmailID.value = value
	
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
	
class EmailReadResp:
	func _init():
		var service
		
		__UserID = PBField.new("UserID", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __UserID
		data[__UserID.tag] = service
		
		__EmailID = PBField.new("EmailID", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __EmailID
		data[__EmailID.tag] = service
		
	var data = {}
	
	var __UserID: PBField
	func get_UserID() -> int:
		return __UserID.value
	func clear_UserID() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__UserID.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_UserID(value : int) -> void:
		__UserID.value = value
	
	var __EmailID: PBField
	func get_EmailID() -> int:
		return __EmailID.value
	func clear_EmailID() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__EmailID.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_EmailID(value : int) -> void:
		__EmailID.value = value
	
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
	
class EmailDelReq:
	func _init():
		var service
		
		__EmailID = PBField.new("EmailID", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __EmailID
		data[__EmailID.tag] = service
		
	var data = {}
	
	var __EmailID: PBField
	func get_EmailID() -> int:
		return __EmailID.value
	func clear_EmailID() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__EmailID.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_EmailID(value : int) -> void:
		__EmailID.value = value
	
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
	
class EmailDelResp:
	func _init():
		var service
		
		__UserID = PBField.new("UserID", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __UserID
		data[__UserID.tag] = service
		
		__EmailID = PBField.new("EmailID", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __EmailID
		data[__EmailID.tag] = service
		
	var data = {}
	
	var __UserID: PBField
	func get_UserID() -> int:
		return __UserID.value
	func clear_UserID() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__UserID.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_UserID(value : int) -> void:
		__UserID.value = value
	
	var __EmailID: PBField
	func get_EmailID() -> int:
		return __EmailID.value
	func clear_EmailID() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__EmailID.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_EmailID(value : int) -> void:
		__EmailID.value = value
	
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
	
class ResultResp:
	func _init():
		var service
		
		__State = PBField.new("State", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __State
		data[__State.tag] = service
		
		__Hints = PBField.new("Hints", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __Hints
		data[__Hints.tag] = service
		
	var data = {}
	
	var __State: PBField
	func get_State() -> int:
		return __State.value
	func clear_State() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__State.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_State(value : int) -> void:
		__State.value = value
	
	var __Hints: PBField
	func get_Hints() -> String:
		return __Hints.value
	func clear_Hints() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__Hints.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_Hints(value : String) -> void:
		__Hints.value = value
	
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
	
class ResultPopResp:
	func _init():
		var service
		
		__Flag = PBField.new("Flag", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __Flag
		data[__Flag.tag] = service
		
		__Title = PBField.new("Title", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __Title
		data[__Title.tag] = service
		
		__Hints = PBField.new("Hints", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __Hints
		data[__Hints.tag] = service
		
	var data = {}
	
	var __Flag: PBField
	func get_Flag() -> int:
		return __Flag.value
	func clear_Flag() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__Flag.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_Flag(value : int) -> void:
		__Flag.value = value
	
	var __Title: PBField
	func get_Title() -> String:
		return __Title.value
	func clear_Title() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__Title.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_Title(value : String) -> void:
		__Title.value = value
	
	var __Hints: PBField
	func get_Hints() -> String:
		return __Hints.value
	func clear_Hints() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__Hints.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_Hints(value : String) -> void:
		__Hints.value = value
	
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
	
class PingReq:
	func _init():
		var service
		
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
	
class PongResp:
	func _init():
		var service
		
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
	
################ USER DATA END #################
