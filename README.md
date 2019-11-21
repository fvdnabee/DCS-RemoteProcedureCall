# DCS-Remote Procedure Call
This script listens on a local UDP socket for RPC messages. By sending UDP messages from an external program a simple RPC method is realised.    

# Installation
Copy DCS-RemoteProcedureCall.lua to your server environment's Scripts folder.
Copy DCS-RPC-hook.lua to your server environment's Scripts/Hooks folder

# Testing
You may test with a simple UDP client (e.g. ncat-portable) by sending UDP messages to localhost:9501 (default port):
`ncat.exe -u localhost 9501`
Wireshark and dcs.log may are recommended debugging tools.

# Implemented RPC messages (v0.3):
* `!N<MSG>\n`: Send in-game notications via trigger.action.outText(). If succesfull, '0|OK\n' is returned as response
* '!S\n': Request server status. If succesfull, response is formated as: '0|DCS_SERVER_NAME,DCS server,DCS_THEATHER,caucasus,DCS_MISSION_NAME,through-the-inferno,DCS_REAL_TIME,600.0,DCS_PLAYER_LIST,player;player2,DCS_VERSION:2.5.5.39384\n'

# PING/PONG mechanism (v0.2+):
* 'PING\n' messages will be answered with a 'PONG\n' response if the server is up and running.
