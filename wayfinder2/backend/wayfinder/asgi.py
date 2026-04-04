"""
WayFinder 2.0 — ASGI Configuration
Supports HTTP + WebSocket (Django Channels) for real-time video streaming.
"""

import os
from django.core.asgi import get_asgi_application
from channels.routing import ProtocolTypeRouter, URLRouter
from channels.auth import AuthMiddlewareStack

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "wayfinder.settings")

django_asgi_app = get_asgi_application()

from api import routing  # noqa: E402 — import after django setup

application = ProtocolTypeRouter(
    {
        "http": django_asgi_app,
        "websocket": AuthMiddlewareStack(URLRouter(routing.websocket_urlpatterns)),
    }
)
