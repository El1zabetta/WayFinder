"""
WayFinder 2.0 — Celery Configuration
Handles background RynnBrain-2B inference tasks to avoid blocking WebSockets.
"""

import os
from celery import Celery

# Set default Django settings
os.environ.setdefault("DJANGO_SETTINGS_MODULE", "wayfinder.settings")

app = Celery("wayfinder")

# Read config from Django settings, using a CELERY_ namespace
app.config_from_object("django.conf:settings", namespace="CELERY")

# Auto-discover tasks in all installed apps
app.autodiscover_tasks()
