"""
WayFinder 2.0 — Data Models
Persistent storage for sessions and assistant interactions scoped by Firebase user.
"""

from django.db import models
from django.utils import timezone


class UserSession(models.Model):
    """
    A usage session — groups multiple messages/interactions together.
    Created when the user opens the app or starts a new navigation session.
    """

    firebase_uid = models.CharField(max_length=128, db_index=True)

    # Session metadata
    started_at = models.DateTimeField(default=timezone.now, db_index=True)
    ended_at = models.DateTimeField(null=True, blank=True)
    is_active = models.BooleanField(default=True)

    # Optional device/context info
    device_info = models.CharField(max_length=256, blank=True, default="")

    class Meta:
        ordering = ["-started_at"]
        indexes = [
            models.Index(fields=["firebase_uid", "-started_at"]),
        ]

    def __str__(self):
        return f"Session {self.id} [{self.firebase_uid[:8]}] {self.started_at:%Y-%m-%d %H:%M}"

    @property
    def duration_seconds(self):
        if self.ended_at:
            return (self.ended_at - self.started_at).total_seconds()
        return (timezone.now() - self.started_at).total_seconds()

    @property
    def message_count(self):
        return self.messages.count()


class Message(models.Model):
    """
    A single Q&A message between a user and WayFinder AI.
    Linked to a UserSession and scoped by Firebase UID.
    """

    # User identity
    firebase_uid = models.CharField(max_length=128, db_index=True)

    # Session link
    session = models.ForeignKey(
        UserSession,
        on_delete=models.CASCADE,
        related_name="messages",
        null=True,
        blank=True,
    )

    # Content
    question_text = models.TextField()
    ai_response = models.TextField()

    # Optional frame snapshot (URL to stored image)
    frame_snapshot_url = models.URLField(max_length=512, blank=True, default="")

    # Metadata
    confidence = models.FloatField(default=0.0)
    grounded = models.BooleanField(default=False)
    source = models.CharField(max_length=32, blank=True, default="")
    interaction_type = models.CharField(max_length=16, default="ask")
    inference_ms = models.FloatField(null=True, blank=True)

    # Timestamps
    timestamp = models.DateTimeField(default=timezone.now, db_index=True)

    class Meta:
        ordering = ["-timestamp"]
        indexes = [
            models.Index(fields=["firebase_uid", "-timestamp"]),
            models.Index(fields=["session", "-timestamp"]),
        ]

    def __str__(self):
        return f"[{self.firebase_uid[:8]}] {self.question_text[:50]}..."


# ─── Legacy model (kept for backward compatibility with existing migrations) ──

class AssistantInteraction(models.Model):
    """
    Legacy: A single Q&A interaction between a user and WayFinder.
    Kept for backward compatibility. New code should use Message model.
    """

    firebase_uid = models.CharField(max_length=128, db_index=True)
    question = models.TextField()
    answer = models.TextField()
    confidence = models.FloatField(default=0.0)
    grounded = models.BooleanField(default=False)
    source = models.CharField(max_length=32, blank=True, default="")
    interaction_type = models.CharField(max_length=16, default="ask")
    inference_ms = models.FloatField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True, db_index=True)

    class Meta:
        ordering = ["-created_at"]
        indexes = [
            models.Index(fields=["firebase_uid", "-created_at"]),
        ]

    def __str__(self):
        return f"[{self.firebase_uid[:8]}] {self.question[:50]}..."
