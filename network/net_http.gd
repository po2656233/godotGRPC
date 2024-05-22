extends Node

var reqId = 0
var reqs = {}

func _ready():
	set_process(true)
	
func _process(_d):
	for key in reqs.keys():
		var req = reqs[key]
		if req.state == 1:
			if req.http.get_status()==HTTPClient.STATUS_CONNECTING or req.http.get_status()==HTTPClient.STATUS_RESOLVING:
				req.http.poll()
			else:
				if req.http.get_status() != HTTPClient.STATUS_CONNECTED:
					req.state = 4
					req.err = 'err when connecting.'
				else:
					req.err = req.http.request(req.method,req.path,req.headers,req.http.query_string_from_dict(req.msg))
					if req.err == OK:
						req.state = 2
					else:
						req.state = 4
		elif req.state == 2:
			if req.http.get_status() == HTTPClient.STATUS_REQUESTING:
				req.http.poll()
			else:
				if req.http.get_status() != HTTPClient.STATUS_BODY and req.http.get_status() != HTTPClient.STATUS_CONNECTED:
					req.state = 4
					req.err = 'err when request.'
				else:
					if req.http.has_response():
						req.state = 3
					else:
						req.state = 4
		elif req.state == 3:
			if req.http.get_status()==HTTPClient.STATUS_BODY:
				req.http.poll()
				var chunk = req.http.read_response_body_chunk()
				if chunk.size()==0:
					await get_tree().process_frame
					pass
				else:
					req.rb = req.rb + chunk
			else:
				req.state = 4
		else:
			if req.err != OK:
				print('http err:',req.err)
			else:
				if req.isRaw:
					req.cb.call(req.rb)
				else:
					req.cb.call(req.rb.get_string_from_utf8())
			reqs.erase(key)
			print('cur http reqs size:',reqs.size())

###############################[外部接口]#################################################
func Request(host,port,path, msg, cb, method = HTTPClient.METHOD_GET,isRaw = false):
	var http = HTTPClient.new()
	var err = http.connect_to_host(host,port)
	assert(err == OK) # Make sure connection is OK.
	# Wait until resolved and connected.
	while http.get_status() == HTTPClient.STATUS_CONNECTING or http.get_status() == HTTPClient.STATUS_RESOLVING:
		http.poll()
		print("Connecting...")
		await get_tree().process_frame
		#else:
			#yield(Engine.get_main_loop(), "idle_frame")
			
	#assert(http.get_status() == HTTPClient.STATUS_CONNECTED) # Check if the connection was made successfully.
	var headers=[
		"User-Agent: Pirulo/1.0 (Godot)",
		"Accept: */*",
		"Access-Control-Allow-Origin: *"
		]
	var query_string = http.query_string_from_dict(msg)
	if method == HTTPClient.METHOD_GET:
		if not path.ends_with("?") and (msg != {} or msg == null):
			path+="?"
		path += query_string
	elif method == HTTPClient.METHOD_POST:
		headers=[
		"User-Agent: Pirulo/1.0 (Godot)",
		"Accept: */*",
		"Access-Control-Allow-Origin: *",
		"Content-Type:application/x-www-form-urlencoded",
		"Content-Length: " + str(query_string.length())
		]
	reqId += 1
	var state = 1
	if err != OK:
		state = 4
	
	reqs[reqId] = {
		http=http,
		state = state,
		msg = msg,
		method = method,
		cb = Callable(cb.instance,cb.f),
		path = path,
		err = err,
		headers = headers,
		isRaw = isRaw,
		rb = PackedByteArray()
	}

