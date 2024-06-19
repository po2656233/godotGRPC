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


class LoginRequest:
	func _init():
		var service
		
		__serverId = PBField.new("serverId", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __serverId
		data[__serverId.tag] = service
		
		__token = PBField.new("token", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __token
		data[__token.tag] = service
		
		var __params_default: Array = []
		__params = PBField.new("params", PB_DATA_TYPE.MAP, PB_RULE.REPEATED, 3, true, __params_default)
		service = PBServiceField.new()
		service.field = __params
		service.func_ref = Callable(self, "add_empty_params")
		data[__params.tag] = service
		
	var data = {}
	
	var __serverId: PBField
	func get_serverId() -> int:
		return __serverId.value
	func clear_serverId() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__serverId.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_serverId(value : int) -> void:
		__serverId.value = value
	
	var __token: PBField
	func get_token() -> String:
		return __token.value
	func clear_token() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__token.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_token(value : String) -> void:
		__token.value = value
	
	var __params: PBField
	func get_raw_params():
		return __params.value
	func get_params():
		return PBPacker.construct_map(__params.value)
	func clear_params():
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__params.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MAP]
	func add_empty_params() -> LoginRequest.map_type_params:
		var element = LoginRequest.map_type_params.new()
		__params.value.append(element)
		return element
	func add_params(a_key, a_value) -> void:
		var idx = -1
		for i in range(__params.value.size()):
			if __params.value[i].get_key() == a_key:
				idx = i
				break
		var element = LoginRequest.map_type_params.new()
		element.set_key(a_key)
		element.set_value(a_value)
		if idx != -1:
			__params.value[idx] = element
		else:
			__params.value.append(element)
	
	class map_type_params:
		func _init():
			var service
			
			__key = PBField.new("key", PB_DATA_TYPE.INT32, PB_RULE.REQUIRED, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
			__key.is_map_field = true
			service = PBServiceField.new()
			service.field = __key
			data[__key.tag] = service
			
			__value = PBField.new("value", PB_DATA_TYPE.STRING, PB_RULE.REQUIRED, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
			__value.is_map_field = true
			service = PBServiceField.new()
			service.field = __value
			data[__value.tag] = service
			
		var data = {}
		
		var __key: PBField
		func get_key() -> int:
			return __key.value
		func clear_key() -> void:
			data[1].state = PB_SERVICE_STATE.UNFILLED
			__key.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
		func set_key(value : int) -> void:
			__key.value = value
		
		var __value: PBField
		func get_value() -> String:
			return __value.value
		func clear_value() -> void:
			data[2].state = PB_SERVICE_STATE.UNFILLED
			__value.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
		func set_value(value : String) -> void:
			__value.value = value
		
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
	
class LoginResponse:
	func _init():
		var service
		
		__uid = PBField.new("uid", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __uid
		data[__uid.tag] = service
		
		__pid = PBField.new("pid", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __pid
		data[__pid.tag] = service
		
		__openId = PBField.new("openId", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __openId
		data[__openId.tag] = service
		
		var __params_default: Array = []
		__params = PBField.new("params", PB_DATA_TYPE.MAP, PB_RULE.REPEATED, 4, true, __params_default)
		service = PBServiceField.new()
		service.field = __params
		service.func_ref = Callable(self, "add_empty_params")
		data[__params.tag] = service
		
	var data = {}
	
	var __uid: PBField
	func get_uid() -> int:
		return __uid.value
	func clear_uid() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__uid.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_uid(value : int) -> void:
		__uid.value = value
	
	var __pid: PBField
	func get_pid() -> int:
		return __pid.value
	func clear_pid() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__pid.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_pid(value : int) -> void:
		__pid.value = value
	
	var __openId: PBField
	func get_openId() -> String:
		return __openId.value
	func clear_openId() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__openId.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_openId(value : String) -> void:
		__openId.value = value
	
	var __params: PBField
	func get_raw_params():
		return __params.value
	func get_params():
		return PBPacker.construct_map(__params.value)
	func clear_params():
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__params.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MAP]
	func add_empty_params() -> LoginResponse.map_type_params:
		var element = LoginResponse.map_type_params.new()
		__params.value.append(element)
		return element
	func add_params(a_key, a_value) -> void:
		var idx = -1
		for i in range(__params.value.size()):
			if __params.value[i].get_key() == a_key:
				idx = i
				break
		var element = LoginResponse.map_type_params.new()
		element.set_key(a_key)
		element.set_value(a_value)
		if idx != -1:
			__params.value[idx] = element
		else:
			__params.value.append(element)
	
	class map_type_params:
		func _init():
			var service
			
			__key = PBField.new("key", PB_DATA_TYPE.INT32, PB_RULE.REQUIRED, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
			__key.is_map_field = true
			service = PBServiceField.new()
			service.field = __key
			data[__key.tag] = service
			
			__value = PBField.new("value", PB_DATA_TYPE.STRING, PB_RULE.REQUIRED, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
			__value.is_map_field = true
			service = PBServiceField.new()
			service.field = __value
			data[__value.tag] = service
			
		var data = {}
		
		var __key: PBField
		func get_key() -> int:
			return __key.value
		func clear_key() -> void:
			data[1].state = PB_SERVICE_STATE.UNFILLED
			__key.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
		func set_key(value : int) -> void:
			__key.value = value
		
		var __value: PBField
		func get_value() -> String:
			return __value.value
		func clear_value() -> void:
			data[2].state = PB_SERVICE_STATE.UNFILLED
			__value.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
		func set_value(value : String) -> void:
			__value.value = value
		
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
	
enum HeroType {
	HeroNull = 0,
	JIN = 1,
	MU = 2,
	SHUI = 3,
	HUO = 4,
	TU = 5
}

enum TableState {
	InitTB = 0,
	OpenTB = 1,
	RepairTB = 2,
	ClearTB = 3,
	StopTB = 4,
	CloseTB = 5
}

enum GameType {
	General = 0,
	Fight = 1,
	Multiperson = 2,
	TableCard = 3,
	Guess = 4,
	GamesCity = 5,
	DualMeet = 6,
	Sport = 7,
	Smart = 8,
	RPG = 9
}

enum GameScene {
	Free = 0,
	Start = 1,
	Call = 2,
	Decide = 3,
	Playing = 4,
	Opening = 5,
	Over = 6,
	Closing = 7,
	SitDirect = 8,
	RollDice = 9,
	WaitOperate = 10,
	ChangeThree = 11,
	DingQue = 12,
	CheckTing = 13,
	CheckHuaZhu = 14
}

class UserInfo:
	func _init():
		var service
		
		__userID = PBField.new("userID", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __userID
		data[__userID.tag] = service
		
		__name = PBField.new("name", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __name
		data[__name.tag] = service
		
		__account = PBField.new("account", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __account
		data[__account.tag] = service
		
		__password = PBField.new("password", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __password
		data[__password.tag] = service
		
		__faceID = PBField.new("faceID", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 5, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __faceID
		data[__faceID.tag] = service
		
		__gender = PBField.new("gender", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 6, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __gender
		data[__gender.tag] = service
		
		__age = PBField.new("age", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 7, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __age
		data[__age.tag] = service
		
		__vIP = PBField.new("vIP", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 8, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __vIP
		data[__vIP.tag] = service
		
		__level = PBField.new("level", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 9, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __level
		data[__level.tag] = service
		
		__yuanBao = PBField.new("yuanBao", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 10, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __yuanBao
		data[__yuanBao.tag] = service
		
		__coin = PBField.new("coin", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 11, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __coin
		data[__coin.tag] = service
		
		__money = PBField.new("money", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 12, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __money
		data[__money.tag] = service
		
		__passPortID = PBField.new("passPortID", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 13, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __passPortID
		data[__passPortID.tag] = service
		
		__realName = PBField.new("realName", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 14, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __realName
		data[__realName.tag] = service
		
		__phoneNum = PBField.new("phoneNum", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 15, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __phoneNum
		data[__phoneNum.tag] = service
		
		__email = PBField.new("email", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 16, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __email
		data[__email.tag] = service
		
		__address = PBField.new("address", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 17, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __address
		data[__address.tag] = service
		
		__iDentity = PBField.new("iDentity", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 18, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __iDentity
		data[__iDentity.tag] = service
		
		__agentID = PBField.new("agentID", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 19, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __agentID
		data[__agentID.tag] = service
		
		__referralCode = PBField.new("referralCode", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 20, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __referralCode
		data[__referralCode.tag] = service
		
		__clientAddr = PBField.new("clientAddr", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 21, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __clientAddr
		data[__clientAddr.tag] = service
		
		__serverAddr = PBField.new("serverAddr", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 22, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __serverAddr
		data[__serverAddr.tag] = service
		
		__machineCode = PBField.new("machineCode", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 23, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __machineCode
		data[__machineCode.tag] = service
		
	var data = {}
	
	var __userID: PBField
	func get_userID() -> int:
		return __userID.value
	func clear_userID() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__userID.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_userID(value : int) -> void:
		__userID.value = value
	
	var __name: PBField
	func get_name() -> String:
		return __name.value
	func clear_name() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__name.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_name(value : String) -> void:
		__name.value = value
	
	var __account: PBField
	func get_account() -> String:
		return __account.value
	func clear_account() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__account.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_account(value : String) -> void:
		__account.value = value
	
	var __password: PBField
	func get_password() -> String:
		return __password.value
	func clear_password() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__password.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_password(value : String) -> void:
		__password.value = value
	
	var __faceID: PBField
	func get_faceID() -> int:
		return __faceID.value
	func clear_faceID() -> void:
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__faceID.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_faceID(value : int) -> void:
		__faceID.value = value
	
	var __gender: PBField
	func get_gender() -> int:
		return __gender.value
	func clear_gender() -> void:
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__gender.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_gender(value : int) -> void:
		__gender.value = value
	
	var __age: PBField
	func get_age() -> int:
		return __age.value
	func clear_age() -> void:
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__age.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_age(value : int) -> void:
		__age.value = value
	
	var __vIP: PBField
	func get_vIP() -> int:
		return __vIP.value
	func clear_vIP() -> void:
		data[8].state = PB_SERVICE_STATE.UNFILLED
		__vIP.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_vIP(value : int) -> void:
		__vIP.value = value
	
	var __level: PBField
	func get_level() -> int:
		return __level.value
	func clear_level() -> void:
		data[9].state = PB_SERVICE_STATE.UNFILLED
		__level.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_level(value : int) -> void:
		__level.value = value
	
	var __yuanBao: PBField
	func get_yuanBao() -> int:
		return __yuanBao.value
	func clear_yuanBao() -> void:
		data[10].state = PB_SERVICE_STATE.UNFILLED
		__yuanBao.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_yuanBao(value : int) -> void:
		__yuanBao.value = value
	
	var __coin: PBField
	func get_coin() -> int:
		return __coin.value
	func clear_coin() -> void:
		data[11].state = PB_SERVICE_STATE.UNFILLED
		__coin.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_coin(value : int) -> void:
		__coin.value = value
	
	var __money: PBField
	func get_money() -> int:
		return __money.value
	func clear_money() -> void:
		data[12].state = PB_SERVICE_STATE.UNFILLED
		__money.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_money(value : int) -> void:
		__money.value = value
	
	var __passPortID: PBField
	func get_passPortID() -> String:
		return __passPortID.value
	func clear_passPortID() -> void:
		data[13].state = PB_SERVICE_STATE.UNFILLED
		__passPortID.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_passPortID(value : String) -> void:
		__passPortID.value = value
	
	var __realName: PBField
	func get_realName() -> String:
		return __realName.value
	func clear_realName() -> void:
		data[14].state = PB_SERVICE_STATE.UNFILLED
		__realName.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_realName(value : String) -> void:
		__realName.value = value
	
	var __phoneNum: PBField
	func get_phoneNum() -> String:
		return __phoneNum.value
	func clear_phoneNum() -> void:
		data[15].state = PB_SERVICE_STATE.UNFILLED
		__phoneNum.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_phoneNum(value : String) -> void:
		__phoneNum.value = value
	
	var __email: PBField
	func get_email() -> String:
		return __email.value
	func clear_email() -> void:
		data[16].state = PB_SERVICE_STATE.UNFILLED
		__email.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_email(value : String) -> void:
		__email.value = value
	
	var __address: PBField
	func get_address() -> String:
		return __address.value
	func clear_address() -> void:
		data[17].state = PB_SERVICE_STATE.UNFILLED
		__address.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_address(value : String) -> void:
		__address.value = value
	
	var __iDentity: PBField
	func get_iDentity() -> String:
		return __iDentity.value
	func clear_iDentity() -> void:
		data[18].state = PB_SERVICE_STATE.UNFILLED
		__iDentity.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_iDentity(value : String) -> void:
		__iDentity.value = value
	
	var __agentID: PBField
	func get_agentID() -> int:
		return __agentID.value
	func clear_agentID() -> void:
		data[19].state = PB_SERVICE_STATE.UNFILLED
		__agentID.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_agentID(value : int) -> void:
		__agentID.value = value
	
	var __referralCode: PBField
	func get_referralCode() -> String:
		return __referralCode.value
	func clear_referralCode() -> void:
		data[20].state = PB_SERVICE_STATE.UNFILLED
		__referralCode.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_referralCode(value : String) -> void:
		__referralCode.value = value
	
	var __clientAddr: PBField
	func get_clientAddr() -> String:
		return __clientAddr.value
	func clear_clientAddr() -> void:
		data[21].state = PB_SERVICE_STATE.UNFILLED
		__clientAddr.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_clientAddr(value : String) -> void:
		__clientAddr.value = value
	
	var __serverAddr: PBField
	func get_serverAddr() -> String:
		return __serverAddr.value
	func clear_serverAddr() -> void:
		data[22].state = PB_SERVICE_STATE.UNFILLED
		__serverAddr.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_serverAddr(value : String) -> void:
		__serverAddr.value = value
	
	var __machineCode: PBField
	func get_machineCode() -> String:
		return __machineCode.value
	func clear_machineCode() -> void:
		data[23].state = PB_SERVICE_STATE.UNFILLED
		__machineCode.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_machineCode(value : String) -> void:
		__machineCode.value = value
	
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
		
		__iD = PBField.new("iD", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __iD
		data[__iD.tag] = service
		
		__headId = PBField.new("headId", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __headId
		data[__headId.tag] = service
		
		__name = PBField.new("name", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __name
		data[__name.tag] = service
		
		__sex = PBField.new("sex", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __sex
		data[__sex.tag] = service
		
		__rarity = PBField.new("rarity", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 5, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __rarity
		data[__rarity.tag] = service
		
		__faction = PBField.new("faction", PB_DATA_TYPE.ENUM, PB_RULE.OPTIONAL, 6, true, DEFAULT_VALUES_3[PB_DATA_TYPE.ENUM])
		service = PBServiceField.new()
		service.field = __faction
		data[__faction.tag] = service
		
		__healthPoint = PBField.new("healthPoint", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 7, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __healthPoint
		data[__healthPoint.tag] = service
		
		__healthPointFull = PBField.new("healthPointFull", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 8, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __healthPointFull
		data[__healthPointFull.tag] = service
		
		__strength = PBField.new("strength", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 9, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __strength
		data[__strength.tag] = service
		
		__agility = PBField.new("agility", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 10, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __agility
		data[__agility.tag] = service
		
		__intelligence = PBField.new("intelligence", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 11, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __intelligence
		data[__intelligence.tag] = service
		
		__attackPoint = PBField.new("attackPoint", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 12, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __attackPoint
		data[__attackPoint.tag] = service
		
		__armorPoint = PBField.new("armorPoint", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 13, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __armorPoint
		data[__armorPoint.tag] = service
		
		__spellPower = PBField.new("spellPower", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 14, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __spellPower
		data[__spellPower.tag] = service
		
		var __skills_default: Array[int] = []
		__skills = PBField.new("skills", PB_DATA_TYPE.INT64, PB_RULE.REPEATED, 15, true, __skills_default)
		service = PBServiceField.new()
		service.field = __skills
		data[__skills.tag] = service
		
	var data = {}
	
	var __iD: PBField
	func get_iD() -> int:
		return __iD.value
	func clear_iD() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__iD.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_iD(value : int) -> void:
		__iD.value = value
	
	var __headId: PBField
	func get_headId() -> int:
		return __headId.value
	func clear_headId() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__headId.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_headId(value : int) -> void:
		__headId.value = value
	
	var __name: PBField
	func get_name() -> String:
		return __name.value
	func clear_name() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__name.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_name(value : String) -> void:
		__name.value = value
	
	var __sex: PBField
	func get_sex() -> int:
		return __sex.value
	func clear_sex() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__sex.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_sex(value : int) -> void:
		__sex.value = value
	
	var __rarity: PBField
	func get_rarity() -> int:
		return __rarity.value
	func clear_rarity() -> void:
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__rarity.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_rarity(value : int) -> void:
		__rarity.value = value
	
	var __faction: PBField
	func get_faction():
		return __faction.value
	func clear_faction() -> void:
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__faction.value = DEFAULT_VALUES_3[PB_DATA_TYPE.ENUM]
	func set_faction(value) -> void:
		__faction.value = value
	
	var __healthPoint: PBField
	func get_healthPoint() -> int:
		return __healthPoint.value
	func clear_healthPoint() -> void:
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__healthPoint.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_healthPoint(value : int) -> void:
		__healthPoint.value = value
	
	var __healthPointFull: PBField
	func get_healthPointFull() -> int:
		return __healthPointFull.value
	func clear_healthPointFull() -> void:
		data[8].state = PB_SERVICE_STATE.UNFILLED
		__healthPointFull.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_healthPointFull(value : int) -> void:
		__healthPointFull.value = value
	
	var __strength: PBField
	func get_strength() -> int:
		return __strength.value
	func clear_strength() -> void:
		data[9].state = PB_SERVICE_STATE.UNFILLED
		__strength.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_strength(value : int) -> void:
		__strength.value = value
	
	var __agility: PBField
	func get_agility() -> int:
		return __agility.value
	func clear_agility() -> void:
		data[10].state = PB_SERVICE_STATE.UNFILLED
		__agility.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_agility(value : int) -> void:
		__agility.value = value
	
	var __intelligence: PBField
	func get_intelligence() -> int:
		return __intelligence.value
	func clear_intelligence() -> void:
		data[11].state = PB_SERVICE_STATE.UNFILLED
		__intelligence.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_intelligence(value : int) -> void:
		__intelligence.value = value
	
	var __attackPoint: PBField
	func get_attackPoint() -> int:
		return __attackPoint.value
	func clear_attackPoint() -> void:
		data[12].state = PB_SERVICE_STATE.UNFILLED
		__attackPoint.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_attackPoint(value : int) -> void:
		__attackPoint.value = value
	
	var __armorPoint: PBField
	func get_armorPoint() -> int:
		return __armorPoint.value
	func clear_armorPoint() -> void:
		data[13].state = PB_SERVICE_STATE.UNFILLED
		__armorPoint.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_armorPoint(value : int) -> void:
		__armorPoint.value = value
	
	var __spellPower: PBField
	func get_spellPower() -> int:
		return __spellPower.value
	func clear_spellPower() -> void:
		data[14].state = PB_SERVICE_STATE.UNFILLED
		__spellPower.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_spellPower(value : int) -> void:
		__spellPower.value = value
	
	var __skills: PBField
	func get_skills() -> Array[int]:
		return __skills.value
	func clear_skills() -> void:
		data[15].state = PB_SERVICE_STATE.UNFILLED
		__skills.value = []
	func add_skills(value : int) -> void:
		__skills.value.append(value)
	
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
		
		__iD = PBField.new("iD", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __iD
		data[__iD.tag] = service
		
		__name = PBField.new("name", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __name
		data[__name.tag] = service
		
		__type = PBField.new("type", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __type
		data[__type.tag] = service
		
		__level = PBField.new("level", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __level
		data[__level.tag] = service
		
		__damage = PBField.new("damage", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 5, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __damage
		data[__damage.tag] = service
		
		__prob = PBField.new("prob", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 6, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __prob
		data[__prob.tag] = service
		
		__count = PBField.new("count", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 7, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __count
		data[__count.tag] = service
		
	var data = {}
	
	var __iD: PBField
	func get_iD() -> int:
		return __iD.value
	func clear_iD() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__iD.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_iD(value : int) -> void:
		__iD.value = value
	
	var __name: PBField
	func get_name() -> String:
		return __name.value
	func clear_name() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__name.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_name(value : String) -> void:
		__name.value = value
	
	var __type: PBField
	func get_type() -> int:
		return __type.value
	func clear_type() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__type.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_type(value : int) -> void:
		__type.value = value
	
	var __level: PBField
	func get_level() -> int:
		return __level.value
	func clear_level() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__level.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_level(value : int) -> void:
		__level.value = value
	
	var __damage: PBField
	func get_damage() -> int:
		return __damage.value
	func clear_damage() -> void:
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__damage.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_damage(value : int) -> void:
		__damage.value = value
	
	var __prob: PBField
	func get_prob() -> int:
		return __prob.value
	func clear_prob() -> void:
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__prob.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_prob(value : int) -> void:
		__prob.value = value
	
	var __count: PBField
	func get_count() -> int:
		return __count.value
	func clear_count() -> void:
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__count.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_count(value : int) -> void:
		__count.value = value
	
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
		
		__iD = PBField.new("iD", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __iD
		data[__iD.tag] = service
		
		__name = PBField.new("name", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __name
		data[__name.tag] = service
		
		__kind = PBField.new("kind", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __kind
		data[__kind.tag] = service
		
		__level = PBField.new("level", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __level
		data[__level.tag] = service
		
		__price = PBField.new("price", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 5, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __price
		data[__price.tag] = service
		
		__store = PBField.new("store", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 6, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __store
		data[__store.tag] = service
		
		__sold = PBField.new("sold", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 7, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __sold
		data[__sold.tag] = service
		
		__amount = PBField.new("amount", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 8, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __amount
		data[__amount.tag] = service
		
	var data = {}
	
	var __iD: PBField
	func get_iD() -> int:
		return __iD.value
	func clear_iD() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__iD.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_iD(value : int) -> void:
		__iD.value = value
	
	var __name: PBField
	func get_name() -> String:
		return __name.value
	func clear_name() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__name.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_name(value : String) -> void:
		__name.value = value
	
	var __kind: PBField
	func get_kind() -> int:
		return __kind.value
	func clear_kind() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__kind.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_kind(value : int) -> void:
		__kind.value = value
	
	var __level: PBField
	func get_level() -> int:
		return __level.value
	func clear_level() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__level.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_level(value : int) -> void:
		__level.value = value
	
	var __price: PBField
	func get_price() -> int:
		return __price.value
	func clear_price() -> void:
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__price.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_price(value : int) -> void:
		__price.value = value
	
	var __store: PBField
	func get_store() -> int:
		return __store.value
	func clear_store() -> void:
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__store.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_store(value : int) -> void:
		__store.value = value
	
	var __sold: PBField
	func get_sold() -> int:
		return __sold.value
	func clear_sold() -> void:
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__sold.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_sold(value : int) -> void:
		__sold.value = value
	
	var __amount: PBField
	func get_amount() -> int:
		return __amount.value
	func clear_amount() -> void:
		data[8].state = PB_SERVICE_STATE.UNFILLED
		__amount.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_amount(value : int) -> void:
		__amount.value = value
	
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
		
		var __allGoods_default: Array[GoodsInfo] = []
		__allGoods = PBField.new("allGoods", PB_DATA_TYPE.MESSAGE, PB_RULE.REPEATED, 1, true, __allGoods_default)
		service = PBServiceField.new()
		service.field = __allGoods
		service.func_ref = Callable(self, "add_allGoods")
		data[__allGoods.tag] = service
		
	var data = {}
	
	var __allGoods: PBField
	func get_allGoods() -> Array[GoodsInfo]:
		return __allGoods.value
	func clear_allGoods() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__allGoods.value = []
	func add_allGoods() -> GoodsInfo:
		var element = GoodsInfo.new()
		__allGoods.value.append(element)
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
		
		__iD = PBField.new("iD", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __iD
		data[__iD.tag] = service
		
		__name = PBField.new("name", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __name
		data[__name.tag] = service
		
		var __myWeaponry_default: Array[WeaponInfo] = []
		__myWeaponry = PBField.new("myWeaponry", PB_DATA_TYPE.MESSAGE, PB_RULE.REPEATED, 3, true, __myWeaponry_default)
		service = PBServiceField.new()
		service.field = __myWeaponry
		service.func_ref = Callable(self, "add_myWeaponry")
		data[__myWeaponry.tag] = service
		
		var __myGoods_default: Array[GoodsInfo] = []
		__myGoods = PBField.new("myGoods", PB_DATA_TYPE.MESSAGE, PB_RULE.REPEATED, 4, true, __myGoods_default)
		service = PBServiceField.new()
		service.field = __myGoods
		service.func_ref = Callable(self, "add_myGoods")
		data[__myGoods.tag] = service
		
		var __myHeroList_default: Array[HeroInfo] = []
		__myHeroList = PBField.new("myHeroList", PB_DATA_TYPE.MESSAGE, PB_RULE.REPEATED, 5, true, __myHeroList_default)
		service = PBServiceField.new()
		service.field = __myHeroList
		service.func_ref = Callable(self, "add_myHeroList")
		data[__myHeroList.tag] = service
		
		__number = PBField.new("number", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 6, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __number
		data[__number.tag] = service
		
	var data = {}
	
	var __iD: PBField
	func get_iD() -> int:
		return __iD.value
	func clear_iD() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__iD.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_iD(value : int) -> void:
		__iD.value = value
	
	var __name: PBField
	func get_name() -> String:
		return __name.value
	func clear_name() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__name.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_name(value : String) -> void:
		__name.value = value
	
	var __myWeaponry: PBField
	func get_myWeaponry() -> Array[WeaponInfo]:
		return __myWeaponry.value
	func clear_myWeaponry() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__myWeaponry.value = []
	func add_myWeaponry() -> WeaponInfo:
		var element = WeaponInfo.new()
		__myWeaponry.value.append(element)
		return element
	
	var __myGoods: PBField
	func get_myGoods() -> Array[GoodsInfo]:
		return __myGoods.value
	func clear_myGoods() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__myGoods.value = []
	func add_myGoods() -> GoodsInfo:
		var element = GoodsInfo.new()
		__myGoods.value.append(element)
		return element
	
	var __myHeroList: PBField
	func get_myHeroList() -> Array[HeroInfo]:
		return __myHeroList.value
	func clear_myHeroList() -> void:
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__myHeroList.value = []
	func add_myHeroList() -> HeroInfo:
		var element = HeroInfo.new()
		__myHeroList.value.append(element)
		return element
	
	var __number: PBField
	func get_number() -> int:
		return __number.value
	func clear_number() -> void:
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__number.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_number(value : int) -> void:
		__number.value = value
	
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
		
		__emailID = PBField.new("emailID", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __emailID
		data[__emailID.tag] = service
		
		__acceptName = PBField.new("acceptName", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __acceptName
		data[__acceptName.tag] = service
		
		__sender = PBField.new("sender", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __sender
		data[__sender.tag] = service
		
		__cc = PBField.new("cc", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __cc
		data[__cc.tag] = service
		
		__topic = PBField.new("topic", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 5, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __topic
		data[__topic.tag] = service
		
		__content = PBField.new("content", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 6, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __content
		data[__content.tag] = service
		
		__isRead = PBField.new("isRead", PB_DATA_TYPE.BOOL, PB_RULE.OPTIONAL, 7, true, DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL])
		service = PBServiceField.new()
		service.field = __isRead
		data[__isRead.tag] = service
		
		__awardList = PBField.new("awardList", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 8, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __awardList
		service.func_ref = Callable(self, "new_awardList")
		data[__awardList.tag] = service
		
		__timeStamp = PBField.new("timeStamp", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 9, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __timeStamp
		data[__timeStamp.tag] = service
		
	var data = {}
	
	var __emailID: PBField
	func get_emailID() -> int:
		return __emailID.value
	func clear_emailID() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__emailID.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_emailID(value : int) -> void:
		__emailID.value = value
	
	var __acceptName: PBField
	func get_acceptName() -> String:
		return __acceptName.value
	func clear_acceptName() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__acceptName.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_acceptName(value : String) -> void:
		__acceptName.value = value
	
	var __sender: PBField
	func get_sender() -> String:
		return __sender.value
	func clear_sender() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__sender.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_sender(value : String) -> void:
		__sender.value = value
	
	var __cc: PBField
	func get_cc() -> String:
		return __cc.value
	func clear_cc() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__cc.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_cc(value : String) -> void:
		__cc.value = value
	
	var __topic: PBField
	func get_topic() -> String:
		return __topic.value
	func clear_topic() -> void:
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__topic.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_topic(value : String) -> void:
		__topic.value = value
	
	var __content: PBField
	func get_content() -> String:
		return __content.value
	func clear_content() -> void:
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__content.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_content(value : String) -> void:
		__content.value = value
	
	var __isRead: PBField
	func get_isRead() -> bool:
		return __isRead.value
	func clear_isRead() -> void:
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__isRead.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL]
	func set_isRead(value : bool) -> void:
		__isRead.value = value
	
	var __awardList: PBField
	func get_awardList() -> GoodsList:
		return __awardList.value
	func clear_awardList() -> void:
		data[8].state = PB_SERVICE_STATE.UNFILLED
		__awardList.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_awardList() -> GoodsList:
		__awardList.value = GoodsList.new()
		return __awardList.value
	
	var __timeStamp: PBField
	func get_timeStamp() -> int:
		return __timeStamp.value
	func clear_timeStamp() -> void:
		data[9].state = PB_SERVICE_STATE.UNFILLED
		__timeStamp.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_timeStamp(value : int) -> void:
		__timeStamp.value = value
	
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
	
class TableInfo:
	func _init():
		var service
		
		__hostID = PBField.new("hostID", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __hostID
		data[__hostID.tag] = service
		
		__name = PBField.new("name", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __name
		data[__name.tag] = service
		
		__password = PBField.new("password", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __password
		data[__password.tag] = service
		
		__state = PBField.new("state", PB_DATA_TYPE.ENUM, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.ENUM])
		service = PBServiceField.new()
		service.field = __state
		data[__state.tag] = service
		
		__enterScore = PBField.new("enterScore", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 5, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __enterScore
		data[__enterScore.tag] = service
		
		__lessScore = PBField.new("lessScore", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 6, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __lessScore
		data[__lessScore.tag] = service
		
		__playScore = PBField.new("playScore", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 7, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __playScore
		data[__playScore.tag] = service
		
		__commission = PBField.new("commission", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 8, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __commission
		data[__commission.tag] = service
		
		__maxChair = PBField.new("maxChair", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 9, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __maxChair
		data[__maxChair.tag] = service
		
		__amount = PBField.new("amount", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 10, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __amount
		data[__amount.tag] = service
		
		__maxOnline = PBField.new("maxOnline", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 11, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __maxOnline
		data[__maxOnline.tag] = service
		
		__robotCount = PBField.new("robotCount", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 12, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __robotCount
		data[__robotCount.tag] = service
		
	var data = {}
	
	var __hostID: PBField
	func get_hostID() -> int:
		return __hostID.value
	func clear_hostID() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__hostID.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_hostID(value : int) -> void:
		__hostID.value = value
	
	var __name: PBField
	func get_name() -> String:
		return __name.value
	func clear_name() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__name.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_name(value : String) -> void:
		__name.value = value
	
	var __password: PBField
	func get_password() -> String:
		return __password.value
	func clear_password() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__password.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_password(value : String) -> void:
		__password.value = value
	
	var __state: PBField
	func get_state():
		return __state.value
	func clear_state() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__state.value = DEFAULT_VALUES_3[PB_DATA_TYPE.ENUM]
	func set_state(value) -> void:
		__state.value = value
	
	var __enterScore: PBField
	func get_enterScore() -> int:
		return __enterScore.value
	func clear_enterScore() -> void:
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__enterScore.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_enterScore(value : int) -> void:
		__enterScore.value = value
	
	var __lessScore: PBField
	func get_lessScore() -> int:
		return __lessScore.value
	func clear_lessScore() -> void:
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__lessScore.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_lessScore(value : int) -> void:
		__lessScore.value = value
	
	var __playScore: PBField
	func get_playScore() -> int:
		return __playScore.value
	func clear_playScore() -> void:
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__playScore.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_playScore(value : int) -> void:
		__playScore.value = value
	
	var __commission: PBField
	func get_commission() -> int:
		return __commission.value
	func clear_commission() -> void:
		data[8].state = PB_SERVICE_STATE.UNFILLED
		__commission.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_commission(value : int) -> void:
		__commission.value = value
	
	var __maxChair: PBField
	func get_maxChair() -> int:
		return __maxChair.value
	func clear_maxChair() -> void:
		data[9].state = PB_SERVICE_STATE.UNFILLED
		__maxChair.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_maxChair(value : int) -> void:
		__maxChair.value = value
	
	var __amount: PBField
	func get_amount() -> int:
		return __amount.value
	func clear_amount() -> void:
		data[10].state = PB_SERVICE_STATE.UNFILLED
		__amount.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_amount(value : int) -> void:
		__amount.value = value
	
	var __maxOnline: PBField
	func get_maxOnline() -> int:
		return __maxOnline.value
	func clear_maxOnline() -> void:
		data[11].state = PB_SERVICE_STATE.UNFILLED
		__maxOnline.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_maxOnline(value : int) -> void:
		__maxOnline.value = value
	
	var __robotCount: PBField
	func get_robotCount() -> int:
		return __robotCount.value
	func clear_robotCount() -> void:
		data[12].state = PB_SERVICE_STATE.UNFILLED
		__robotCount.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_robotCount(value : int) -> void:
		__robotCount.value = value
	
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
	
class GameInfo:
	func _init():
		var service
		
		__type = PBField.new("type", PB_DATA_TYPE.ENUM, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.ENUM])
		service = PBServiceField.new()
		service.field = __type
		data[__type.tag] = service
		
		__kindID = PBField.new("kindID", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __kindID
		data[__kindID.tag] = service
		
		__level = PBField.new("level", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __level
		data[__level.tag] = service
		
		__scene = PBField.new("scene", PB_DATA_TYPE.ENUM, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.ENUM])
		service = PBServiceField.new()
		service.field = __scene
		data[__scene.tag] = service
		
		__name = PBField.new("name", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 5, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __name
		data[__name.tag] = service
		
	var data = {}
	
	var __type: PBField
	func get_type():
		return __type.value
	func clear_type() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__type.value = DEFAULT_VALUES_3[PB_DATA_TYPE.ENUM]
	func set_type(value) -> void:
		__type.value = value
	
	var __kindID: PBField
	func get_kindID() -> int:
		return __kindID.value
	func clear_kindID() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__kindID.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
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
	
	var __scene: PBField
	func get_scene():
		return __scene.value
	func clear_scene() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__scene.value = DEFAULT_VALUES_3[PB_DATA_TYPE.ENUM]
	func set_scene(value) -> void:
		__scene.value = value
	
	var __name: PBField
	func get_name() -> String:
		return __name.value
	func clear_name() -> void:
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__name.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_name(value : String) -> void:
		__name.value = value
	
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
	
class TaskItem:
	func _init():
		var service
		
		__iD = PBField.new("iD", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __iD
		data[__iD.tag] = service
		
		__twice = PBField.new("twice", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __twice
		data[__twice.tag] = service
		
		__hints = PBField.new("hints", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __hints
		data[__hints.tag] = service
		
	var data = {}
	
	var __iD: PBField
	func get_iD() -> int:
		return __iD.value
	func clear_iD() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__iD.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_iD(value : int) -> void:
		__iD.value = value
	
	var __twice: PBField
	func get_twice() -> int:
		return __twice.value
	func clear_twice() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__twice.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_twice(value : int) -> void:
		__twice.value = value
	
	var __hints: PBField
	func get_hints() -> String:
		return __hints.value
	func clear_hints() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
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
	
class ClassItem:
	func _init():
		var service
		
		__iD = PBField.new("iD", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __iD
		data[__iD.tag] = service
		
		__name = PBField.new("name", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __name
		data[__name.tag] = service
		
		__key = PBField.new("key", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __key
		data[__key.tag] = service
		
	var data = {}
	
	var __iD: PBField
	func get_iD() -> int:
		return __iD.value
	func clear_iD() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__iD.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_iD(value : int) -> void:
		__iD.value = value
	
	var __name: PBField
	func get_name() -> String:
		return __name.value
	func clear_name() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__name.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_name(value : String) -> void:
		__name.value = value
	
	var __key: PBField
	func get_key() -> String:
		return __key.value
	func clear_key() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__key.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_key(value : String) -> void:
		__key.value = value
	
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
	
class GameItem:
	func _init():
		var service
		
		__iD = PBField.new("iD", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __iD
		data[__iD.tag] = service
		
		__info = PBField.new("info", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __info
		service.func_ref = Callable(self, "new_info")
		data[__info.tag] = service
		
	var data = {}
	
	var __iD: PBField
	func get_iD() -> int:
		return __iD.value
	func clear_iD() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__iD.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_iD(value : int) -> void:
		__iD.value = value
	
	var __info: PBField
	func get_info() -> GameInfo:
		return __info.value
	func clear_info() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__info.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_info() -> GameInfo:
		__info.value = GameInfo.new()
		return __info.value
	
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
	
class TableItem:
	func _init():
		var service
		
		__num = PBField.new("num", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __num
		data[__num.tag] = service
		
		__gameID = PBField.new("gameID", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __gameID
		data[__gameID.tag] = service
		
		__info = PBField.new("info", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __info
		service.func_ref = Callable(self, "new_info")
		data[__info.tag] = service
		
	var data = {}
	
	var __num: PBField
	func get_num() -> int:
		return __num.value
	func clear_num() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__num.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_num(value : int) -> void:
		__num.value = value
	
	var __gameID: PBField
	func get_gameID() -> int:
		return __gameID.value
	func clear_gameID() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__gameID.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_gameID(value : int) -> void:
		__gameID.value = value
	
	var __info: PBField
	func get_info() -> TableInfo:
		return __info.value
	func clear_info() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__info.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_info() -> TableInfo:
		__info.value = TableInfo.new()
		return __info.value
	
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
	
class TaskList:
	func _init():
		var service
		
		var __task_default: Array[TaskItem] = []
		__task = PBField.new("task", PB_DATA_TYPE.MESSAGE, PB_RULE.REPEATED, 1, true, __task_default)
		service = PBServiceField.new()
		service.field = __task
		service.func_ref = Callable(self, "add_task")
		data[__task.tag] = service
		
	var data = {}
	
	var __task: PBField
	func get_task() -> Array[TaskItem]:
		return __task.value
	func clear_task() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__task.value = []
	func add_task() -> TaskItem:
		var element = TaskItem.new()
		__task.value.append(element)
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
	
class ClassList:
	func _init():
		var service
		
		var __classify_default: Array[ClassItem] = []
		__classify = PBField.new("classify", PB_DATA_TYPE.MESSAGE, PB_RULE.REPEATED, 1, true, __classify_default)
		service = PBServiceField.new()
		service.field = __classify
		service.func_ref = Callable(self, "add_classify")
		data[__classify.tag] = service
		
	var data = {}
	
	var __classify: PBField
	func get_classify() -> Array[ClassItem]:
		return __classify.value
	func clear_classify() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__classify.value = []
	func add_classify() -> ClassItem:
		var element = ClassItem.new()
		__classify.value.append(element)
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
	
class GameList:
	func _init():
		var service
		
		var __items_default: Array[GameItem] = []
		__items = PBField.new("items", PB_DATA_TYPE.MESSAGE, PB_RULE.REPEATED, 1, true, __items_default)
		service = PBServiceField.new()
		service.field = __items
		service.func_ref = Callable(self, "add_items")
		data[__items.tag] = service
		
	var data = {}
	
	var __items: PBField
	func get_items() -> Array[GameItem]:
		return __items.value
	func clear_items() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__items.value = []
	func add_items() -> GameItem:
		var element = GameItem.new()
		__items.value.append(element)
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
	
class TableList:
	func _init():
		var service
		
		var __items_default: Array[TableItem] = []
		__items = PBField.new("items", PB_DATA_TYPE.MESSAGE, PB_RULE.REPEATED, 1, true, __items_default)
		service = PBServiceField.new()
		service.field = __items
		service.func_ref = Callable(self, "add_items")
		data[__items.tag] = service
		
	var data = {}
	
	var __items: PBField
	func get_items() -> Array[TableItem]:
		return __items.value
	func clear_items() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__items.value = []
	func add_items() -> TableItem:
		var element = TableItem.new()
		__items.value.append(element)
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
	
class MasterInfo:
	func _init():
		var service
		
		__userInfo = PBField.new("userInfo", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __userInfo
		service.func_ref = Callable(self, "new_userInfo")
		data[__userInfo.tag] = service
		
		__classes = PBField.new("classes", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __classes
		service.func_ref = Callable(self, "new_classes")
		data[__classes.tag] = service
		
		__tasks = PBField.new("tasks", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __tasks
		service.func_ref = Callable(self, "new_tasks")
		data[__tasks.tag] = service
		
	var data = {}
	
	var __userInfo: PBField
	func get_userInfo() -> UserInfo:
		return __userInfo.value
	func clear_userInfo() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__userInfo.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_userInfo() -> UserInfo:
		__userInfo.value = UserInfo.new()
		return __userInfo.value
	
	var __classes: PBField
	func get_classes() -> ClassList:
		return __classes.value
	func clear_classes() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__classes.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_classes() -> ClassList:
		__classes.value = ClassList.new()
		return __classes.value
	
	var __tasks: PBField
	func get_tasks() -> TaskList:
		return __tasks.value
	func clear_tasks() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__tasks.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_tasks() -> TaskList:
		__tasks.value = TaskList.new()
		return __tasks.value
	
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
		
		__name = PBField.new("name", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __name
		data[__name.tag] = service
		
		__password = PBField.new("password", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __password
		data[__password.tag] = service
		
		__securityCode = PBField.new("securityCode", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __securityCode
		data[__securityCode.tag] = service
		
		__machineCode = PBField.new("machineCode", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __machineCode
		data[__machineCode.tag] = service
		
		__invitationCode = PBField.new("invitationCode", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 5, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __invitationCode
		data[__invitationCode.tag] = service
		
		__platformID = PBField.new("platformID", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 6, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __platformID
		data[__platformID.tag] = service
		
		__gender = PBField.new("gender", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 7, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __gender
		data[__gender.tag] = service
		
		__age = PBField.new("age", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 8, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __age
		data[__age.tag] = service
		
		__faceID = PBField.new("faceID", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 9, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __faceID
		data[__faceID.tag] = service
		
		__passPortID = PBField.new("passPortID", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 10, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __passPortID
		data[__passPortID.tag] = service
		
		__realName = PBField.new("realName", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 11, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __realName
		data[__realName.tag] = service
		
		__phoneNum = PBField.new("phoneNum", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 12, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __phoneNum
		data[__phoneNum.tag] = service
		
		__email = PBField.new("email", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 13, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __email
		data[__email.tag] = service
		
		__address = PBField.new("address", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 14, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __address
		data[__address.tag] = service
		
	var data = {}
	
	var __name: PBField
	func get_name() -> String:
		return __name.value
	func clear_name() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__name.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_name(value : String) -> void:
		__name.value = value
	
	var __password: PBField
	func get_password() -> String:
		return __password.value
	func clear_password() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__password.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_password(value : String) -> void:
		__password.value = value
	
	var __securityCode: PBField
	func get_securityCode() -> String:
		return __securityCode.value
	func clear_securityCode() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__securityCode.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_securityCode(value : String) -> void:
		__securityCode.value = value
	
	var __machineCode: PBField
	func get_machineCode() -> String:
		return __machineCode.value
	func clear_machineCode() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__machineCode.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_machineCode(value : String) -> void:
		__machineCode.value = value
	
	var __invitationCode: PBField
	func get_invitationCode() -> String:
		return __invitationCode.value
	func clear_invitationCode() -> void:
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__invitationCode.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_invitationCode(value : String) -> void:
		__invitationCode.value = value
	
	var __platformID: PBField
	func get_platformID() -> int:
		return __platformID.value
	func clear_platformID() -> void:
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__platformID.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_platformID(value : int) -> void:
		__platformID.value = value
	
	var __gender: PBField
	func get_gender() -> int:
		return __gender.value
	func clear_gender() -> void:
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__gender.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_gender(value : int) -> void:
		__gender.value = value
	
	var __age: PBField
	func get_age() -> int:
		return __age.value
	func clear_age() -> void:
		data[8].state = PB_SERVICE_STATE.UNFILLED
		__age.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_age(value : int) -> void:
		__age.value = value
	
	var __faceID: PBField
	func get_faceID() -> int:
		return __faceID.value
	func clear_faceID() -> void:
		data[9].state = PB_SERVICE_STATE.UNFILLED
		__faceID.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_faceID(value : int) -> void:
		__faceID.value = value
	
	var __passPortID: PBField
	func get_passPortID() -> String:
		return __passPortID.value
	func clear_passPortID() -> void:
		data[10].state = PB_SERVICE_STATE.UNFILLED
		__passPortID.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_passPortID(value : String) -> void:
		__passPortID.value = value
	
	var __realName: PBField
	func get_realName() -> String:
		return __realName.value
	func clear_realName() -> void:
		data[11].state = PB_SERVICE_STATE.UNFILLED
		__realName.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_realName(value : String) -> void:
		__realName.value = value
	
	var __phoneNum: PBField
	func get_phoneNum() -> String:
		return __phoneNum.value
	func clear_phoneNum() -> void:
		data[12].state = PB_SERVICE_STATE.UNFILLED
		__phoneNum.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_phoneNum(value : String) -> void:
		__phoneNum.value = value
	
	var __email: PBField
	func get_email() -> String:
		return __email.value
	func clear_email() -> void:
		data[13].state = PB_SERVICE_STATE.UNFILLED
		__email.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_email(value : String) -> void:
		__email.value = value
	
	var __address: PBField
	func get_address() -> String:
		return __address.value
	func clear_address() -> void:
		data[14].state = PB_SERVICE_STATE.UNFILLED
		__address.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_address(value : String) -> void:
		__address.value = value
	
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
		
		__sdkId = PBField.new("sdkId", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __sdkId
		data[__sdkId.tag] = service
		
		__pid = PBField.new("pid", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __pid
		data[__pid.tag] = service
		
		__openId = PBField.new("openId", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __openId
		data[__openId.tag] = service
		
		__serverId = PBField.new("serverId", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 5, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __serverId
		data[__serverId.tag] = service
		
		__ip = PBField.new("ip", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 6, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __ip
		data[__ip.tag] = service
		
	var data = {}
	
	var __sdkId: PBField
	func get_sdkId() -> int:
		return __sdkId.value
	func clear_sdkId() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__sdkId.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_sdkId(value : int) -> void:
		__sdkId.value = value
	
	var __pid: PBField
	func get_pid() -> int:
		return __pid.value
	func clear_pid() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__pid.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_pid(value : int) -> void:
		__pid.value = value
	
	var __openId: PBField
	func get_openId() -> String:
		return __openId.value
	func clear_openId() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__openId.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_openId(value : String) -> void:
		__openId.value = value
	
	var __serverId: PBField
	func get_serverId() -> int:
		return __serverId.value
	func clear_serverId() -> void:
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__serverId.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_serverId(value : int) -> void:
		__serverId.value = value
	
	var __ip: PBField
	func get_ip() -> String:
		return __ip.value
	func clear_ip() -> void:
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__ip.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_ip(value : String) -> void:
		__ip.value = value
	
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
		
		__account = PBField.new("account", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __account
		data[__account.tag] = service
		
		__password = PBField.new("password", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __password
		data[__password.tag] = service
		
		__securityCode = PBField.new("securityCode", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __securityCode
		data[__securityCode.tag] = service
		
		__machineCode = PBField.new("machineCode", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __machineCode
		data[__machineCode.tag] = service
		
		__platformID = PBField.new("platformID", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 5, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __platformID
		data[__platformID.tag] = service
		
	var data = {}
	
	var __account: PBField
	func get_account() -> String:
		return __account.value
	func clear_account() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__account.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_account(value : String) -> void:
		__account.value = value
	
	var __password: PBField
	func get_password() -> String:
		return __password.value
	func clear_password() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__password.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_password(value : String) -> void:
		__password.value = value
	
	var __securityCode: PBField
	func get_securityCode() -> String:
		return __securityCode.value
	func clear_securityCode() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__securityCode.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_securityCode(value : String) -> void:
		__securityCode.value = value
	
	var __machineCode: PBField
	func get_machineCode() -> String:
		return __machineCode.value
	func clear_machineCode() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__machineCode.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_machineCode(value : String) -> void:
		__machineCode.value = value
	
	var __platformID: PBField
	func get_platformID() -> int:
		return __platformID.value
	func clear_platformID() -> void:
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__platformID.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_platformID(value : int) -> void:
		__platformID.value = value
	
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
		
		__mainInfo = PBField.new("mainInfo", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __mainInfo
		service.func_ref = Callable(self, "new_mainInfo")
		data[__mainInfo.tag] = service
		
		__inGameID = PBField.new("inGameID", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __inGameID
		data[__inGameID.tag] = service
		
		__inTableNum = PBField.new("inTableNum", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __inTableNum
		data[__inTableNum.tag] = service
		
		__token = PBField.new("token", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __token
		data[__token.tag] = service
		
	var data = {}
	
	var __mainInfo: PBField
	func get_mainInfo() -> MasterInfo:
		return __mainInfo.value
	func clear_mainInfo() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__mainInfo.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_mainInfo() -> MasterInfo:
		__mainInfo.value = MasterInfo.new()
		return __mainInfo.value
	
	var __inGameID: PBField
	func get_inGameID() -> int:
		return __inGameID.value
	func clear_inGameID() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__inGameID.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_inGameID(value : int) -> void:
		__inGameID.value = value
	
	var __inTableNum: PBField
	func get_inTableNum() -> int:
		return __inTableNum.value
	func clear_inTableNum() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__inTableNum.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_inTableNum(value : int) -> void:
		__inTableNum.value = value
	
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
	
class AllopatricResp:
	func _init():
		var service
		
		__userID = PBField.new("userID", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __userID
		data[__userID.tag] = service
		
	var data = {}
	
	var __userID: PBField
	func get_userID() -> int:
		return __userID.value
	func clear_userID() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
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
	
class ReconnectReq:
	func _init():
		var service
		
		__account = PBField.new("account", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __account
		data[__account.tag] = service
		
		__password = PBField.new("password", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __password
		data[__password.tag] = service
		
		__machineCode = PBField.new("machineCode", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __machineCode
		data[__machineCode.tag] = service
		
		__platformID = PBField.new("platformID", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __platformID
		data[__platformID.tag] = service
		
	var data = {}
	
	var __account: PBField
	func get_account() -> String:
		return __account.value
	func clear_account() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__account.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_account(value : String) -> void:
		__account.value = value
	
	var __password: PBField
	func get_password() -> String:
		return __password.value
	func clear_password() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__password.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_password(value : String) -> void:
		__password.value = value
	
	var __machineCode: PBField
	func get_machineCode() -> String:
		return __machineCode.value
	func clear_machineCode() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__machineCode.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_machineCode(value : String) -> void:
		__machineCode.value = value
	
	var __platformID: PBField
	func get_platformID() -> int:
		return __platformID.value
	func clear_platformID() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__platformID.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_platformID(value : int) -> void:
		__platformID.value = value
	
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
		
		__mainInfo = PBField.new("mainInfo", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __mainInfo
		service.func_ref = Callable(self, "new_mainInfo")
		data[__mainInfo.tag] = service
		
		__inGameID = PBField.new("inGameID", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __inGameID
		data[__inGameID.tag] = service
		
		__inTableNum = PBField.new("inTableNum", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __inTableNum
		data[__inTableNum.tag] = service
		
		__token = PBField.new("token", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __token
		data[__token.tag] = service
		
	var data = {}
	
	var __mainInfo: PBField
	func get_mainInfo() -> MasterInfo:
		return __mainInfo.value
	func clear_mainInfo() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__mainInfo.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_mainInfo() -> MasterInfo:
		__mainInfo.value = MasterInfo.new()
		return __mainInfo.value
	
	var __inGameID: PBField
	func get_inGameID() -> int:
		return __inGameID.value
	func clear_inGameID() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__inGameID.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_inGameID(value : int) -> void:
		__inGameID.value = value
	
	var __inTableNum: PBField
	func get_inTableNum() -> int:
		return __inTableNum.value
	func clear_inTableNum() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__inTableNum.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_inTableNum(value : int) -> void:
		__inTableNum.value = value
	
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
	
class ChooseClassReq:
	func _init():
		var service
		
		__iD = PBField.new("iD", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __iD
		data[__iD.tag] = service
		
		__tableKey = PBField.new("tableKey", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __tableKey
		data[__tableKey.tag] = service
		
	var data = {}
	
	var __iD: PBField
	func get_iD() -> int:
		return __iD.value
	func clear_iD() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__iD.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_iD(value : int) -> void:
		__iD.value = value
	
	var __tableKey: PBField
	func get_tableKey() -> String:
		return __tableKey.value
	func clear_tableKey() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__tableKey.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_tableKey(value : String) -> void:
		__tableKey.value = value
	
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
	
class ChooseClassResp:
	func _init():
		var service
		
		__iD = PBField.new("iD", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __iD
		data[__iD.tag] = service
		
		__games = PBField.new("games", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __games
		service.func_ref = Callable(self, "new_games")
		data[__games.tag] = service
		
		__pageNum = PBField.new("pageNum", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __pageNum
		data[__pageNum.tag] = service
		
	var data = {}
	
	var __iD: PBField
	func get_iD() -> int:
		return __iD.value
	func clear_iD() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__iD.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_iD(value : int) -> void:
		__iD.value = value
	
	var __games: PBField
	func get_games() -> GameList:
		return __games.value
	func clear_games() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__games.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_games() -> GameList:
		__games.value = GameList.new()
		return __games.value
	
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
	
class ChooseGameReq:
	func _init():
		var service
		
		__info = PBField.new("info", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __info
		service.func_ref = Callable(self, "new_info")
		data[__info.tag] = service
		
		__pageNum = PBField.new("pageNum", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __pageNum
		data[__pageNum.tag] = service
		
	var data = {}
	
	var __info: PBField
	func get_info() -> GameInfo:
		return __info.value
	func clear_info() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__info.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_info() -> GameInfo:
		__info.value = GameInfo.new()
		return __info.value
	
	var __pageNum: PBField
	func get_pageNum() -> int:
		return __pageNum.value
	func clear_pageNum() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
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
	
class ChooseGameResp:
	func _init():
		var service
		
		__info = PBField.new("info", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __info
		service.func_ref = Callable(self, "new_info")
		data[__info.tag] = service
		
		__pageNum = PBField.new("pageNum", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __pageNum
		data[__pageNum.tag] = service
		
		__tables = PBField.new("tables", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __tables
		service.func_ref = Callable(self, "new_tables")
		data[__tables.tag] = service
		
	var data = {}
	
	var __info: PBField
	func get_info() -> GameInfo:
		return __info.value
	func clear_info() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__info.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_info() -> GameInfo:
		__info.value = GameInfo.new()
		return __info.value
	
	var __pageNum: PBField
	func get_pageNum() -> int:
		return __pageNum.value
	func clear_pageNum() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__pageNum.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_pageNum(value : int) -> void:
		__pageNum.value = value
	
	var __tables: PBField
	func get_tables() -> TableList:
		return __tables.value
	func clear_tables() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__tables.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_tables() -> TableList:
		__tables.value = TableList.new()
		return __tables.value
	
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
	
class SettingTableReq:
	func _init():
		var service
		
		__gInfo = PBField.new("gInfo", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __gInfo
		service.func_ref = Callable(self, "new_gInfo")
		data[__gInfo.tag] = service
		
		__tInfo = PBField.new("tInfo", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __tInfo
		service.func_ref = Callable(self, "new_tInfo")
		data[__tInfo.tag] = service
		
	var data = {}
	
	var __gInfo: PBField
	func get_gInfo() -> GameInfo:
		return __gInfo.value
	func clear_gInfo() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__gInfo.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_gInfo() -> GameInfo:
		__gInfo.value = GameInfo.new()
		return __gInfo.value
	
	var __tInfo: PBField
	func get_tInfo() -> TableInfo:
		return __tInfo.value
	func clear_tInfo() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__tInfo.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_tInfo() -> TableInfo:
		__tInfo.value = TableInfo.new()
		return __tInfo.value
	
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
	
class SettingTableResp:
	func _init():
		var service
		
		__item = PBField.new("item", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __item
		service.func_ref = Callable(self, "new_item")
		data[__item.tag] = service
		
	var data = {}
	
	var __item: PBField
	func get_item() -> TableItem:
		return __item.value
	func clear_item() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__item.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_item() -> TableItem:
		__item.value = TableItem.new()
		return __item.value
	
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
		
		__userID = PBField.new("userID", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __userID
		data[__userID.tag] = service
		
		__remark = PBField.new("remark", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __remark
		data[__remark.tag] = service
		
	var data = {}
	
	var __userID: PBField
	func get_userID() -> int:
		return __userID.value
	func clear_userID() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__userID.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_userID(value : int) -> void:
		__userID.value = value
	
	var __remark: PBField
	func get_remark() -> String:
		return __remark.value
	func clear_remark() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__remark.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_remark(value : String) -> void:
		__remark.value = value
	
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
		
		__userID = PBField.new("userID", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __userID
		data[__userID.tag] = service
		
		__remark = PBField.new("remark", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __remark
		data[__remark.tag] = service
		
		__timestamp = PBField.new("timestamp", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __timestamp
		data[__timestamp.tag] = service
		
		__awardList = PBField.new("awardList", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __awardList
		service.func_ref = Callable(self, "new_awardList")
		data[__awardList.tag] = service
		
	var data = {}
	
	var __userID: PBField
	func get_userID() -> int:
		return __userID.value
	func clear_userID() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__userID.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_userID(value : int) -> void:
		__userID.value = value
	
	var __remark: PBField
	func get_remark() -> String:
		return __remark.value
	func clear_remark() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__remark.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_remark(value : String) -> void:
		__remark.value = value
	
	var __timestamp: PBField
	func get_timestamp() -> int:
		return __timestamp.value
	func clear_timestamp() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__timestamp.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_timestamp(value : int) -> void:
		__timestamp.value = value
	
	var __awardList: PBField
	func get_awardList() -> GoodsList:
		return __awardList.value
	func clear_awardList() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__awardList.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_awardList() -> GoodsList:
		__awardList.value = GoodsList.new()
		return __awardList.value
	
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
	
class GetCheckInResp:
	func _init():
		var service
		
		__userID = PBField.new("userID", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __userID
		data[__userID.tag] = service
		
		var __allCheckin_default: Array[CheckInResp] = []
		__allCheckin = PBField.new("allCheckin", PB_DATA_TYPE.MESSAGE, PB_RULE.REPEATED, 2, true, __allCheckin_default)
		service = PBServiceField.new()
		service.field = __allCheckin
		service.func_ref = Callable(self, "add_allCheckin")
		data[__allCheckin.tag] = service
		
		__pageNum = PBField.new("pageNum", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
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
	
	var __allCheckin: PBField
	func get_allCheckin() -> Array[CheckInResp]:
		return __allCheckin.value
	func clear_allCheckin() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__allCheckin.value = []
	func add_allCheckin() -> CheckInResp:
		var element = CheckInResp.new()
		__allCheckin.value.append(element)
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
	
class DrawHeroReq:
	func _init():
		var service
		
		__amount = PBField.new("amount", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __amount
		data[__amount.tag] = service
		
	var data = {}
	
	var __amount: PBField
	func get_amount() -> int:
		return __amount.value
	func clear_amount() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__amount.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_amount(value : int) -> void:
		__amount.value = value
	
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
		
		__userID = PBField.new("userID", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __userID
		data[__userID.tag] = service
		
		var __heroList_default: Array[HeroInfo] = []
		__heroList = PBField.new("heroList", PB_DATA_TYPE.MESSAGE, PB_RULE.REPEATED, 2, true, __heroList_default)
		service = PBServiceField.new()
		service.field = __heroList
		service.func_ref = Callable(self, "add_heroList")
		data[__heroList.tag] = service
		
	var data = {}
	
	var __userID: PBField
	func get_userID() -> int:
		return __userID.value
	func clear_userID() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__userID.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_userID(value : int) -> void:
		__userID.value = value
	
	var __heroList: PBField
	func get_heroList() -> Array[HeroInfo]:
		return __heroList.value
	func clear_heroList() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__heroList.value = []
	func add_heroList() -> HeroInfo:
		var element = HeroInfo.new()
		__heroList.value.append(element)
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
	
class GetMyHeroResp:
	func _init():
		var service
		
		__userID = PBField.new("userID", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __userID
		data[__userID.tag] = service
		
		var __heroList_default: Array[HeroInfo] = []
		__heroList = PBField.new("heroList", PB_DATA_TYPE.MESSAGE, PB_RULE.REPEATED, 2, true, __heroList_default)
		service = PBServiceField.new()
		service.field = __heroList
		service.func_ref = Callable(self, "add_heroList")
		data[__heroList.tag] = service
		
	var data = {}
	
	var __userID: PBField
	func get_userID() -> int:
		return __userID.value
	func clear_userID() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__userID.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_userID(value : int) -> void:
		__userID.value = value
	
	var __heroList: PBField
	func get_heroList() -> Array[HeroInfo]:
		return __heroList.value
	func clear_heroList() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__heroList.value = []
	func add_heroList() -> HeroInfo:
		var element = HeroInfo.new()
		__heroList.value.append(element)
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
		
		__position = PBField.new("position", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __position
		data[__position.tag] = service
		
		__heroID = PBField.new("heroID", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __heroID
		data[__heroID.tag] = service
		
	var data = {}
	
	var __position: PBField
	func get_position() -> int:
		return __position.value
	func clear_position() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__position.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_position(value : int) -> void:
		__position.value = value
	
	var __heroID: PBField
	func get_heroID() -> int:
		return __heroID.value
	func clear_heroID() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__heroID.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_heroID(value : int) -> void:
		__heroID.value = value
	
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
		
		__position = PBField.new("position", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __position
		data[__position.tag] = service
		
		__hero = PBField.new("hero", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __hero
		service.func_ref = Callable(self, "new_hero")
		data[__hero.tag] = service
		
	var data = {}
	
	var __position: PBField
	func get_position() -> int:
		return __position.value
	func clear_position() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__position.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_position(value : int) -> void:
		__position.value = value
	
	var __hero: PBField
	func get_hero() -> HeroInfo:
		return __hero.value
	func clear_hero() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__hero.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_hero() -> HeroInfo:
		__hero.value = HeroInfo.new()
		return __hero.value
	
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
	
class DownHeroReq:
	func _init():
		var service
		
		__position = PBField.new("position", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __position
		data[__position.tag] = service
		
		__heroID = PBField.new("heroID", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __heroID
		data[__heroID.tag] = service
		
	var data = {}
	
	var __position: PBField
	func get_position() -> int:
		return __position.value
	func clear_position() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__position.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_position(value : int) -> void:
		__position.value = value
	
	var __heroID: PBField
	func get_heroID() -> int:
		return __heroID.value
	func clear_heroID() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__heroID.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_heroID(value : int) -> void:
		__heroID.value = value
	
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
	
class DownHeroReqResp:
	func _init():
		var service
		
		__position = PBField.new("position", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __position
		data[__position.tag] = service
		
		__heroID = PBField.new("heroID", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __heroID
		data[__heroID.tag] = service
		
	var data = {}
	
	var __position: PBField
	func get_position() -> int:
		return __position.value
	func clear_position() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__position.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_position(value : int) -> void:
		__position.value = value
	
	var __heroID: PBField
	func get_heroID() -> int:
		return __heroID.value
	func clear_heroID() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__heroID.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_heroID(value : int) -> void:
		__heroID.value = value
	
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
	
class GetAllHeroResp:
	func _init():
		var service
		
		var __heroList_default: Array[HeroInfo] = []
		__heroList = PBField.new("heroList", PB_DATA_TYPE.MESSAGE, PB_RULE.REPEATED, 1, true, __heroList_default)
		service = PBServiceField.new()
		service.field = __heroList
		service.func_ref = Callable(self, "add_heroList")
		data[__heroList.tag] = service
		
	var data = {}
	
	var __heroList: PBField
	func get_heroList() -> Array[HeroInfo]:
		return __heroList.value
	func clear_heroList() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__heroList.value = []
	func add_heroList() -> HeroInfo:
		var element = HeroInfo.new()
		__heroList.value.append(element)
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
		
		var __heroIDs_default: Array[int] = []
		__heroIDs = PBField.new("heroIDs", PB_DATA_TYPE.INT32, PB_RULE.REPEATED, 1, true, __heroIDs_default)
		service = PBServiceField.new()
		service.field = __heroIDs
		data[__heroIDs.tag] = service
		
		__name = PBField.new("name", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __name
		data[__name.tag] = service
		
		__sex = PBField.new("sex", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __sex
		data[__sex.tag] = service
		
		__country = PBField.new("country", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __country
		data[__country.tag] = service
		
		__faction = PBField.new("faction", PB_DATA_TYPE.ENUM, PB_RULE.OPTIONAL, 5, true, DEFAULT_VALUES_3[PB_DATA_TYPE.ENUM])
		service = PBServiceField.new()
		service.field = __faction
		data[__faction.tag] = service
		
	var data = {}
	
	var __heroIDs: PBField
	func get_heroIDs() -> Array[int]:
		return __heroIDs.value
	func clear_heroIDs() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__heroIDs.value = []
	func add_heroIDs(value : int) -> void:
		__heroIDs.value.append(value)
	
	var __name: PBField
	func get_name() -> String:
		return __name.value
	func clear_name() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__name.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_name(value : String) -> void:
		__name.value = value
	
	var __sex: PBField
	func get_sex() -> int:
		return __sex.value
	func clear_sex() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__sex.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_sex(value : int) -> void:
		__sex.value = value
	
	var __country: PBField
	func get_country() -> String:
		return __country.value
	func clear_country() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__country.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_country(value : String) -> void:
		__country.value = value
	
	var __faction: PBField
	func get_faction():
		return __faction.value
	func clear_faction() -> void:
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__faction.value = DEFAULT_VALUES_3[PB_DATA_TYPE.ENUM]
	func set_faction(value) -> void:
		__faction.value = value
	
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
		
		var __heroList_default: Array[HeroInfo] = []
		__heroList = PBField.new("heroList", PB_DATA_TYPE.MESSAGE, PB_RULE.REPEATED, 1, true, __heroList_default)
		service = PBServiceField.new()
		service.field = __heroList
		service.func_ref = Callable(self, "add_heroList")
		data[__heroList.tag] = service
		
	var data = {}
	
	var __heroList: PBField
	func get_heroList() -> Array[HeroInfo]:
		return __heroList.value
	func clear_heroList() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__heroList.value = []
	func add_heroList() -> HeroInfo:
		var element = HeroInfo.new()
		__heroList.value.append(element)
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
		
		__userID = PBField.new("userID", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __userID
		data[__userID.tag] = service
		
		__byiD = PBField.new("byiD", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __byiD
		data[__byiD.tag] = service
		
		__payment = PBField.new("payment", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __payment
		data[__payment.tag] = service
		
		__method = PBField.new("method", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __method
		data[__method.tag] = service
		
		__switch = PBField.new("switch", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 5, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __switch
		data[__switch.tag] = service
		
		__reason = PBField.new("reason", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 6, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
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
	
	var __byiD: PBField
	func get_byiD() -> int:
		return __byiD.value
	func clear_byiD() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__byiD.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_byiD(value : int) -> void:
		__byiD.value = value
	
	var __payment: PBField
	func get_payment() -> int:
		return __payment.value
	func clear_payment() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__payment.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_payment(value : int) -> void:
		__payment.value = value
	
	var __method: PBField
	func get_method() -> int:
		return __method.value
	func clear_method() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__method.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_method(value : int) -> void:
		__method.value = value
	
	var __switch: PBField
	func get_switch() -> int:
		return __switch.value
	func clear_switch() -> void:
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__switch.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_switch(value : int) -> void:
		__switch.value = value
	
	var __reason: PBField
	func get_reason() -> String:
		return __reason.value
	func clear_reason() -> void:
		data[6].state = PB_SERVICE_STATE.UNFILLED
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
	
class RechargeResp:
	func _init():
		var service
		
		__userID = PBField.new("userID", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __userID
		data[__userID.tag] = service
		
		__byiD = PBField.new("byiD", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __byiD
		data[__byiD.tag] = service
		
		__preMoney = PBField.new("preMoney", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __preMoney
		data[__preMoney.tag] = service
		
		__payment = PBField.new("payment", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __payment
		data[__payment.tag] = service
		
		__money = PBField.new("money", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 5, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __money
		data[__money.tag] = service
		
		__yuanBao = PBField.new("yuanBao", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 6, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __yuanBao
		data[__yuanBao.tag] = service
		
		__coin = PBField.new("coin", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 7, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __coin
		data[__coin.tag] = service
		
		__method = PBField.new("method", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 8, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __method
		data[__method.tag] = service
		
		__isSuccess = PBField.new("isSuccess", PB_DATA_TYPE.BOOL, PB_RULE.OPTIONAL, 9, true, DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL])
		service = PBServiceField.new()
		service.field = __isSuccess
		data[__isSuccess.tag] = service
		
		__order = PBField.new("order", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 10, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __order
		data[__order.tag] = service
		
		__timeStamp = PBField.new("timeStamp", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 11, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __timeStamp
		data[__timeStamp.tag] = service
		
		__reason = PBField.new("reason", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 12, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
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
	
	var __byiD: PBField
	func get_byiD() -> int:
		return __byiD.value
	func clear_byiD() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__byiD.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_byiD(value : int) -> void:
		__byiD.value = value
	
	var __preMoney: PBField
	func get_preMoney() -> int:
		return __preMoney.value
	func clear_preMoney() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__preMoney.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_preMoney(value : int) -> void:
		__preMoney.value = value
	
	var __payment: PBField
	func get_payment() -> int:
		return __payment.value
	func clear_payment() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__payment.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_payment(value : int) -> void:
		__payment.value = value
	
	var __money: PBField
	func get_money() -> int:
		return __money.value
	func clear_money() -> void:
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__money.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_money(value : int) -> void:
		__money.value = value
	
	var __yuanBao: PBField
	func get_yuanBao() -> int:
		return __yuanBao.value
	func clear_yuanBao() -> void:
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__yuanBao.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_yuanBao(value : int) -> void:
		__yuanBao.value = value
	
	var __coin: PBField
	func get_coin() -> int:
		return __coin.value
	func clear_coin() -> void:
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__coin.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_coin(value : int) -> void:
		__coin.value = value
	
	var __method: PBField
	func get_method() -> int:
		return __method.value
	func clear_method() -> void:
		data[8].state = PB_SERVICE_STATE.UNFILLED
		__method.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_method(value : int) -> void:
		__method.value = value
	
	var __isSuccess: PBField
	func get_isSuccess() -> bool:
		return __isSuccess.value
	func clear_isSuccess() -> void:
		data[9].state = PB_SERVICE_STATE.UNFILLED
		__isSuccess.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL]
	func set_isSuccess(value : bool) -> void:
		__isSuccess.value = value
	
	var __order: PBField
	func get_order() -> String:
		return __order.value
	func clear_order() -> void:
		data[10].state = PB_SERVICE_STATE.UNFILLED
		__order.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_order(value : String) -> void:
		__order.value = value
	
	var __timeStamp: PBField
	func get_timeStamp() -> int:
		return __timeStamp.value
	func clear_timeStamp() -> void:
		data[11].state = PB_SERVICE_STATE.UNFILLED
		__timeStamp.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_timeStamp(value : int) -> void:
		__timeStamp.value = value
	
	var __reason: PBField
	func get_reason() -> String:
		return __reason.value
	func clear_reason() -> void:
		data[12].state = PB_SERVICE_STATE.UNFILLED
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
	
class GetRechargesReq:
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
	
class GetRechargesResp:
	func _init():
		var service
		
		__userID = PBField.new("userID", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __userID
		data[__userID.tag] = service
		
		var __allRecharges_default: Array[RechargeResp] = []
		__allRecharges = PBField.new("allRecharges", PB_DATA_TYPE.MESSAGE, PB_RULE.REPEATED, 2, true, __allRecharges_default)
		service = PBServiceField.new()
		service.field = __allRecharges
		service.func_ref = Callable(self, "add_allRecharges")
		data[__allRecharges.tag] = service
		
		__pageNum = PBField.new("pageNum", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
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
	
	var __allRecharges: PBField
	func get_allRecharges() -> Array[RechargeResp]:
		return __allRecharges.value
	func clear_allRecharges() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__allRecharges.value = []
	func add_allRecharges() -> RechargeResp:
		var element = RechargeResp.new()
		__allRecharges.value.append(element)
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
	
class GetGoodsReq:
	func _init():
		var service
		
		__iD = PBField.new("iD", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __iD
		data[__iD.tag] = service
		
	var data = {}
	
	var __iD: PBField
	func get_iD() -> int:
		return __iD.value
	func clear_iD() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__iD.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_iD(value : int) -> void:
		__iD.value = value
	
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
		
		__userID = PBField.new("userID", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __userID
		data[__userID.tag] = service
		
		__info = PBField.new("info", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __info
		service.func_ref = Callable(self, "new_info")
		data[__info.tag] = service
		
	var data = {}
	
	var __userID: PBField
	func get_userID() -> int:
		return __userID.value
	func clear_userID() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__userID.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_userID(value : int) -> void:
		__userID.value = value
	
	var __info: PBField
	func get_info() -> GoodsInfo:
		return __info.value
	func clear_info() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__info.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_info() -> GoodsInfo:
		__info.value = GoodsInfo.new()
		return __info.value
	
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
	
class GetAllGoodsResp:
	func _init():
		var service
		
		__userID = PBField.new("userID", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __userID
		data[__userID.tag] = service
		
		var __info_default: Array[GoodsInfo] = []
		__info = PBField.new("info", PB_DATA_TYPE.MESSAGE, PB_RULE.REPEATED, 2, true, __info_default)
		service = PBServiceField.new()
		service.field = __info
		service.func_ref = Callable(self, "add_info")
		data[__info.tag] = service
		
		__pageNum = PBField.new("pageNum", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
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
	
	var __info: PBField
	func get_info() -> Array[GoodsInfo]:
		return __info.value
	func clear_info() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__info.value = []
	func add_info() -> GoodsInfo:
		var element = GoodsInfo.new()
		__info.value.append(element)
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
	
class BuyGoodsReq:
	func _init():
		var service
		
		__iD = PBField.new("iD", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __iD
		data[__iD.tag] = service
		
		__payment = PBField.new("payment", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __payment
		data[__payment.tag] = service
		
		__count = PBField.new("count", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __count
		data[__count.tag] = service
		
	var data = {}
	
	var __iD: PBField
	func get_iD() -> int:
		return __iD.value
	func clear_iD() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__iD.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_iD(value : int) -> void:
		__iD.value = value
	
	var __payment: PBField
	func get_payment() -> int:
		return __payment.value
	func clear_payment() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__payment.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_payment(value : int) -> void:
		__payment.value = value
	
	var __count: PBField
	func get_count() -> int:
		return __count.value
	func clear_count() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__count.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_count(value : int) -> void:
		__count.value = value
	
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
		
		__userID = PBField.new("userID", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __userID
		data[__userID.tag] = service
		
		__info = PBField.new("info", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __info
		service.func_ref = Callable(self, "new_info")
		data[__info.tag] = service
		
	var data = {}
	
	var __userID: PBField
	func get_userID() -> int:
		return __userID.value
	func clear_userID() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__userID.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_userID(value : int) -> void:
		__userID.value = value
	
	var __info: PBField
	func get_info() -> GoodsInfo:
		return __info.value
	func clear_info() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__info.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_info() -> GoodsInfo:
		__info.value = GoodsInfo.new()
		return __info.value
	
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
		
		__iD = PBField.new("iD", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __iD
		data[__iD.tag] = service
		
		__number = PBField.new("number", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __number
		data[__number.tag] = service
		
	var data = {}
	
	var __iD: PBField
	func get_iD() -> int:
		return __iD.value
	func clear_iD() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__iD.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_iD(value : int) -> void:
		__iD.value = value
	
	var __number: PBField
	func get_number() -> int:
		return __number.value
	func clear_number() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__number.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_number(value : int) -> void:
		__number.value = value
	
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
		
		__userID = PBField.new("userID", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __userID
		data[__userID.tag] = service
		
		__info = PBField.new("info", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __info
		service.func_ref = Callable(self, "new_info")
		data[__info.tag] = service
		
	var data = {}
	
	var __userID: PBField
	func get_userID() -> int:
		return __userID.value
	func clear_userID() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__userID.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_userID(value : int) -> void:
		__userID.value = value
	
	var __info: PBField
	func get_info() -> KnapsackInfo:
		return __info.value
	func clear_info() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__info.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_info() -> KnapsackInfo:
		__info.value = KnapsackInfo.new()
		return __info.value
	
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
		
		__iD = PBField.new("iD", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __iD
		data[__iD.tag] = service
		
		__toID = PBField.new("toID", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __toID
		data[__toID.tag] = service
		
		__amount = PBField.new("amount", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __amount
		data[__amount.tag] = service
		
	var data = {}
	
	var __iD: PBField
	func get_iD() -> int:
		return __iD.value
	func clear_iD() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__iD.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_iD(value : int) -> void:
		__iD.value = value
	
	var __toID: PBField
	func get_toID() -> int:
		return __toID.value
	func clear_toID() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__toID.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_toID(value : int) -> void:
		__toID.value = value
	
	var __amount: PBField
	func get_amount() -> int:
		return __amount.value
	func clear_amount() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__amount.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_amount(value : int) -> void:
		__amount.value = value
	
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
		
		__userID = PBField.new("userID", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __userID
		data[__userID.tag] = service
		
		__info = PBField.new("info", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __info
		service.func_ref = Callable(self, "new_info")
		data[__info.tag] = service
		
	var data = {}
	
	var __userID: PBField
	func get_userID() -> int:
		return __userID.value
	func clear_userID() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__userID.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_userID(value : int) -> void:
		__userID.value = value
	
	var __info: PBField
	func get_info() -> KnapsackInfo:
		return __info.value
	func clear_info() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__info.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_info() -> KnapsackInfo:
		__info.value = KnapsackInfo.new()
		return __info.value
	
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
		
		__iD = PBField.new("iD", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __iD
		data[__iD.tag] = service
		
		__count = PBField.new("count", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __count
		data[__count.tag] = service
		
		__reason = PBField.new("reason", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __reason
		data[__reason.tag] = service
		
	var data = {}
	
	var __iD: PBField
	func get_iD() -> int:
		return __iD.value
	func clear_iD() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__iD.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_iD(value : int) -> void:
		__iD.value = value
	
	var __count: PBField
	func get_count() -> int:
		return __count.value
	func clear_count() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__count.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_count(value : int) -> void:
		__count.value = value
	
	var __reason: PBField
	func get_reason() -> String:
		return __reason.value
	func clear_reason() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
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
	
class EmailReq:
	func _init():
		var service
		
		__pageNum = PBField.new("pageNum", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __pageNum
		data[__pageNum.tag] = service
		
	var data = {}
	
	var __pageNum: PBField
	func get_pageNum() -> int:
		return __pageNum.value
	func clear_pageNum() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
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
	
class EmailResp:
	func _init():
		var service
		
		__userID = PBField.new("userID", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __userID
		data[__userID.tag] = service
		
		var __infos_default: Array[EmailInfo] = []
		__infos = PBField.new("infos", PB_DATA_TYPE.MESSAGE, PB_RULE.REPEATED, 2, true, __infos_default)
		service = PBServiceField.new()
		service.field = __infos
		service.func_ref = Callable(self, "add_infos")
		data[__infos.tag] = service
		
		__pageNum = PBField.new("pageNum", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
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
	
	var __infos: PBField
	func get_infos() -> Array[EmailInfo]:
		return __infos.value
	func clear_infos() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__infos.value = []
	func add_infos() -> EmailInfo:
		var element = EmailInfo.new()
		__infos.value.append(element)
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
	
class ClaimReq:
	func _init():
		var service
		
		__emailID = PBField.new("emailID", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __emailID
		data[__emailID.tag] = service
		
	var data = {}
	
	var __emailID: PBField
	func get_emailID() -> int:
		return __emailID.value
	func clear_emailID() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__emailID.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_emailID(value : int) -> void:
		__emailID.value = value
	
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
		
		__userID = PBField.new("userID", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __userID
		data[__userID.tag] = service
		
		__emailID = PBField.new("emailID", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __emailID
		data[__emailID.tag] = service
		
	var data = {}
	
	var __userID: PBField
	func get_userID() -> int:
		return __userID.value
	func clear_userID() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__userID.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_userID(value : int) -> void:
		__userID.value = value
	
	var __emailID: PBField
	func get_emailID() -> int:
		return __emailID.value
	func clear_emailID() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__emailID.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_emailID(value : int) -> void:
		__emailID.value = value
	
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
		
		__content = PBField.new("content", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __content
		data[__content.tag] = service
		
	var data = {}
	
	var __content: PBField
	func get_content() -> String:
		return __content.value
	func clear_content() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
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
	
class SuggestResp:
	func _init():
		var service
		
		__userID = PBField.new("userID", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __userID
		data[__userID.tag] = service
		
		__feedback = PBField.new("feedback", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __feedback
		service.func_ref = Callable(self, "new_feedback")
		data[__feedback.tag] = service
		
	var data = {}
	
	var __userID: PBField
	func get_userID() -> int:
		return __userID.value
	func clear_userID() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__userID.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_userID(value : int) -> void:
		__userID.value = value
	
	var __feedback: PBField
	func get_feedback() -> EmailInfo:
		return __feedback.value
	func clear_feedback() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__feedback.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_feedback() -> EmailInfo:
		__feedback.value = EmailInfo.new()
		return __feedback.value
	
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
		
		__emailID = PBField.new("emailID", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __emailID
		data[__emailID.tag] = service
		
	var data = {}
	
	var __emailID: PBField
	func get_emailID() -> int:
		return __emailID.value
	func clear_emailID() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__emailID.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_emailID(value : int) -> void:
		__emailID.value = value
	
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
		
		__userID = PBField.new("userID", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __userID
		data[__userID.tag] = service
		
		__emailID = PBField.new("emailID", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __emailID
		data[__emailID.tag] = service
		
	var data = {}
	
	var __userID: PBField
	func get_userID() -> int:
		return __userID.value
	func clear_userID() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__userID.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_userID(value : int) -> void:
		__userID.value = value
	
	var __emailID: PBField
	func get_emailID() -> int:
		return __emailID.value
	func clear_emailID() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__emailID.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_emailID(value : int) -> void:
		__emailID.value = value
	
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
		
		__emailID = PBField.new("emailID", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __emailID
		data[__emailID.tag] = service
		
	var data = {}
	
	var __emailID: PBField
	func get_emailID() -> int:
		return __emailID.value
	func clear_emailID() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__emailID.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_emailID(value : int) -> void:
		__emailID.value = value
	
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
		
		__userID = PBField.new("userID", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __userID
		data[__userID.tag] = service
		
		__emailID = PBField.new("emailID", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __emailID
		data[__emailID.tag] = service
		
	var data = {}
	
	var __userID: PBField
	func get_userID() -> int:
		return __userID.value
	func clear_userID() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__userID.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_userID(value : int) -> void:
		__userID.value = value
	
	var __emailID: PBField
	func get_emailID() -> int:
		return __emailID.value
	func clear_emailID() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__emailID.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_emailID(value : int) -> void:
		__emailID.value = value
	
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
		
		__state = PBField.new("state", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __state
		data[__state.tag] = service
		
		__hints = PBField.new("hints", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __hints
		data[__hints.tag] = service
		
	var data = {}
	
	var __state: PBField
	func get_state() -> int:
		return __state.value
	func clear_state() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__state.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_state(value : int) -> void:
		__state.value = value
	
	var __hints: PBField
	func get_hints() -> String:
		return __hints.value
	func clear_hints() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
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
	
class ResultPopResp:
	func _init():
		var service
		
		__flag = PBField.new("flag", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __flag
		data[__flag.tag] = service
		
		__title = PBField.new("title", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __title
		data[__title.tag] = service
		
		__hints = PBField.new("hints", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __hints
		data[__hints.tag] = service
		
	var data = {}
	
	var __flag: PBField
	func get_flag() -> int:
		return __flag.value
	func clear_flag() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__flag.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_flag(value : int) -> void:
		__flag.value = value
	
	var __title: PBField
	func get_title() -> String:
		return __title.value
	func clear_title() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__title.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_title(value : String) -> void:
		__title.value = value
	
	var __hints: PBField
	func get_hints() -> String:
		return __hints.value
	func clear_hints() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
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
	
class PingReq:
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
	
class PongResp:
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
	
################ USER DATA END #################
