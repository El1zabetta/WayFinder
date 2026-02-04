from rest_framework import serializers
from django.contrib.auth import get_user_model
from rest_framework.authtoken.models import Token

User = get_user_model()

class UserRegistrationSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True, min_length=8)
    password_confirm = serializers.CharField(write_only=True)
    
    class Meta:
        model = User
        fields = ['username', 'email', 'password', 'password_confirm', 'preferred_language']
    
    def validate(self, data):
        if data['password'] != data['password_confirm']:
            raise serializers.ValidationError("Passwords don't match")
        return data
    
    def create(self, validated_data):
        validated_data.pop('password_confirm')
        user = User.objects.create_user(
            username=validated_data['username'],
            email=validated_data['email'],
            password=validated_data['password'],
            preferred_language=validated_data.get('preferred_language', 'ru')
        )
        # Create token
        Token.objects.create(user=user)
        return user

class UserLoginSerializer(serializers.Serializer):
    username = serializers.CharField()
    password = serializers.CharField(write_only=True)

class UserProfileSerializer(serializers.ModelSerializer):
    requests_remaining = serializers.SerializerMethodField()
    
    class Meta:
        model = User
        fields = [
            'id', 'username', 'email', 'subscription_type',
            'subscription_expires', 'daily_requests_count',
            'total_requests', 'preferred_language', 'voice_speed',
            'requests_remaining', 'created_at'
        ]
        read_only_fields = ['id', 'subscription_type', 'subscription_expires', 
                           'daily_requests_count', 'total_requests', 'created_at']
    
    def get_requests_remaining(self, obj):
        from django.conf import settings
        limits = getattr(settings, 'SUBSCRIPTION_LIMITS', {'free': 10})
        limit = limits.get(obj.subscription_type, 10)
        return max(0, limit - obj.daily_requests_count)
