extends Node

var reqId = 0
var reqs: Dictionary


func _ready():
	set_process(true)


func _process(_d):
	for key in reqs.keys():
		var req = reqs[key]
		if req.state == 1:
			if (
				req.http.get_status() == HTTPClient.STATUS_CONNECTING
				or req.http.get_status() == HTTPClient.STATUS_RESOLVING
			):
				req.http.poll()
			else:
				if req.http.get_status() != HTTPClient.STATUS_CONNECTED:
					req.state = 4
					req.err = "err when connecting."
				else:
					req.err = req.http.request(
						req.method, req.path, req.headers, req.http.query_string_from_dict(req.msg)
					)
					if req.err == OK:
						req.state = 2
					else:
						req.state = 4
		elif req.state == 2:
			if req.http.get_status() == HTTPClient.STATUS_REQUESTING:
				req.http.poll()
			else:
				if (
					req.http.get_status() != HTTPClient.STATUS_BODY
					and req.http.get_status() != HTTPClient.STATUS_CONNECTED
				):
					req.state = 4
					req.err = "err when request."
				else:
					if req.http.has_response():
						req.state = 3
					else:
						req.state = 4
		elif req.state == 3:
			if req.http.get_status() == HTTPClient.STATUS_BODY:
				req.http.poll()
				var chunk = req.http.read_response_body_chunk()
				if chunk.size() == 0:
					await get_tree().process_frame
					pass
				else:
					req.rb = req.rb + chunk
			else:
				req.state = 4
		else:
			reqs.erase(key)
			if typeof(req.err) != TYPE_INT or req.err != OK:
				print("http err:", req.err)
				if req.isAgain:
					reqAgain(req)
					return
			else:
				if req.isRaw:
					req.cb.call(req.rb)
				else:
					req.cb.call(req.rb.get_string_from_utf8())
			print("cur http reqs size:", reqs.size())


func reqAgain(req):
	reqId -= 1
	req.http.close()
	Request(
		req.host,
		req.port,
		req.path,
		req.msg,
		req.cbObj,
		req.method,
		req.isRaw,
		req.isAgain,
		req.headers
	)
	pass


###############################[外部接口]#################################################
func Request(
	host,
	port,
	path,
	msg,
	cb,
	method = HTTPClient.METHOD_GET,
	isRaw = false,
	isReqAgain = true,
	headers = []
):
	var http = HTTPClient.new()
	var err = http.connect_to_host(host, port)
	assert(err == OK)  # Make sure connection is OK.
	# Wait until resolved and connected.
	while (
		http.get_status() == HTTPClient.STATUS_CONNECTING
		or http.get_status() == HTTPClient.STATUS_RESOLVING
	):
		http.poll()
		#print("Connecting...")
		await get_tree().process_frame
		#if not OS.has_feature("web"):
		#OS.delay_msec(500)
		#else:
		#await get_tree().process_frame
		#yield(Engine.get_main_loop(), "idle_frame")

	#assert(http.get_status() == HTTPClient.STATUS_CONNECTED) # Check if the connection was made successfully.
	if not headers.has("User-Agent:"):
		headers.append("User-Agent: Pirulo/1.0 (Godot)")
	if not headers.has("Accept:"):
		headers.append("Accept: */*")
	if not headers.has("Access-Control-Allow-Origin:"):
		headers.append("Access-Control-Allow-Origin: *")
	var query_string = http.query_string_from_dict(msg)
	if method == HTTPClient.METHOD_GET:
		if not path.ends_with("?") and (msg != {} or msg == null):
			path += "?"
		path += query_string
	elif method == HTTPClient.METHOD_POST:
		if not headers.has("Content-Type:"):
			headers.append("Content-Type:application/x-www-form-urlencoded")
		if not headers.has("Content-Length:"):
			headers.append("Content-Length: " + str(query_string.length()))
	reqId += 1
	var state = 1
	if err != OK:
		state = 4

	reqs[reqId] = {
		http = http,
		host = host,
		port = port,
		state = state,
		msg = msg,
		method = method,
		cbObj = cb,
		cb = Callable(cb.instance, cb.f),
		path = path,
		err = err,
		headers = headers,
		isRaw = isRaw,
		isAgain = isReqAgain,
		rb = PackedByteArray()
	}
