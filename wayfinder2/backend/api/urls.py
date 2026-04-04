"""
WayFinder 2.0 — API URL Routing
"""

from django.urls import path
from . import views

urlpatterns = [
    # Core analysis
    path("analyze/video/", views.analyze_video, name="analyze-video"),
    path("analyze/image/", views.analyze_image, name="analyze-image"),

    # Specialized RynnBrain modes
    path("navigate/", views.navigate, name="navigate"),
    path("threats/", views.detect_threats, name="detect-threats"),
    path("search/", views.search_object, name="search-object"),

    # Ask-Wayfinder: natural language scene QA
    path("ask/", views.ask_wayfinder, name="ask-wayfinder"),

    # Sessions & Messages (new)
    path("session/start/", views.session_start, name="session-start"),
    path("session/<int:session_id>/end/", views.session_end, name="session-end"),
    path("message/save/", views.message_save, name="message-save"),
    path("messages/", views.messages_history, name="messages-history"),
    path("messages/<int:message_id>/", views.message_detail, name="message-detail"),

    # Legacy history (backward compat)
    path("history/", views.history_list, name="history-list"),
    path("history/<int:interaction_id>/", views.history_detail, name="history-detail"),

    # System
    path("health/", views.health, name="health"),
]
