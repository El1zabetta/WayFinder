"""WayFinder 2.0 — WebSocket URL routing"""
from django.urls import re_path
from . import consumers

websocket_urlpatterns = [
    re_path(r"ws/navigate/$", consumers.NavigationConsumer.as_asgi()),
]
