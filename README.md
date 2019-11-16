# DCS-Remote Procedure Call
This script listens on a local UDP socket for RPC messages. By sending UDP messages from an external program a simple RPC method is realised.    

# Installation
Copy DCS-RemoteProcedureCall.lua to your server environment's Scripts folder.
Copy DCS-RPC-hook.lua to your server environment's Scripts/Hooks folder

# Testing
You may test with a simple UDP client (e.g. ncat-portable) by sending UDP messages to localhost:9501 (default port):
`ncat.exe -u localhost 9501`
Wireshark and dcs.log may are recommended debugging tools.

# Implemented RPC messages (v0.1):
* `!N<MSG>\n`: Send in-game notications via trigger.action.outText(). No response is returned (yet).