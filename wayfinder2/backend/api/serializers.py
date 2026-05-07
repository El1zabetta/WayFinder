"""
WayFinder 2.0 — API Serializers
"""

from rest_framework import serializers
from .models import AssistantInteraction, UserSession, Message


# ─── New Models ───────────────────────────────────────────────────────────────

class SessionSerializer(serializers.ModelSerializer):
    """Serializer for UserSession."""
    message_count = serializers.ReadOnlyField()
    duration_seconds = serializers.ReadOnlyField()

    class Meta:
        model = UserSession
        fields = [
            "id",
            "started_at",
            "ended_at",
            "is_active",
            "device_info",
            "message_count",
            "duration_seconds",
        ]


class MessageSerializer(serializers.ModelSerializer):
    """Serializer for Message (history cards)."""

    class Meta:
        model = Message
        fields = [
            "id",
            "session",
            "question_text",
            "ai_response",
            "frame_snapshot_url",
            "confidence",
            "grounded",
            "source",
            "interaction_type",
            "inference_ms",
            "timestamp",
        ]


class MessageListSerializer(serializers.ModelSerializer):
    """Compact serializer for history list view."""

    class Meta:
        model = Message
        fields = [
            "id",
            "question_text",
            "ai_response",
            "interaction_type",
            "confidence",
            "timestamp",
        ]


# ─── Legacy (backward compatibility) ─────────────────────────────────────────

class InteractionListSerializer(serializers.ModelSerializer):
    """Compact serializer for legacy history list view, backed by Message."""
    question = serializers.CharField(source='question_text')
    answer = serializers.CharField(source='ai_response')
    created_at = serializers.DateTimeField(source='timestamp')

    class Meta:
        model = Message
        fields = [
            "id",
            "question",
            "answer",
            "interaction_type",
            "confidence",
            "created_at",
        ]


class InteractionDetailSerializer(serializers.ModelSerializer):
    """Full serializer for legacy single interaction detail, backed by Message."""
    question = serializers.CharField(source='question_text')
    answer = serializers.CharField(source='ai_response')
    created_at = serializers.DateTimeField(source='timestamp')

    class Meta:
        model = Message
        fields = [
            "id",
            "question",
            "answer",
            "confidence",
            "grounded",
            "source",
            "interaction_type",
            "inference_ms",
            "created_at",
        ]
