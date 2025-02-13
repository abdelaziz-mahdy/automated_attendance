import asyncio
from server import CameraProviderServer

async def main():
    server = CameraProviderServer()
    try:
        await server.start()
        # Keep the server running
        while True:
            await asyncio.sleep(1)
    except KeyboardInterrupt:
        await server.stop()

if __name__ == "__main__":
    asyncio.run(main())