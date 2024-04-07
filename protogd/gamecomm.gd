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


enum PlayerState {
	PlayerLookOn = 0,
	PlayerSitDown = 1,
	PlayerAgree = 2,
	PlayerPlaying = 3,
	PlayerPickUp = 4,
	PlayerChouKa = 5,
	PlayerChooseJiang = 6,
	PlayerTrustee = 97,
	PlayerGiveUp = 98,
	PlayerStandUp = 99
}

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

class PlayerInfo:
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
		
		__FaceID = PBField.new("FaceID", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __FaceID
		data[__FaceID.tag] = service
		
		__Age = PBField.new("Age", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __Age
		data[__Age.tag] = service
		
		__Sex = PBField.new("Sex", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 5, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __Sex
		data[__Sex.tag] = service
		
		__YuanBao = PBField.new("YuanBao", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 6, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __YuanBao
		data[__YuanBao.tag] = service
		
		__Coin = PBField.new("Coin", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 7, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __Coin
		data[__Coin.tag] = service
		
		__Level = PBField.new("Level", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 8, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __Level
		data[__Level.tag] = service
		
		__Ranking = PBField.new("Ranking", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 9, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __Ranking
		data[__Ranking.tag] = service
		
		__State = PBField.new("State", PB_DATA_TYPE.ENUM, PB_RULE.OPTIONAL, 10, true, DEFAULT_VALUES_3[PB_DATA_TYPE.ENUM])
		service = PBServiceField.new()
		service.field = __State
		data[__State.tag] = service
		
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
	
	var __FaceID: PBField
	func get_FaceID() -> int:
		return __FaceID.value
	func clear_FaceID() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__FaceID.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_FaceID(value : int) -> void:
		__FaceID.value = value
	
	var __Age: PBField
	func get_Age() -> int:
		return __Age.value
	func clear_Age() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__Age.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_Age(value : int) -> void:
		__Age.value = value
	
	var __Sex: PBField
	func get_Sex() -> int:
		return __Sex.value
	func clear_Sex() -> void:
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__Sex.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_Sex(value : int) -> void:
		__Sex.value = value
	
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
	
	var __Level: PBField
	func get_Level() -> int:
		return __Level.value
	func clear_Level() -> void:
		data[8].state = PB_SERVICE_STATE.UNFILLED
		__Level.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_Level(value : int) -> void:
		__Level.value = value
	
	var __Ranking: PBField
	func get_Ranking() -> int:
		return __Ranking.value
	func clear_Ranking() -> void:
		data[9].state = PB_SERVICE_STATE.UNFILLED
		__Ranking.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_Ranking(value : int) -> void:
		__Ranking.value = value
	
	var __State: PBField
	func get_State():
		return __State.value
	func clear_State() -> void:
		data[10].state = PB_SERVICE_STATE.UNFILLED
		__State.value = DEFAULT_VALUES_3[PB_DATA_TYPE.ENUM]
	func set_State(value) -> void:
		__State.value = value
	
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
	
class TimeInfo:
	func _init():
		var service
		
		__TimeStamp = PBField.new("TimeStamp", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __TimeStamp
		data[__TimeStamp.tag] = service
		
		__WaitTime = PBField.new("WaitTime", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __WaitTime
		data[__WaitTime.tag] = service
		
		__OutTime = PBField.new("OutTime", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __OutTime
		data[__OutTime.tag] = service
		
		__TotalTime = PBField.new("TotalTime", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __TotalTime
		data[__TotalTime.tag] = service
		
	var data = {}
	
	var __TimeStamp: PBField
	func get_TimeStamp() -> int:
		return __TimeStamp.value
	func clear_TimeStamp() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__TimeStamp.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_TimeStamp(value : int) -> void:
		__TimeStamp.value = value
	
	var __WaitTime: PBField
	func get_WaitTime() -> int:
		return __WaitTime.value
	func clear_WaitTime() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__WaitTime.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_WaitTime(value : int) -> void:
		__WaitTime.value = value
	
	var __OutTime: PBField
	func get_OutTime() -> int:
		return __OutTime.value
	func clear_OutTime() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__OutTime.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_OutTime(value : int) -> void:
		__OutTime.value = value
	
	var __TotalTime: PBField
	func get_TotalTime() -> int:
		return __TotalTime.value
	func clear_TotalTime() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__TotalTime.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_TotalTime(value : int) -> void:
		__TotalTime.value = value
	
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
		
		__Number = PBField.new("Number", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __Number
		data[__Number.tag] = service
		
		__WinnerID = PBField.new("WinnerID", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __WinnerID
		data[__WinnerID.tag] = service
		
		__LoserID = PBField.new("LoserID", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __LoserID
		data[__LoserID.tag] = service
		
		__Payoff = PBField.new("Payoff", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __Payoff
		data[__Payoff.tag] = service
		
		__TimeStamp = PBField.new("TimeStamp", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 5, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __TimeStamp
		data[__TimeStamp.tag] = service
		
		__Result = PBField.new("Result", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 6, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __Result
		data[__Result.tag] = service
		
	var data = {}
	
	var __Number: PBField
	func get_Number() -> String:
		return __Number.value
	func clear_Number() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__Number.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_Number(value : String) -> void:
		__Number.value = value
	
	var __WinnerID: PBField
	func get_WinnerID() -> int:
		return __WinnerID.value
	func clear_WinnerID() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__WinnerID.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_WinnerID(value : int) -> void:
		__WinnerID.value = value
	
	var __LoserID: PBField
	func get_LoserID() -> int:
		return __LoserID.value
	func clear_LoserID() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__LoserID.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_LoserID(value : int) -> void:
		__LoserID.value = value
	
	var __Payoff: PBField
	func get_Payoff() -> int:
		return __Payoff.value
	func clear_Payoff() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__Payoff.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_Payoff(value : int) -> void:
		__Payoff.value = value
	
	var __TimeStamp: PBField
	func get_TimeStamp() -> int:
		return __TimeStamp.value
	func clear_TimeStamp() -> void:
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__TimeStamp.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_TimeStamp(value : int) -> void:
		__TimeStamp.value = value
	
	var __Result: PBField
	func get_Result() -> String:
		return __Result.value
	func clear_Result() -> void:
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__Result.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_Result(value : String) -> void:
		__Result.value = value
	
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
		
		var __AllInfos_default: Array[PlayerInfo] = []
		__AllInfos = PBField.new("AllInfos", PB_DATA_TYPE.MESSAGE, PB_RULE.REPEATED, 1, true, __AllInfos_default)
		service = PBServiceField.new()
		service.field = __AllInfos
		service.func_ref = Callable(self, "add_AllInfos")
		data[__AllInfos.tag] = service
		
	var data = {}
	
	var __AllInfos: PBField
	func get_AllInfos() -> Array[PlayerInfo]:
		return __AllInfos.value
	func clear_AllInfos() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__AllInfos.value = []
	func add_AllInfos() -> PlayerInfo:
		var element = PlayerInfo.new()
		__AllInfos.value.append(element)
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
	
class ExitGameReq:
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
	
class ExitGameResp:
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
	
class RankingListReq:
	func _init():
		var service
		
		__TopCount = PBField.new("TopCount", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __TopCount
		data[__TopCount.tag] = service
		
	var data = {}
	
	var __TopCount: PBField
	func get_TopCount() -> int:
		return __TopCount.value
	func clear_TopCount() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__TopCount.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_TopCount(value : int) -> void:
		__TopCount.value = value
	
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
		
		__UserInfo = PBField.new("UserInfo", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __UserInfo
		service.func_ref = Callable(self, "new_UserInfo")
		data[__UserInfo.tag] = service
		
	var data = {}
	
	var __UserInfo: PBField
	func get_UserInfo() -> PlayerInfo:
		return __UserInfo.value
	func clear_UserInfo() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__UserInfo.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_UserInfo() -> PlayerInfo:
		__UserInfo.value = PlayerInfo.new()
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
	
class TrusteeReq:
	func _init():
		var service
		
		__IsTrustee = PBField.new("IsTrustee", PB_DATA_TYPE.BOOL, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL])
		service = PBServiceField.new()
		service.field = __IsTrustee
		data[__IsTrustee.tag] = service
		
	var data = {}
	
	var __IsTrustee: PBField
	func get_IsTrustee() -> bool:
		return __IsTrustee.value
	func clear_IsTrustee() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__IsTrustee.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL]
	func set_IsTrustee(value : bool) -> void:
		__IsTrustee.value = value
	
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
		
		__UserID = PBField.new("UserID", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __UserID
		data[__UserID.tag] = service
		
		__IsTrustee = PBField.new("IsTrustee", PB_DATA_TYPE.BOOL, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL])
		service = PBServiceField.new()
		service.field = __IsTrustee
		data[__IsTrustee.tag] = service
		
	var data = {}
	
	var __UserID: PBField
	func get_UserID() -> int:
		return __UserID.value
	func clear_UserID() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__UserID.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_UserID(value : int) -> void:
		__UserID.value = value
	
	var __IsTrustee: PBField
	func get_IsTrustee() -> bool:
		return __IsTrustee.value
	func clear_IsTrustee() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__IsTrustee.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL]
	func set_IsTrustee(value : bool) -> void:
		__IsTrustee.value = value
	
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
		
		__StartTimeStamp = PBField.new("StartTimeStamp", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __StartTimeStamp
		data[__StartTimeStamp.tag] = service
		
		__EndTimeStamp = PBField.new("EndTimeStamp", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __EndTimeStamp
		data[__EndTimeStamp.tag] = service
		
	var data = {}
	
	var __StartTimeStamp: PBField
	func get_StartTimeStamp() -> int:
		return __StartTimeStamp.value
	func clear_StartTimeStamp() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__StartTimeStamp.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_StartTimeStamp(value : int) -> void:
		__StartTimeStamp.value = value
	
	var __EndTimeStamp: PBField
	func get_EndTimeStamp() -> int:
		return __EndTimeStamp.value
	func clear_EndTimeStamp() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__EndTimeStamp.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_EndTimeStamp(value : int) -> void:
		__EndTimeStamp.value = value
	
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
		
		__UserID = PBField.new("UserID", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __UserID
		data[__UserID.tag] = service
		
		__StartTimeStamp = PBField.new("StartTimeStamp", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __StartTimeStamp
		data[__StartTimeStamp.tag] = service
		
		__EndTimeStamp = PBField.new("EndTimeStamp", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __EndTimeStamp
		data[__EndTimeStamp.tag] = service
		
		var __Innings_default: Array[InningInfo] = []
		__Innings = PBField.new("Innings", PB_DATA_TYPE.MESSAGE, PB_RULE.REPEATED, 4, true, __Innings_default)
		service = PBServiceField.new()
		service.field = __Innings
		service.func_ref = Callable(self, "add_Innings")
		data[__Innings.tag] = service
		
		__PageNum = PBField.new("PageNum", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 5, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
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
	
	var __StartTimeStamp: PBField
	func get_StartTimeStamp() -> int:
		return __StartTimeStamp.value
	func clear_StartTimeStamp() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__StartTimeStamp.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_StartTimeStamp(value : int) -> void:
		__StartTimeStamp.value = value
	
	var __EndTimeStamp: PBField
	func get_EndTimeStamp() -> int:
		return __EndTimeStamp.value
	func clear_EndTimeStamp() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__EndTimeStamp.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_EndTimeStamp(value : int) -> void:
		__EndTimeStamp.value = value
	
	var __Innings: PBField
	func get_Innings() -> Array[InningInfo]:
		return __Innings.value
	func clear_Innings() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__Innings.value = []
	func add_Innings() -> InningInfo:
		var element = InningInfo.new()
		__Innings.value.append(element)
		return element
	
	var __PageNum: PBField
	func get_PageNum() -> int:
		return __PageNum.value
	func clear_PageNum() -> void:
		data[5].state = PB_SERVICE_STATE.UNFILLED
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
	
class NotifyBeOut:
	func _init():
		var service
		
		__UserID = PBField.new("UserID", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __UserID
		data[__UserID.tag] = service
		
		__GameID = PBField.new("GameID", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __GameID
		data[__GameID.tag] = service
		
		__Code = PBField.new("Code", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __Code
		data[__Code.tag] = service
		
		__Hints = PBField.new("Hints", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __Hints
		data[__Hints.tag] = service
		
	var data = {}
	
	var __UserID: PBField
	func get_UserID() -> int:
		return __UserID.value
	func clear_UserID() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__UserID.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_UserID(value : int) -> void:
		__UserID.value = value
	
	var __GameID: PBField
	func get_GameID() -> int:
		return __GameID.value
	func clear_GameID() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__GameID.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_GameID(value : int) -> void:
		__GameID.value = value
	
	var __Code: PBField
	func get_Code() -> int:
		return __Code.value
	func clear_Code() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__Code.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_Code(value : int) -> void:
		__Code.value = value
	
	var __Hints: PBField
	func get_Hints() -> String:
		return __Hints.value
	func clear_Hints() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
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
	
class NotifyBalanceChange:
	func _init():
		var service
		
		__UserID = PBField.new("UserID", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __UserID
		data[__UserID.tag] = service
		
		__YuanBao = PBField.new("YuanBao", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __YuanBao
		data[__YuanBao.tag] = service
		
		__AlterYuanBao = PBField.new("AlterYuanBao", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __AlterYuanBao
		data[__AlterYuanBao.tag] = service
		
		__Coin = PBField.new("Coin", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __Coin
		data[__Coin.tag] = service
		
		__AlterCoin = PBField.new("AlterCoin", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 5, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __AlterCoin
		data[__AlterCoin.tag] = service
		
		__Code = PBField.new("Code", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 6, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __Code
		data[__Code.tag] = service
		
		__Reason = PBField.new("Reason", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 7, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
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
	
	var __YuanBao: PBField
	func get_YuanBao() -> int:
		return __YuanBao.value
	func clear_YuanBao() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__YuanBao.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_YuanBao(value : int) -> void:
		__YuanBao.value = value
	
	var __AlterYuanBao: PBField
	func get_AlterYuanBao() -> int:
		return __AlterYuanBao.value
	func clear_AlterYuanBao() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__AlterYuanBao.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_AlterYuanBao(value : int) -> void:
		__AlterYuanBao.value = value
	
	var __Coin: PBField
	func get_Coin() -> int:
		return __Coin.value
	func clear_Coin() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__Coin.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_Coin(value : int) -> void:
		__Coin.value = value
	
	var __AlterCoin: PBField
	func get_AlterCoin() -> int:
		return __AlterCoin.value
	func clear_AlterCoin() -> void:
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__AlterCoin.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_AlterCoin(value : int) -> void:
		__AlterCoin.value = value
	
	var __Code: PBField
	func get_Code() -> int:
		return __Code.value
	func clear_Code() -> void:
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__Code.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_Code(value : int) -> void:
		__Code.value = value
	
	var __Reason: PBField
	func get_Reason() -> String:
		return __Reason.value
	func clear_Reason() -> void:
		data[7].state = PB_SERVICE_STATE.UNFILLED
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
	
class NotifyNoticeReq:
	func _init():
		var service
		
		__GameID = PBField.new("GameID", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __GameID
		data[__GameID.tag] = service
		
		__Title = PBField.new("Title", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __Title
		data[__Title.tag] = service
		
		__Content = PBField.new("Content", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __Content
		data[__Content.tag] = service
		
		__Level = PBField.new("Level", PB_DATA_TYPE.ENUM, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.ENUM])
		service = PBServiceField.new()
		service.field = __Level
		data[__Level.tag] = service
		
		__Timeout = PBField.new("Timeout", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 5, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __Timeout
		data[__Timeout.tag] = service
		
	var data = {}
	
	var __GameID: PBField
	func get_GameID() -> int:
		return __GameID.value
	func clear_GameID() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__GameID.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_GameID(value : int) -> void:
		__GameID.value = value
	
	var __Title: PBField
	func get_Title() -> String:
		return __Title.value
	func clear_Title() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__Title.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_Title(value : String) -> void:
		__Title.value = value
	
	var __Content: PBField
	func get_Content() -> String:
		return __Content.value
	func clear_Content() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__Content.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_Content(value : String) -> void:
		__Content.value = value
	
	var __Level: PBField
	func get_Level():
		return __Level.value
	func clear_Level() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__Level.value = DEFAULT_VALUES_3[PB_DATA_TYPE.ENUM]
	func set_Level(value) -> void:
		__Level.value = value
	
	var __Timeout: PBField
	func get_Timeout() -> int:
		return __Timeout.value
	func clear_Timeout() -> void:
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__Timeout.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_Timeout(value : int) -> void:
		__Timeout.value = value
	
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
		
		__UserID = PBField.new("UserID", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __UserID
		data[__UserID.tag] = service
		
		__GameID = PBField.new("GameID", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __GameID
		data[__GameID.tag] = service
		
		__Level = PBField.new("Level", PB_DATA_TYPE.ENUM, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.ENUM])
		service = PBServiceField.new()
		service.field = __Level
		data[__Level.tag] = service
		
		__TimeInfo = PBField.new("TimeInfo", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __TimeInfo
		service.func_ref = Callable(self, "new_TimeInfo")
		data[__TimeInfo.tag] = service
		
		__Title = PBField.new("Title", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 5, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __Title
		data[__Title.tag] = service
		
		__Content = PBField.new("Content", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 6, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __Content
		data[__Content.tag] = service
		
	var data = {}
	
	var __UserID: PBField
	func get_UserID() -> int:
		return __UserID.value
	func clear_UserID() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__UserID.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_UserID(value : int) -> void:
		__UserID.value = value
	
	var __GameID: PBField
	func get_GameID() -> int:
		return __GameID.value
	func clear_GameID() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__GameID.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_GameID(value : int) -> void:
		__GameID.value = value
	
	var __Level: PBField
	func get_Level():
		return __Level.value
	func clear_Level() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__Level.value = DEFAULT_VALUES_3[PB_DATA_TYPE.ENUM]
	func set_Level(value) -> void:
		__Level.value = value
	
	var __TimeInfo: PBField
	func get_TimeInfo() -> TimeInfo:
		return __TimeInfo.value
	func clear_TimeInfo() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__TimeInfo.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_TimeInfo() -> TimeInfo:
		__TimeInfo.value = TimeInfo.new()
		return __TimeInfo.value
	
	var __Title: PBField
	func get_Title() -> String:
		return __Title.value
	func clear_Title() -> void:
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__Title.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_Title(value : String) -> void:
		__Title.value = value
	
	var __Content: PBField
	func get_Content() -> String:
		return __Content.value
	func clear_Content() -> void:
		data[6].state = PB_SERVICE_STATE.UNFILLED
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
	
################ USER DATA END #################
