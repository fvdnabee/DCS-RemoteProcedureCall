local dcsrpc = {} -- DONT REMOVE!!!

--[[
   DCS Remote Procedure Call - v0.1
   
   Put this file in C:/Users/<YOUR USERNAME>/DCS/Scripts for 1.5 or C:/Users/<YOUR USERNAME>/DCS.openalpha/Scripts for 2.0
   This script listens on a local UDP socket for RPC messages. 
   By sending UDP messages from an external program a simple RPC method is realised.    
--]]

dcsrpc.version = "0.1"

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
	-- Hanlders in this function should return two values: returncode and a response. 
	-- A 0 return code indicates succes, non-zero return codes are used to signal different error states.
	net.log("DCSRPC - received RPC call: ".._received)

	if _received:sub(1,2) == "!N" then  -- send notification
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
	end
end

DCS.setUserCallbacks(dcsrpc)

net.log("Loaded - DCS Remote Procedure Call v".. dcsrpc.version.. " by logion")