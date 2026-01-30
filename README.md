📱 Pocket Butler – Anti-Theft Security App

Pocket Butler is an Android anti-theft security app built with Flutter and native Android (Kotlin).
It protects your phone by triggering loud alarms and vibration, locking volume at maximum, and actively preventing shutdown attempts even if a thief tries to power off the device.

🚨 Key Features

🔊 Loud Theft Alarm  
Plays a continuous voice alarm when unauthorized activity is detected.

📳 Synchronized Vibration  
Native vibration triggers alongside the real alarm audio.

🔒 Volume Lock at Maximum  
Prevents thieves from lowering or muting alarm volume.

🚫 Shutdown Prevention (Accessibility-Based)  
Uses an Accessibility Service to instantly dismiss the power menu, making shutdown impossible while armed.

🔑 PIN-Protected Disarm  
Only the correct PIN can stop the alarm and restore control.

⚙️ Flutter + Native Integration  
Uses MethodChannels to safely access system-level Android features.

🛡️ How Shutdown Protection Works

Pocket Butler registers a dedicated Accessibility Service that:
- Detects the Android power menu (Global Actions)
- Instantly triggers a BACK action
- Repeatedly closes the shutdown UI before it can be tapped

This approach works even on modern Android versions (Android 12+ / 13+) where traditional shutdown interception is blocked.

🧩 Tech Stack

- Flutter (Dart) – UI & core logic
- Kotlin (Android) – Accessibility Service, vibration, volume control
- MethodChannel – Flutter ↔ Native communication
- Android Accessibility API – Shutdown prevention
- Android Services & Receivers – System-level monitoring

⚙️ Setup & Installation

1️⃣ Build the APK
```bash
flutter clean
flutter pub get
flutter build apk --debug
```

2️⃣ Install on Device
```bash
adb install -r build/app/outputs/flutter-apk/app-debug.apk
```

♿ Enable Accessibility Protection (Required)
1. Open Pocket Butler
2. Tap “Grant Accessibility Permission”
3. Go to Settings → Accessibility → Installed Services
4. Enable “Butler Shutdown Protection”

⚠️ Android 13+:  
If the toggle is disabled, go to App Info → 3 dots → Allow Restricted Settings

▶️ How to Use
1. Open the app
2. ARM the protection
3. Simulate theft (disconnect trusted device / trigger condition)
4. Alarm + vibration start immediately
5. Power menu attempts are blocked
6. Enter PIN to disarm

🏆 Accomplishments
- Implemented shutdown prevention on modern Android
- Solved OEM-specific system limitations
- Built a single-source-of-truth architecture for alerts
- Achieved stable Flutter ↔ Native coordination

🔮 What’s Next
- Remote alarm & control
- Cloud alerts & device tracking
- Motion & geofence triggers
- Play Store–ready production build

📂 Repository

GitHub:  
👉 https://github.com/Ashil2005/Pocket-butler

👤 Author

Ashil  
Android • Flutter • Security Systems
