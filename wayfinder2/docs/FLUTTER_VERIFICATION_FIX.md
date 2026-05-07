# Flutter CLI & Backend Command Verification Fix

## Issue Description
During the Data Flow & Database Persistence verification phase, all automated terminal commands (including `flutter analyze`, `flutter test`, and `python manage.py check`) were blocked by the system executing the AI agent.

The exact error encountered on every terminal execution attempt was:
```text
Encountered error in step execution: unexpected user interaction type: not permission
```

This is typically caused by a frozen background shell job (e.g., a hanging `git remove -v` process running for over 2 hours) which locks the interaction permissions of the environment.

## Required Manual Action

Since the automated tools are blocked, the developer must manually run the following commands in an unlocked terminal to fulfill the verification requirements.

### 1. Fix PATH if Flutter is missing
If running `flutter` returns "command not found", run:
```bash
export PATH="$PATH:/opt/flutter/bin"
# OR if installed via snap:
export PATH="$PATH:/snap/bin/flutter"
```
To persist this, add the export to your `~/.bashrc` or `~/.zshrc`.

### 2. Manual Flutter Verification
Navigate to the mobile directory and run:
```bash
cd mobile
flutter pub get
flutter analyze
flutter test
```

### 3. Manual Backend Verification
Navigate to the backend directory and run:
```bash
cd backend
source venv/bin/activate
python manage.py check
python manage.py test api.tests.test_data_flow -v 2
```

Once these commands succeed without error, the Phase 8 verification is fully complete.
