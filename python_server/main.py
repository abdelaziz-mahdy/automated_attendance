import asyncio
import argparse
import logging
from server import CameraProviderServer

logger = logging.getLogger(__name__)

async def main():
    # Parse command line arguments
    parser = argparse.ArgumentParser(description='Camera Provider Server for Raspberry Pi and other platforms')
    parser.add_argument('--camera', choices=['auto', 'picamera', 'opencv'], default='auto',
                      help='Camera type to use (auto, picamera, or opencv). Default is auto.')
    
    args = parser.parse_args()
    
    # Set logging level based on arguments
    if args.debug:
        logging.getLogger().setLevel(logging.DEBUG)
    
    logger.info(f"Starting camera provider with camera_type={args.camera}")
    
    # Create and start server with specified camera type
    server = CameraProviderServer(camera_type=args.camera)
    try:
        await server.start()
        # Keep the server running
        while True:
            await asyncio.sleep(1)
    except KeyboardInterrupt:
        logger.info("Keyboard interrupt received, shutting down...")
        await server.stop()
    except Exception as e:
        logger.error(f"Error in server: {e}")
        await server.stop()
        raise

if __name__ == "__main__":
    asyncio.run(main())