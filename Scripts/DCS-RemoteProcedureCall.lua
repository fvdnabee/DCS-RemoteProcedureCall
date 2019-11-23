local dcsrpc = {} -- DONT REMOVE!!!

--[[
   DCS Remote Procedure Call - v0.4
   
   Put this file in C:/Users/<YOUR USERNAME>/DCS/Scripts for 1.5 or C:/Users/<YOUR USERNAME>/DCS.openalpha/Scripts for 2.0
   This script listens on a local UDP socket for RPC messages and PING requests. 
   By sending UDP messages from an external program a simple RPC method is realised.    
   The script sends responses to the client, using the same socket. 
   
   Following responses are sent:
   - RPC messages are responsed with "RC|RESPONSE\n" where RC = 0 indicates succes and RC > 0 indicates a failure mode
   - PING messages are responsed with "PONG\n"
--]]


-- Static info about the DCS server instance (feel free to edit):
dcsrpc.DCS_SERVER_NAME_OVERRIDE = nil  -- if different than nil, then this setting overwrites the server name from serverSettings.lua
dcsrpc.DCS_THEATHER = "caucasus"  -- currently hardcoded, set to the theather of the server
dcsrpc.DCS_VERSION = "2.5.5.39384"  -- currently hardcoded, set to the DCS runtime environment version of the server
dcsrpc.RECEIVE_PORT = 9501
dcsrpc.SEND_PORT = 9502

--------------------------------------------------------------------------------------------------------------------------------------
-- Edit below this line at your own risk!
dcsrpc.version = "0.4"

package.path = package.path .. ";.\\LuaSocket\\?.lua;"
package.cpath = package.cpath .. ";.\\LuaSocket\\?.dll;"

local socket = require("socket")
local Tools = require('tools')

-- Bind for listening to RPC commands
dcsrpc.UDPReceiveSocket = socket.udp()
dcsrpc.UDPReceiveSocket:setsockname("*", dcsrpc.RECEIVE_PORT)
dcsrpc.UDPReceiveSocket:settimeout(0) --receive timer was 0001

-- send response to multiple clients ('broadcast')
dcsrpc.UDPSendSocket = socket.udp()
dcsrpc.UDPSendSocket:settimeout(0)

local _lastSent = 0;
local _lastReceivedCheck = 0;

-- Read cfg from serverSettings.lua
dcsrpc.serverName = ""
dcsrpc.serverSettingsConfig = nil
dcsrpc.readServerSettings = false

dcsrpc.onSimulationStart = function()
	-- read serverSettings.lua from Config folder
	if not dcsrpc.serverSettings then
		local serverSettingsConfig = Tools.safeDoFile(lfs.writedir() .. 'Config/serverSettings.lua', false)
		if serverSettingsConfig then
			dcsrpc.serverSettingsConfig = serverSettingsConfig.cfg
		end
	end

	-- set serverName
	if DCS_SERVER_NAME_OVERRIDE ~= nil and DCS_SERVER_NAME_OVERRIDE ~= "" then
		dcsrpc.serverName = dcsrpc.DCS_SERVER_NAME_OVERRIDE
	else
		if dcsrpc.serverSettingsConfig ~= nil then
			dcsrpc.serverName = dcsrpc.serverSettingsConfig["name"]
		else
			dcsrpc.serverName = "DCS-server"  -- fallback server name
		end
	end
end

dcsrpc.onSimulationFrame = function()
    local _now = DCS.getRealTime()

	-- check every 1 second if we received a new message:
    if _now > _lastReceivedCheck + 1.0 then
        _lastReceivedCheck = _now 
        -- net.log("DCSRPC - checking UDP socket for new messages")

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
	-- net.log("DCSRPC - received RPC call: ".._received)

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
		local dcsMission = dcsrpc.getDCSMissionName()
		local dcsRealTime = DCS.getRealTime()
		local dcsPlayerList = dcsrpc.getPlayerList()
		local dcsVersion = dcsrpc.getDCSVersion()
		
		response = "DCS_SERVER_NAME,"..dcsServerName..",DCS_THEATHER,"..dcsTheather..",DCS_MISSION_NAME,"..dcsMission..",DCS_REAL_TIME,"..dcsRealTime..",DCS_PLAYER_LIST,"..dcsPlayerList..",DCS_VERSION,"..dcsVersion.."\n"
		return 0, response
	else
		response = "Unknown RPC request: "..method.."\n"
		return 1, response
	end
end

dcsrpc.getDCSServerName = function()
	-- Returns the name of the running DCS server
	return dcsrpc.serverName
end

dcsrpc.getDCSTheather = function()
	-- Returns the name of the active theather
	-- TODO: get from scripting environment
	return dcsrpc.DCS_THEATHER
end

dcsrpc.getDCSMissionName = function()
	-- Returns the name of the active mission
	local missionName = DCS.getMissionName()

	return missionName
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

	return ssvPlayerList
end

DCS.setUserCallbacks(dcsrpc)

net.log("Loaded - DCS Remote Procedure Call v".. dcsrpc.version.. " by logion")