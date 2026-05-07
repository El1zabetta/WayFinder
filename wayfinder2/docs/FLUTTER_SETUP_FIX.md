# Flutter Setup Fix

The Flutter SDK could not be located in the current environment (`flutter: command not found`).

## Steps to Fix

1. **Install Flutter SDK**:
   - Download the Flutter SDK from the [official Flutter website](https://docs.flutter.dev/get-started/install/linux).
   - Extract the archive to a desired location, e.g., `~/flutter` or `/opt/flutter`.

2. **Add Flutter to PATH**:
   Add the following line to your `~/.bashrc` or `~/.zshrc` file:
   ```bash
   export PATH="$HOME/flutter/bin:$PATH"
   ```
   Apply the changes by running:
   ```bash
   source ~/.bashrc
   ```

3. **Verify Installation**:
   Run the following commands to ensure Flutter is installed and configured correctly:
   ```bash
   flutter --version
   flutter doctor
   ```

4. **Install Project Dependencies**:
   Navigate to the `mobile` directory and run:
   ```bash
   cd mobile
   flutter pub get
   flutter analyze
   ```
