"""
WayFinder 2.0 — Firebase Authentication for Django REST Framework

Validates Firebase ID tokens from the Flutter app's Authorization header.
Attaches decoded Firebase claims (uid, email) to request.auth.

Usage:
  - Set as default auth in settings.py REST_FRAMEWORK config
  - Or apply per-view with @authentication_classes([FirebaseAuthentication])

Requires:
  - firebase-admin package
  - GOOGLE_APPLICATION_CREDENTIALS env var pointing to service account JSON
    OR FIREBASE_CREDENTIALS_JSON env var with the JSON content directly
"""

import logging
import os
import json

import firebase_admin
from firebase_admin import auth as firebase_auth, credentials

from rest_framework.authentication import BaseAuthentication
from rest_framework.exceptions import AuthenticationFailed

logger = logging.getLogger(__name__)

# ─── Firebase Admin SDK Initialization ────────────────────────────────────────

_firebase_app = None


def _initialize_firebase():
    """
    Initialize Firebase Admin SDK once.
    Supports two modes:
      1. GOOGLE_APPLICATION_CREDENTIALS env var (path to service account JSON)
      2. FIREBASE_CREDENTIALS_JSON env var (JSON string, useful for Docker/Render)
    """
    global _firebase_app

    if _firebase_app is not None:
        return _firebase_app

    # Already initialized by another module
    if firebase_admin._apps:
        _firebase_app = firebase_admin.get_app()
        return _firebase_app

    cred = None

    # Option 1: JSON string in env var (for cloud deployments)
    json_str = os.environ.get("FIREBASE_CREDENTIALS_JSON")
    if json_str:
        try:
            cred_dict = json.loads(json_str)
            cred = credentials.Certificate(cred_dict)
            logger.info("[Firebase] Initialized from FIREBASE_CREDENTIALS_JSON env var.")
        except Exception as e:
            logger.error(f"[Firebase] Failed to parse FIREBASE_CREDENTIALS_JSON: {e}")

    # Option 2: File path via GOOGLE_APPLICATION_CREDENTIALS or local file
    if cred is None:
        default_path = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "wayfinder-483708-firebase-adminsdk-fbsvc-e94ec7bd43.json")
        cred_path = os.environ.get("GOOGLE_APPLICATION_CREDENTIALS", default_path)
        if cred_path and os.path.isfile(cred_path):
            try:
                cred = credentials.Certificate(cred_path)
                logger.info(f"[Firebase] Initialized from file: {cred_path}")
            except Exception as e:
                logger.error(f"[Firebase] Failed to load credentials file: {e}")

    # Option 3: Application Default Credentials (GCP environments)
    if cred is None:
        try:
            cred = credentials.ApplicationDefault()
            logger.info("[Firebase] Initialized with Application Default Credentials.")
        except Exception:
            pass

    if cred is None:
        logger.warning(
            "[Firebase] No credentials found. Set GOOGLE_APPLICATION_CREDENTIALS "
            "or FIREBASE_CREDENTIALS_JSON. Auth will reject all requests."
        )
        return None

    try:
        options = {
            'projectId': 'wayfinder-483708',
        }
        _firebase_app = firebase_admin.initialize_app(cred, options=options)
        return _firebase_app
    except Exception as e:
        logger.error(f"[Firebase] SDK initialization failed: {e}")
        return None


# Initialize on module import
_initialize_firebase()


# ─── DRF Authentication Class ────────────────────────────────────────────────


class FirebaseUser:
    """
    Lightweight user object attached to request.user.
    Contains decoded Firebase token claims.
    """

    def __init__(self, uid: str, email: str = "", name: str = "", claims: dict = None):
        self.uid = uid
        self.pk = uid  # DRF compatibility
        self.id = uid
        self.email = email
        self.name = name
        self.claims = claims or {}
        self.is_authenticated = True
        self.is_active = True
        self.is_anonymous = False

    def __str__(self):
        return f"FirebaseUser({self.uid}, {self.email})"


class FirebaseAuthentication(BaseAuthentication):
    """
    DRF authentication backend that validates Firebase ID tokens.

    Expects header: Authorization: Bearer <firebase_id_token>
    On success: sets request.user = FirebaseUser, request.auth = decoded_token
    On failure: raises AuthenticationFailed (HTTP 401)
    """

    keyword = "Bearer"

    def authenticate(self, request):
        auth_header = request.META.get("HTTP_AUTHORIZATION", "")

        if not auth_header:
            # No auth header — let DRF's permission classes handle it
            return None

        parts = auth_header.split()

        if len(parts) != 2 or parts[0] != self.keyword:
            raise AuthenticationFailed(
                "Invalid authorization header. Expected: 'Bearer <token>'"
            )

        token = parts[1]

        # ─── Dev Auth Mode ────────────────────────────────────────────
        # Only available when DEBUG=True AND ALLOW_DEV_AUTH=True
        # Accepts 'Bearer dev-token' for local development without Firebase.
        # NEVER enabled in production.
        from django.conf import settings
        if (getattr(settings, 'DEBUG', False) and
                os.environ.get('ALLOW_DEV_AUTH', '').lower() in ('true', '1', 'yes')):
            if token == 'dev-token':
                logger.warning("[Firebase Auth] DEV AUTH MODE — skipping Firebase validation.")
                user = FirebaseUser(
                    uid='dev-user-001',
                    email='dev@wayfinder.local',
                    name='Dev User',
                    claims={'dev_mode': True},
                )
                return (user, {'uid': 'dev-user-001', 'dev_mode': True})

        if not _firebase_app:
            raise AuthenticationFailed(
                "Firebase is not configured on this server. Contact the administrator."
            )

        try:
            decoded = firebase_auth.verify_id_token(token, app=_firebase_app)
        except firebase_auth.ExpiredIdTokenError:
            raise AuthenticationFailed("Firebase token has expired. Please sign in again.")
        except firebase_auth.RevokedIdTokenError:
            raise AuthenticationFailed("Firebase token has been revoked.")
        except firebase_auth.InvalidIdTokenError:
            raise AuthenticationFailed("Invalid Firebase token.")
        except Exception as e:
            logger.error(f"[Firebase Auth] Token verification failed: {e}")
            raise AuthenticationFailed("Could not verify authentication token.")

        uid = decoded.get("uid", "")
        email = decoded.get("email", "")
        name = decoded.get("name", "")

        user = FirebaseUser(uid=uid, email=email, name=name, claims=decoded)

        logger.debug(f"[Firebase Auth] Authenticated: {uid} ({email})")

        return (user, decoded)

    def authenticate_header(self, request):
        """
        Return a string to be used as the value of the WWW-Authenticate header
        in a 401 response.
        """
        return 'Bearer realm="wayfinder"'
