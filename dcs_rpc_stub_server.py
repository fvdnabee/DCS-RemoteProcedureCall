#!/usr/bin/env python
""" A stub server for the DCS-RPC lua UDP server. Used to facilitate developing and testing """
import argparse
import asyncio

DCS_SERVER_NAME = "server-caucusus"


class DCSRPCStubServerProtocol:
    """ asyncio server protocol class for stub server """
    def __init__(self):
        self.transport = None

    def connection_made(self, transport):
        """ Connection established """
        self.transport = transport

    def datagram_received(self, data, addr):
        """ datagram received """
        message = data.decode()
        print('Received %r from %s' % (message, addr))
        if len(message) >= 2:
            if message[0] == "!":
                return_code, result = self.handle_rpc(message)
                response = "{}|{}".format(return_code, result)
            elif message[0:4] == "PING":
                response = "PONG\n"

            print('Sending %r to %s' % (response, addr))
            self.transport.sendto(response.encode(), addr)

    @classmethod
    def handle_rpc(cls, message):
        """ handle rpc requests """
        if message[0:2] == "!N":  # ingame notification
            return_code, result = (0, "OK\n")
        elif message[0:2] == "!S":  # reply with server status
            return_code = 0
            result = (f"DCS_SERVER_NAME,{DCS_SERVER_NAME},DCS_THEATHER,caucasus,"
                      "DCS_MISSION_NAME,through-the-inferno,DCS_REAL_TIME,22000,"
                      "DCS_PLAYER_LIST,logion;slasse;F0X,DCS_VERSION:2.5.5.39384\n")
        else:
            return_code = 1
            result = "Unknown RPC request: {}\n".format(message[0:2])

        return return_code, result


async def async_main(stub_server_addr):
    """ main method, supporting asyncio """
    print(f"Starting DCS-RPC stub server, listening on {stub_server_addr[0]}:{stub_server_addr[1]}")

    # Get a reference to the event loop as we plan to use
    # low-level APIs.
    loop = asyncio.get_running_loop()

    # One protocol instance will be created to serve all
    # client requests.
    transport, _ = await loop.create_datagram_endpoint(
        DCSRPCStubServerProtocol,
        local_addr=stub_server_addr)

    try:
        await asyncio.sleep(3600)  # Serve for 1 hour.
    finally:
        transport.close()


def main():
    """ Main function """
    parser = argparse.ArgumentParser("Run a stub server that emulates the DCS RPC LUA script UDP server socket")
    parser.add_argument('--ip', help="IP address for the stub server's UDP socket.", default="127.0.0.1")
    parser.add_argument('--port', help="Port for the stub server's UDP socket.", type=int, default=9501)
    args = parser.parse_args()

    asyncio.run(async_main((args.ip, args.port)))


if __name__ == "__main__":
    main()
