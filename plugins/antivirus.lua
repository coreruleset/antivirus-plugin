-- Binary packing of numbers into big-endian 4 byte integer (>I4),
-- added for compatibility with Lua version < 5.3.
function clamav_pack_chunk_length(x)
	local bytes = {}
	for j = 1, 4 do
		table.insert(bytes, string.char(x % (2 ^ 8)))
		x = math.floor(x / (2 ^ 8))
	end
	return string.reverse(table.concat(bytes))
end

function main(filename_or_data)
	pcall(require, "m")
	local connect_type = m.getvar("tx.antivirus-plugin_clamav_connect_type")
	if connect_type == "socket" then
		module_name = "socket.unix"
	elseif connect_type == "tcp" then
		module_name = "socket"
	else
		m.log(2, string.format("Antivirus Plugin ERROR: Invalid value '%s' for 'tx.antivirus-plugin_clamav_connect_type' in antivirus-config.conf.", connect_type))
		return nil
	end
	local ok, socket = pcall(require, module_name)
	if not ok then
		m.log(2, "Antivirus Plugin ERROR: LuaSocket library not installed, please install it or disable this plugin.")
		return nil
	end

	local data_type = m.getvar("tx.antivirus-plugin_data_type")
	if data_type == "file" then
		file_handle = io.open(filename_or_data, "r")
		if file_handle == nil then
			m.log(2, string.format("Antivirus Plugin ERROR: Cannot open uploaded file '%s'.", filename_or_data))
			return nil
		end
		data_size = file_handle:seek("end")
		file_handle:seek("set", 0)
	elseif data_type == "request_body" then
		if filename_or_data == nil then
			data_size = 0
		else
			data_size = string.len(filename_or_data)
		end
		position_from = 1
	else
		m.log(2, "Antivirus Plugin ERROR: Invalid value for 'tx.antivirus-plugin_data_type', probably a misconfiguration or version mismatch.")
		return nil
	end
	-- Empty data, nothing to scan.
	if data_size == 0 then
		return nil
	elseif data_size > tonumber(m.getvar("tx.antivirus-plugin_max_data_size_bytes")) then
		m.log(2, string.format("Antivirus Plugin ERROR: Scan aborted, data are too big (see 'tx.antivirus-plugin_max_data_size_bytes' in antivirus-config.conf), data size: %s bytes.", data_size))
		return nil
	end

	if connect_type == "socket" then
		sck = socket()
	elseif connect_type == "tcp" then
		sck = socket.tcp()
	end
	sck:settimeout(tonumber(m.getvar("tx.antivirus-plugin_network_timeout_seconds", "none")))
	-- Connecting using unix socket file.
	if connect_type == "socket" then
		status, error = sck:connect(m.getvar("tx.antivirus-plugin_clamav_socket_file"))
	-- Connecting using TCP/IP.
	else
		status, error = sck:connect(m.getvar("tx.antivirus-plugin_clamav_address", "none"), tonumber(m.getvar("tx.antivirus-plugin_clamav_port", "none")))
	end
	if not status then
		m.log(2, string.format("Antivirus Plugin ERROR: Error connecting to antivirus: %s.", error))
		return nil
	end

	sck:send("nINSTREAM\n")

	local chunk_size = tonumber(m.getvar("tx.antivirus-plugin_clamav_chunk_size_bytes", "none"))

	-- Data needs to be streamed in chunks prefixed by binary packed chunk size.
	-- Streaming is terminated by sending a zero-length chunk.
	-- Chunk size is configurable but must NOT exceed StreamMaxLength defined in ClamAV configuration file.
	while true do
		-- Scanning of uploaded file.
		if data_type == "file" then
			chunk = file_handle:read(chunk_size)
		-- Scanning of REQUEST_BODY.
		else
			if position_from > data_size then
				chunk = nil
			else
				local position_to = position_from + chunk_size
				if position_to > data_size then
					position_to = data_size
				end
				chunk = string.sub(filename_or_data, position_from, position_to)
				position_from = position_to + 1
			end
		end
		if chunk then
			-- string.pack was introduced in Lua 5.3 but we need to support older versions.
			--sck:send(string.pack(">I4", string.len(chunk)) .. chunk)
			sck:send(clamav_pack_chunk_length(string.len(chunk)) .. chunk)
		else
			--sck:send(string.pack(">I4", 0))
			sck:send(clamav_pack_chunk_length(0))
			break
		end
	end

	if file_handle ~= nil then
		io.close(file_handle)
	end

	local output = ""
	while true do
		local s, status, partial = sck:receive()
		if s then
			output = output .. s
		elseif partial then
			output = output .. partial
		end
		if status == "closed" then
			break
		elseif status == "timeout" then
			m.log(2, "Antivirus Plugin ERROR: Timeout while scanning data.")
			return nil
		end
	end

	sck:close()

	if output == "stream: OK" then
		return nil
	else
		local virus_name = string.match(output, "^stream: (.+) FOUND$")
		if virus_name then
			m.setvar("tx.antivirus-plugin_virus_name", virus_name)
			if data_type == "file" then
				local real_file_name = "<unknown>"
				local files_tmpnames = m.getvars("FILES_TMPNAMES", "none")
				for key, tmpfile in pairs(files_tmpnames) do
					if filename_or_data == tmpfile["value"] then
						local input_name = string.match(tmpfile["name"], "^FILES_TMPNAMES:(.+)$")
						local files = m.getvars("FILES", "none")
						for key2, file in pairs(files) do
							if file["name"] == string.format("FILES:%s", input_name) then
								real_file_name = file["value"]
								break
							end
						end
						break
					end
				end
				m.setvar("tx.antivirus-plugin_file_name", real_file_name)
				return string.format("Antivirus Plugin: Virus %s found in uploaded file %s.", virus_name, real_file_name)
			else
				return string.format("Antivirus Plugin: Virus %s found in request body.", virus_name)
			end
		else
			m.log(2, string.format("Antivirus Plugin ERROR: Unknown response from antivirus: %s.", output))
			return nil
		end
	end
end
