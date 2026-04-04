# Generated migration for UserSession and Message models

from django.db import migrations, models
import django.db.models.deletion
import django.utils.timezone


class Migration(migrations.Migration):

    dependencies = [
        ("api", "0001_initial"),
    ]

    operations = [
        # ─── UserSession ─────────────────────────────────────────────────────
        migrations.CreateModel(
            name="UserSession",
            fields=[
                ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),
                ("firebase_uid", models.CharField(db_index=True, max_length=128)),
                ("started_at", models.DateTimeField(db_index=True, default=django.utils.timezone.now)),
                ("ended_at", models.DateTimeField(blank=True, null=True)),
                ("is_active", models.BooleanField(default=True)),
                ("device_info", models.CharField(blank=True, default="", max_length=256)),
            ],
            options={
                "ordering": ["-started_at"],
            },
        ),
        migrations.AddIndex(
            model_name="usersession",
            index=models.Index(fields=["firebase_uid", "-started_at"], name="api_userses_firebas_idx"),
        ),

        # ─── Message ─────────────────────────────────────────────────────────
        migrations.CreateModel(
            name="Message",
            fields=[
                ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),
                ("firebase_uid", models.CharField(db_index=True, max_length=128)),
                ("question_text", models.TextField()),
                ("ai_response", models.TextField()),
                ("frame_snapshot_url", models.URLField(blank=True, default="", max_length=512)),
                ("confidence", models.FloatField(default=0.0)),
                ("grounded", models.BooleanField(default=False)),
                ("source", models.CharField(blank=True, default="", max_length=32)),
                ("interaction_type", models.CharField(default="ask", max_length=16)),
                ("inference_ms", models.FloatField(blank=True, null=True)),
                ("timestamp", models.DateTimeField(db_index=True, default=django.utils.timezone.now)),
                (
                    "session",
                    models.ForeignKey(
                        blank=True,
                        null=True,
                        on_delete=django.db.models.deletion.CASCADE,
                        related_name="messages",
                        to="api.usersession",
                    ),
                ),
            ],
            options={
                "ordering": ["-timestamp"],
            },
        ),
        migrations.AddIndex(
            model_name="message",
            index=models.Index(fields=["firebase_uid", "-timestamp"], name="api_message_firebas_idx"),
        ),
        migrations.AddIndex(
            model_name="message",
            index=models.Index(fields=["session", "-timestamp"], name="api_message_session_idx"),
        ),
    ]
