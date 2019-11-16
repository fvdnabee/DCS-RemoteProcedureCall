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

-- send response
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

			local _received = dcsrpc.UDPReceiveSocket:receive()

			if _received then
				if string.len(_received) >= 2 then
					if _received:sub(1,1) == "!" then  -- RPC received
						dcsrpc.handleRPC(_received)
					end
				end
				
				-- echo incoming message
				socket.try(dcsrpc.UDPSendSocket:sendto("Received:" .. _received .. " \n", "127.0.0.1", dcsrpc.SEND_PORT))
			end
		end)
		
		if not _status then
			net.log('ERROR onSimulationFrame DCSRPC: ' .. _result)
		end
    end

    -- send a PING every 5 seconds
    if _now > _lastSent + 5.0 then
        _lastSent = _now 
        net.log("sending update")
        socket.try(dcsrpc.UDPSendSocket:sendto("PING \n", "127.0.0.1", dcsrpc.SEND_PORT))
    end
end

dcsrpc.handleRPC = function(_received)
	net.log("received RPC call".._received)

	if _received:sub(1,2) == "!N" then  -- send notification
		local _notificationText = _received:sub(3, -2)  -- remove \n char, _notificationText should not contain any double quotes " as this will interfer with dostring_in below, TODO: check/enforce this
		net.log("Triggering outText: \"".._notificationText.."\"")

		local _status, _error = net.dostring_in('server', " return trigger.action.outText(\"".._notificationText.."\", 10); ")

		if not _status and _error then
			net.log("DCSRPC - error on trigger action outText: ".._error)
			-- return false
		else
			net.log("DCSRPC - trigger.action.outText completed succesfully")
		end
	end
end

DCS.setUserCallbacks(dcsrpc)

net.log("Loaded - DCS Remote Procedure Call v".. dcsrpc.version.. " by logion")