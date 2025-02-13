import asyncio
from aiohttp import web
from zeroconf import ServiceInfo, Zeroconf
import socket
import logging
from camera_provider import LocalCameraProvider

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class CameraProviderServer:
    def __init__(self):
        self._server = None
        self._zeroconf = None
        self._service_info = None
        self.camera_provider = LocalCameraProvider(0)
        
    async def _handle_test(self, request):
        return web.Response(status=200)
        
    async def _handle_get_image(self, request):
        if not self.camera_provider.is_open:
            return web.Response(status=500)
            
        frame = await self.camera_provider.get_frame()
        if frame is None:
            return web.Response(status=500)
            
        return web.Response(body=frame, content_type='image/jpeg')
        
    async def start(self):
        try:
            # Initialize camera
            success = await self.camera_provider.open_camera()
            if not success:
                raise Exception("Failed to open camera")
            
            # Create web application
            app = web.Application()
            app.router.add_get('/test', self._handle_test)
            app.router.add_get('/get_image', self._handle_get_image)
            
            # Start server
            runner = web.AppRunner(app)
            await runner.setup()
            site = web.TCPSite(runner, '0.0.0.0', 12345)
            await site.start()
            
            # Register zeroconf service
            self._zeroconf = Zeroconf()
            self._service_info = ServiceInfo(
                "_camera._tcp.local.",
                "PythonCameraProvider._camera._tcp.local.",
                addresses=[socket.inet_aton("0.0.0.0")],
                port=12345,
                properties={},
            )
            self._zeroconf.register_service(self._service_info)
            
            logger.info(f"Server started at http://0.0.0.0:12345")
            
        except Exception as e:
            logger.error(f"Error starting server: {e}")
            await self.stop()
            raise
            
    async def stop(self):
        if self._zeroconf and self._service_info:
            self._zeroconf.unregister_service(self._service_info)
            self._zeroconf.close()
            
        if self.camera_provider:
            await self.camera_provider.close_camera()
            
        logger.info("Server stopped")