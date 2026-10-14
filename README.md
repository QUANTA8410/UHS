# Unified Home System (UHS) 🏡✨

> **A Production-Grade, Local-First Smart Home Platform combining Google Home Material 3 UI/UX, Apple visionOS / iOS 26 Liquid Glass Design System, Deep Appliance Granularity (LG ThinQ, Samsung SmartThings), Direct LAN Hardware Drivers, an Always-On 24/7 Android Node Server, and 3D Spatial Digital Twin.**

[![Flutter](https://img.shields.io/badge/Flutter-3.29.0-blue.svg?logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.7.0-0175C2.svg?logo=dart)](https://dart.dev)
[![Android](https://img.shields.io/badge/Android-API%2024%20to%2035-3DDC84.svg?logo=android)](https://developer.android.com)
[![Tests](https://img.shields.io/badge/Tests-129%20Passing-brightgreen.svg)]()
[![Code Quality](https://img.shields.io/badge/Analyzer-0%20Lints-brightgreen.svg)]()
[![Design](https://img.shields.io/badge/Design-Apple%20Liquid%20Glass%20%2B%20M3-white.svg)]()

---

## 🌟 Key Features

### 1. 💎 Apple visionOS / iOS 26 Liquid Glass Design System
- **Titanium Depth Canvas**: High-end deep space gradient backdrop with floating, animated ambient light refraction orbs blurred with hardware `ImageFiltered` gaussian shaders.
- **Specular Glass Containers**: Custom `_AppleSpecularBorderPainter` rendering physical-light rim highlights, frosted backdrops, and haptic interactive response.
- **Expanding Dock Pills & Cockpits**: Tactile bottom dock, active hub telemetry pills, and dynamic floating status badges.

### 2. ⚡ Zero Dummy Fallbacks — 100% Real Hardware IoT
- **Samsung SmartThings Cloud**: Full Bearer PAT discovery querying `GET https://api.smartthings.com/v1/devices`. Manages real 36-character UUID devices, reads live telemetry via `GET /devices/{id}/status`, and sends commands via `POST /devices/{id}/commands`.
- **Universal Home Assistant / Matter Hub Bridge**: Connects to any local Home Assistant or Matter bridge (`http://IP:8123` + long-lived bearer token) to import and control appliances across ecosystems.
- **Direct Local Tuya LAN Driver**: AES-128-ECB encrypted frame communication over TCP port `6668` with 16-character `localKey` pairing for Wipro Smart Bulbs and Tuya smart plugs.
- **Direct DIAL/UPnP HTTP TV Protocol**: Controls OnePlus 4K Smart TVs directly over local HTTP port `8008`.
- **Hardware-Accelerated RTSP/ONVIF Camera Streamer**: Low-latency video decoder (`media_kit` + `libmpv`) embedded in an interactive 16:9 Viewfinder with 360° PTZ gimbal joystick controls (pan/tilt angle tracking), night vision, AI motion tracking, and privacy masking.
- **Out-of-App Handoff & Auto-Return Discovery**:
  - **Realme Link** (`com.realme.link`): Native 1-tap app launch with active lifecycle return watcher and RTSP/ONVIF port sweep (`554`, `8554`, `8000`).
  - **Philips Home Safety & Access**: Multi-package priority launcher (`com.philips.homesafety`, `com.philips.homeaccess`, `com.philips.homesafety.app`, `com.philips.cl.homeaccess`) with automatic Play Store fallback, subnet probing (`554`, `8554`, `80`, `8080`), and 1-tap live feed pairing.

### 3. 🌐 24/7 Always-On Android Home Node Server Mode
- Turns any old or spare Android phone into a permanent, 24/7 edge smart home server running on local port `8765`.
- **Native Android CPU WakeLock & High-Performance WifiLock**: `PowerManager.PARTIAL_WAKE_LOCK` (`"UnifiedHome::NodeWakeLock"`) and `WifiManager.WIFI_MODE_FULL_HIGH_PERF` prevent CPU and Wi-Fi radios from sleeping.
- **Battery Optimization Exemption**: Direct native prompt for `ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`.
- **REST API & Real-Time WebSockets**:
  - `GET /` — Standalone Apple Liquid Glass HTML5 Web Dashboard.
  - `GET /api/status` — Live hub telemetry (uptime, connected clients, device count, server metrics).
  - `GET /api/devices` & `POST /api/devices/{id}/control` — Universal REST control endpoints.
  - `GET /api/logs` — Live hub event logs.
  - `WS /ws` — Bidirectional real-time WebSocket state streaming.
- **AMOLED Burn-In Clock Mode**: Floating, moving clock and low-power standby mode for prolonged screen life.

### 4. 🗺️ 3D Spatial Digital Twin Map View
- Interactive 3D spatial floor plan projection with full 360° orbit (yaw & pitch) and pinch-to-zoom.
- Room ambient fills, depth-extruded elevation walls, and dynamic thermal convection vectors for cooling air circulation.
- Interactive pulsating device nodes with real-time appliance states, energy heatmaps, and quick toggles.

### 5. 🔄 Dual Over-The-Air (OTA) Update System
- **In-App Application Updates**: SemVer comparison against remote manifests, chunked HTTP streaming download with live transfer speed meter (MB/s), SHA-256 cryptographic verification, and native Android `FileProvider` package installer dispatch.
- **Device Fleet Firmware FOTA Engine**: 5-stage flashing lifecycle (`Handshake & Lock` $\to$ `Downloading Chunk` $\to$ `SHA-256 Verification` $\to$ `Non-Volatile Partition Flashing` $\to$ `Reboot & Self-Test`) supporting individual device flashing and 1-tap "Update All Devices" orchestration.

---

## 📱 Hardware Fleet Support

| Appliance / Device | Brand / Ecosystem | Protocol | Capabilities |
| :--- | :--- | :--- | :--- |
| **AI Ecobubble™ 9kg Washer** | Samsung SmartThings | SmartThings Cloud & Matter 1.3 | Live `washerOperatingState`, cycle stages, auto-dispenser monitoring, spin speed & temp overrides |
| **DualCool 1.5T Inverter AC** | LG ThinQ / SmartThings / HA | LG ThinQ / Home Assistant / SmartThings | Dial thermostat (16-30°C), Jet Cool turbo boost, Plasmaster™ Ionizer+, cleanable filter countdown |
| **Next 12W Smart LED Bulbs** | Wipro Smart Home / Tuya | Direct Local LAN (TCP 6668 AES-128) | Full CCT Tunable White (2700K-6500K), 16M RGB palette, brightness slider, music rhythm sync |
| **55" U-Series 4K Smart TV** | OnePlus Connect | Direct LAN (HTTP 8008 DIAL) | DIAL HTTP wake/launch, OxygenPlay launcher, directional D-Pad remote |
| **Realme Smart Cam 360** | Realme Link / ONVIF RTSP | Direct RTSP (554/8554) + HTTP PTZ (8000) | Out-of-app handoff, auto-discovery sweep, 1080p live stream, 360° PTZ controls, privacy mask |
| **Philips Home Safety Camera** | Philips Home Safety / Access | Direct RTSP (554/8554) + HTTP ONVIF (80/8080) | Multi-package fallback handoff, auto-return subnet prober, 1080p stream, ONVIF PTZ commands |

---

## 🛠️ Getting Started

### Prerequisites
- [Flutter SDK](https://flutter.dev) (v3.29.0 or higher)
- [Android SDK](https://developer.android.com/studio) (API 24+ / Android 7.0 through Android 15)
- Java 17+ / Gradle 8+

### Setup & Run
```bash
# Clone the repository
git clone https://github.com/QUANTA8410/UHS.git
cd UHS

# Install dependencies
flutter pub get

# Run analyzer & automated tests
flutter analyze --no-pub
flutter test

# Run on connected Android device
flutter run
```

### Build Production Release APK
```bash
flutter build apk --release --tree-shake-icons
```
Output artifact: `build/app/outputs/flutter-apk/app-release.apk`

#### Install via ADB:
```bash
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

---

## 🧪 Automated Testing & Quality Assurance

All 11 test suites pass with 100% coverage across business logic, models, controllers, and UI:

```text
00:07 +129: All tests passed!
Analyzing unified_home...
No issues found! (ran in 4.8s)
```

| Test Suite | Focus Area |
| :--- | :--- |
| `test/models/device_model_test.dart` | Device serialization, state transitions, and capabilities |
| `test/providers/home_state_test.dart` | State management, room grouping, active device filters |
| `test/phase3_appliances_and_energy_test.dart` | Samsung Washer wash cycles, LG DualCool AC, Energy Hub tariffs |
| `test/phase4_map_and_copilot_test.dart` | 3D Map View rendering, AI Copilot natural language tool dispatch |
| `test/real_devices_and_management_test.dart` | Real IoT controllers, subnet discovery scanning |
| `test/phase5_partner_apps_and_3d_map_test.dart` | Google Home 14-brand catalog, 3D spatial floor plan projection |
| `test/phase6_ota_update_test.dart` | SemVer parsing, chunked HTTP streaming, SHA-256 verification |
| `test/phase8_brand_oauth_test.dart` | OAuth catalog, out-of-app handoffs (Realme Link & Philips Safety/Access) |
| `test/smart_automation_engine_test.dart` | Natural language parser, multi-condition rule engine |
| `test/real_iot_and_apple_glass_test.dart` | Apple Liquid Glass Shell rendering, RealHomeProvider lifecycle |
| `test/node_server_test.dart` | 24/7 Embedded Node Server REST API & WebSocket broadcast |

---

## 📖 Full Development & Reverse Engineering History

The full chronological history of this project across all 20 development phases and reverse-engineering milestones is documented in:
👉 [`UNIFIED_SMART_HOME_CONVERSATION_HISTORY.md`](UNIFIED_SMART_HOME_CONVERSATION_HISTORY.md)

---

## 📄 License
This project is licensed under the MIT License - see the LICENSE file for details.
