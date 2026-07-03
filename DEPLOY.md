# WaziBot Mobile — Build & Deploy Guide

## Step 1 — Open PowerShell as Administrator

Search "PowerShell" in Start menu → Right-click → "Run as administrator"

---

## Step 2 — Set ANDROID_HOME permanently

Copy and run this entire block (one paste):

```powershell
[System.Environment]::SetEnvironmentVariable(
  "ANDROID_HOME",
  "C:\Users\manix\AppData\Local\Android\Sdk",
  [System.EnvironmentVariableTarget]::User
)
[System.Environment]::SetEnvironmentVariable(
  "Path",
  [System.Environment]::GetEnvironmentVariable("Path","User") + 
  ";C:\Users\manix\AppData\Local\Android\Sdk\platform-tools" +
  ";C:\Users\manix\AppData\Local\Android\Sdk\tools",
  [System.EnvironmentVariableTarget]::User
)
Write-Host "Done. Close and reopen PowerShell now."
```

Close PowerShell and open a fresh one.

---

## Step 3 — Accept SDK licenses

```powershell
cd C:\Users\manix\wazibot_mobile_phase1\wazibot_mobile
flutter doctor --android-licenses
```

Press `y` and Enter for every prompt until it says "All SDK package licenses accepted."

---

## Step 4 — Run flutter doctor

```powershell
flutter doctor
```

You should see green checkmarks for Flutter and Android toolchain.
Chrome and VS Code warnings are fine to ignore.

---

## Step 5 — Get dependencies

```powershell
flutter pub get
```

---

## Step 6 — Build the APK

```powershell
flutter build apk --release
```

This takes 2-5 minutes the first time.

The APK will be at:
```
build\app\outputs\flutter-apk\app-release.apk
```

---

## Step 7 — Install on your Android phone

Connect your phone via USB, enable USB Debugging (Settings → Developer Options → USB Debugging), then:

```powershell
flutter install
```

Or copy `app-release.apk` to your phone and open it.
(First time: Settings → Security → Allow install from unknown sources)

---

## For Play Store (when ready)

### Create a signing key (run once, keep the file safe forever):
```powershell
keytool -genkey -v -keystore C:\Users\manix\wazibot-release.jks `
  -keyalg RSA -keysize 2048 -validity 10000 -alias wazibot
```

### Create android\key.properties:
```
storePassword=YOUR_PASSWORD
keyPassword=YOUR_PASSWORD
keyAlias=wazibot
storeFile=C:\\Users\\manix\\wazibot-release.jks
```

### Build App Bundle for Play Store:
```powershell
flutter build appbundle --release
```

Upload `build\app\outputs\bundle\release\app-release.aab` to Google Play Console.
