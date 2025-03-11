import asyncio
from aiohttp import web
from zeroconf.asyncio import AsyncZeroconf
import socket
import logging
from camera_provider import create_camera_provider
from zeroconf import ServiceInfo
import datetime
import argparse

# Configure logging with more detail
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    datefmt='%Y-%m-%d %H:%M:%S'
)
logger = logging.getLogger(__name__)

class CameraProviderServer:
    def __init__(self, camera_type='auto', camera_index=0):
        self._server = None
        self._zeroconf = None
        self._service_info = None
        self._camera_type = camera_type
        self._camera_index = camera_index
        self.camera_provider = None  # Will be initialized in start()
        self._request_count = 0
        
    async def _handle_test(self, request):
        self._request_count += 1
        start_time = datetime.datetime.now()
        logger.info(f"[Request #{self._request_count}] Received TEST request from {request.remote}")
        response = web.Response(status=200)
        elapsed = (datetime.datetime.now() - start_time).total_seconds() * 1000
        logger.info(f"[Request #{self._request_count}] Handled TEST request in {elapsed:.2f}ms")
        return response
        
    async def _handle_get_image(self, request):
        self._request_count += 1
        start_time = datetime.datetime.now()
        logger.info(f"[Request #{self._request_count}] Received GET_IMAGE request from {request.remote}")
        
        if not self.camera_provider.is_open:
            logger.error(f"[Request #{self._request_count}] Camera is not open")
            return web.Response(status=500)
            
        frame = await self.camera_provider.get_frame()
        if frame is None:
            logger.error(f"[Request #{self._request_count}] Failed to capture frame")
            return web.Response(status=500)
        
        response = web.Response(body=frame, content_type='image/jpeg')
        elapsed = (datetime.datetime.now() - start_time).total_seconds() * 1000
        logger.info(f"[Request #{self._request_count}] Successfully handled GET_IMAGE request in {elapsed:.2f}ms")
        return response
        
    async def start(self):
        try:
            logger.info("Starting Camera Provider Server...")
            
            # Initialize camera using factory function
            logger.info(f"Initializing camera (type: {self._camera_type}, index: {self._camera_index})...")
            self.camera_provider = create_camera_provider(
                camera_type=self._camera_type,
                camera_index=self._camera_index
            )
            
            success = await self.camera_provider.open_camera()
            if not success:
                raise Exception("Failed to open camera")
            logger.info("Camera initialized successfully")
            
            # Create web application
            logger.info("Setting up web application...")
            app = web.Application()
            app.router.add_get('/test', self._handle_test)
            app.router.add_get('/get_image', self._handle_get_image)
            
            # Start server
            runner = web.AppRunner(app)
            await runner.setup()
            site = web.TCPSite(runner, '0.0.0.0', 12345)
            await site.start()
            logger.info("HTTP server started at http://0.0.0.0:12345")
            
            # Register zeroconf service
            logger.info("Registering Zeroconf service...")
            self._zeroconf = AsyncZeroconf()
            service_name = "PythonCameraProvider"
            service_type = "_camera._tcp.local."
            
            self._service_info = ServiceInfo(
                service_type,
                f"{service_name}.{service_type}",
                addresses=[socket.inet_aton("0.0.0.0")],
                port=12345,
                properties={
                    "server_type": "python",
                    "version": "1.0",
                    "camera_type": self._camera_type,
                },
            )
            
            await self._zeroconf.async_register_service(self._service_info)
            logger.info(f"Zeroconf service registered successfully:")
            logger.info(f"  - Service Name: {service_name}")
            logger.info(f"  - Service Type: {service_type}")
            logger.info(f"  - Port: 12345")
            logger.info(f"  - Properties: {self._service_info.properties}")
            logger.info("Server is now fully operational")
            
        except Exception as e:
            logger.error(f"Error starting server: {e}")
            await self.stop()
            raise
            
    async def stop(self):
        logger.info("Stopping Camera Provider Server...")
        
        if self._zeroconf and self._service_info:
            logger.info("Unregistering Zeroconf service...")
            await self._zeroconf.async_unregister_service(self._service_info)
            await self._zeroconf.async_close()
            logger.info("Zeroconf service unregistered")
            
        if self.camera_provider:
            logger.info("Closing camera...")
            await self.camera_provider.close_camera()
            logger.info("Camera closed")
            
        logger.info("Server stopped successfully")