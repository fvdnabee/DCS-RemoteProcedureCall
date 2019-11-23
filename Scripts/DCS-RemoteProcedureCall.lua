local dcsrpc = {} -- DONT REMOVE!!!

--[[
   DCS Remote Procedure Call - v0.3
   
   Put this file in C:/Users/<YOUR USERNAME>/DCS/Scripts for 1.5 or C:/Users/<YOUR USERNAME>/DCS.openalpha/Scripts for 2.0
   This script listens on a local UDP socket for RPC messages and PING requests. 
   By sending UDP messages from an external program a simple RPC method is realised.    
   The script sends responses to the client, using the same socket. 
   
   Following responses are sent:
   - RPC messages are responsed with "RC|RESPONSE\n" where RC = 0 indicates succes and RC > 0 indicates a failure mode
   - PING messages are responsed with "PONG\n"
--]]

dcsrpc.version = "0.3"

-- Static info about the DCS server instance:
dcsrpc.DCS_SERVER_NAME = "DCS-server"
dcsrpc.DCS_THEATHER = "caucasus"
dcsrpc.DCS_VERSION = "2.5.5.39384"
dcsrpc.RECEIVE_PORT = 9501
dcsrpc.SEND_PORT = 9502


package.path = package.path .. ";.\\LuaSocket\\?.lua;"
package.cpath = package.cpath .. ";.\\LuaSocket\\?.dll;"

local socket = require("socket")

--bind for listening to RPC commands
dcsrpc.UDPReceiveSocket = socket.udp()
dcsrpc.UDPReceiveSocket:setsockname("*", dcsrpc.RECEIVE_PORT)
dcsrpc.UDPReceiveSocket:settimeout(0) --receive timer was 0001

-- send response to multiple clients ('broadcast')
dcsrpc.UDPSendSocket = socket.udp()
dcsrpc.UDPSendSocket:settimeout(0)

local _lastSent = 0;
local _lastReceivedCheck = 0;

dcsrpc.onSimulationFrame = function()
    local _now = DCS.getRealTime()

	-- check every 1 second if we received a new message:
    if _now > _lastReceivedCheck + 1.0 then
        _lastReceivedCheck = _now 
        net.log("DCSRPC - checking UDP socket for new messages")

		-- read from socket
		local _status, _result = pcall(function()

			-- local _received = dcsrpc.UDPReceiveSocket:receive()
			_received, _msg_or_ip, _port_or_nil = dcsrpc.UDPReceiveSocket:receivefrom()

			if _received then
				net.log("DCSRPC - Received message from ".. _msg_or_ip .. ":" .. _port_or_nil)
				if _port_or_nil == nil then -- Fallback to general send port:
					net.log("DCSRPC - _port_or_nil is nil, falling back to default send port: " .. dcsrpc.SEND_PORT)
					_port_or_nil = dcsrpc.SEND_PORT
				end

				if string.len(_received) >= 2 then
					if _received:sub(1,1) == "!" then  -- RPC received
						returncode, response = dcsrpc.handleRPC(_received)

						-- send response over socket:
						net.log("DCSRPC - sending RPC response with rc = " .. returncode .." over UDP socket")
						socket.try(dcsrpc.UDPReceiveSocket:sendto(returncode .. "|" .. response .." \n", _msg_or_ip, _port_or_nil))
					elseif _received:sub(1,4) == "PING" then  -- PING received, reply with PONG (note we don't consider this an RPC request)
						net.log("DCSRPC - received PING, sending PONG response over UDP socket")
						socket.try(dcsrpc.UDPReceiveSocket:sendto("PONG\n", _msg_or_ip, _port_or_nil))
					end
				end
			end
		end)

		if not _status then
			net.log('DCSRPC - ERROR onSimulationFrame: ' .. _result)
		end
    end
end

dcsrpc.handleRPC = function(_received)
	-- Handlers in this function should return two values: returncode and a response. 
	-- A 0 return code indicates succes, non-zero return codes are used to signal different error states.
	net.log("DCSRPC - received RPC call: ".._received)

	method = _received:sub(1,2)
	if method == "!N" then  -- send notification
		local _notificationText = _received:sub(3, -2)  -- remove \n char, _notificationText should not contain any double quotes " as this will interfer with dostring_in below, TODO: check/enforce this
		net.log("DCSRPC - Triggering outText: \"".._notificationText.."\"")

		local _status, _error = net.dostring_in('server', " return trigger.action.outText(\"".._notificationText.."\", 10); ")

		if not _status and _error then
			net.log("DCSRPC - error on trigger action outText: ".._error)
			return 1, "NOK"
		else
			net.log("DCSRPC - trigger.action.outText completed succesfully")
			return 0, "OK"
		end
	elseif method == "!S" then  -- send notification
		local dcsServerName = dcsrpc.getDCSServerName()
		local dcsTheather = dcsrpc.getDCSTheather()
		local dcsRealTime = DCS.getRealTime()
		local dcsPlayerList = dcsrpc.getPlayerList()
		local dcsVersion = dcsrpc.getDCSVersion()
		
		response = "DCS_SERVER_NAME,"..dcsServerName..",DCS_THEATHER,"..dcsTheather..",DCS_MISSION_NAME,through-the-inferno,DCS_REAL_TIME,"..dcsRealTime..",DCS_PLAYER_LIST,"..dcsPlayerList..",DCS_VERSION,"..dcsVersion.."\n"
		return 0, response
	else
		response = "Unknown RPC request: "..method.."\n"
		return 1, response
	end
end

dcsrpc.getDCSServerName = function()
	-- Returns the name of the running DCS server
	-- TODO: get from scripting environment (or serverSettings.lua)
	return dcsrpc.DCS_SERVER_NAME
end

dcsrpc.getDCSTheather = function()
	-- Returns the name of the active theather
	-- TODO: get from scripting environment
	return dcsrpc.DCS_THEATHER
end

dcsrpc.getDCSVersion = function()
	-- Returns the name of the active theather
	-- TODO: get DCS version from the running system, maybe using the env variable?
	return dcsrpc.DCS_VERSION
end

dcsrpc.getPlayerList = function()
	-- Returns a semicolon separated list of player names currently connected to the server
	-- TODO: move to separate lua script
	ssvPlayerList = ""  -- semicolon separated values Player list
	local playerList = net.get_player_list()
	for playerIDIndex, playerID in pairs(playerList)
	do 
		local _playerDetails = net.get_player_info( playerID )
		ssvPlayerList = ssvPlayerList .. _playerDetails.name .. ";"
	end
	ssvPlayerList = ssvPlayerList:sub(1, -2)  -- remove last semicolon
	net.log("DCSRPC - getPlayerList(): "..ssvPlayerList)

	return ssvPlayerList
end

DCS.setUserCallbacks(dcsrpc)

net.log("Loaded - DCS Remote Procedure Call v".. dcsrpc.version.. " by logion")