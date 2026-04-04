"""WayFinder 2.0 API — App Config"""
from django.apps import AppConfig


class ApiConfig(AppConfig):
    default_auto_field = "django.db.models.BigAutoField"
    name = "api"
    verbose_name = "WayFinder 2.0 API"
