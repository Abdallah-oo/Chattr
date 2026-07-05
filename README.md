<div align="center">

<br/>

```
  ██████╗██╗  ██╗ █████╗ ████████╗████████╗██████╗
 ██╔════╝██║  ██║██╔══██╗╚══██╔══╝╚══██╔══╝██╔══██╗
 ██║     ███████║███████║   ██║      ██║   ██████╔╝
 ██║     ██╔══██║██╔══██║   ██║      ██║   ██╔══██╗
 ╚██████╗██║  ██║██║  ██║   ██║      ██║   ██║  ██║
  ╚═════╝╚═╝  ╚═╝╚═╝  ╚═╝   ╚═╝      ╚═╝   ╚═╝  ╚═╝
```

**A real-time chat application built with Flutter & Supabase**

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?style=flat-square&logo=flutter)](https://flutter.dev)
[![Supabase](https://img.shields.io/badge/Supabase-Backend-3ECF8E?style=flat-square&logo=supabase)](https://supabase.io)
[![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?style=flat-square&logo=dart)](https://dart.dev)
[![BLoC](https://img.shields.io/badge/State-BLoC%2FCubit-orange?style=flat-square)](https://bloclibrary.dev)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow?style=flat-square)](LICENSE)

</div>

---

## 📱 Overview

**Chattr** is a full-featured real-time messaging app built with Flutter. It supports private one-on-one conversations, group chats, voice messages, and image sharing — all backed by Supabase for real-time sync and offline-first caching powered by Hive.

---

## 📸 Screenshots

<div align="center">
<table>
  <tr>
    <td><img src="assets/screenshots/1.png" width="180"/></td>
    <td><img src="assets/screenshots/2.png" width="180"/></td>
    <td><img src="assets/screenshots/3.png" width="180"/></td>
    <td><img src="assets/screenshots/4.png" width="180"/></td>
  </tr>
  <tr>
    <td><img src="assets/screenshots/5.png" width="180"/></td>
    <td><img src="assets/screenshots/6.png" width="180"/></td>
    <td><img src="assets/screenshots/7.png" width="180"/></td>
    <td><img src="assets/screenshots/8.png" width="180"/></td>
  </tr>
  <tr>
    <td><img src="assets/screenshots/9.png" width="180"/></td>
    <td><img src="assets/screenshots/10.png" width="180"/></td>
    <td><img src="assets/screenshots/11.png" width="180"/></td>
    <td><img src="assets/screenshots/12.png" width="180"/></td>
  </tr>
  <tr>
    <td><img src="assets/screenshots/13.png" width="180"/></td>
    <td><img src="assets/screenshots/14.png" width="180"/></td>
    <td><img src="assets/screenshots/15.png" width="180"/></td>
    <td><img src="assets/screenshots/16.png" width="180"/></td>
  </tr>
  <tr>
    <td><img src="assets/screenshots/17.png" width="180"/></td>
    <td><img src="assets/screenshots/18.png" width="180"/></td>
    <td><img src="assets/screenshots/19.png" width="180"/></td>
    <td><img src="assets/screenshots/20.png" width="180"/></td>
  </tr>
  <tr>
    <td><img src="assets/screenshots/21.png" width="180"/></td>
    <td><img src="assets/screenshots/22.png" width="180"/></td>
    <td><img src="assets/screenshots/23.png" width="180"/></td>
    <td><img src="assets/screenshots/24.png" width="180"/></td>
  </tr>
  <tr>
    <td><img src="assets/screenshots/25.png" width="180"/></td>
    <td><img src="assets/screenshots/26.png" width="180"/></td>
    <td><img src="assets/screenshots/27.png" width="180"/></td>
    <td><img src="assets/screenshots/28.png" width="180"/></td>
  </tr>
  <tr>
    <td><img src="assets/screenshots/29.png" width="180"/></td>
    <td><img src="assets/screenshots/30.png" width="180"/></td>
    <td><img src="assets/screenshots/31.png" width="180"/></td>
    <td></td>
  </tr>
</table>
</div>

---

## ✨ Features

- 💬 **Private Chats** — Real-time one-on-one messaging with message status tracking (sent, delivered, read)
- 👥 **Group Chats** — Create and manage group conversations with multiple participants
- 🎙️ **Voice Messages** — Record and send audio messages with live recording duration display
- 🖼️ **Image Sharing** — Send images in chat with preview and download support
- 📲 **Contacts** — Browse and start conversations with your contacts
- ⚡ **Offline-First** — Local caching with Hive for instant load and offline access
- 🌙 **Dark Theme** — Sleek dark UI with a modern frosted-glass navigation bar
- 🔄 **Real-time Sync** — Supabase Realtime for live message updates across devices
- 🔔 **Push Notifications** — Firebase Cloud Messaging (FCM V1) delivers notifications when the app is in the background, triggered automatically via Supabase Edge Functions on every new message

---

## 🏗️ Architecture

Chattr follows a **Clean Architecture** approach with a feature-first folder structure.

```
lib/
├── core/
│   ├── cubits/          # Shared cubits (audio, image picker, download...)
│   ├── routing/         # App-wide routing (go_router)
│   ├── services/
│   │   ├── hive/        # Local persistence (Hive boxes)
│   │   ├── supabase/    # Supabase client, storage, and realtime
│   │   └── notification/ # FCM token management & notification handling
│   ├── themes/          # App colors and theme config
│   └── utils/
│       ├── di/          # Dependency injection (get_it)
│       └── cache/       # In-memory user cache (UsersCache)
│
└── features/
    ├── auth/            # Authentication (login, register)
    ├── contacts/        # Contacts list
    ├── private_chats/   # 1-on-1 chat feature
    └── group_chats/     # Group chat feature
```

Each feature follows this internal structure:

```
feature/
├── data/
│   ├── models/          # Hive-annotated data models
│   └── repos/           # Data repository implementations
├── domain/
│   └── repos/           # Abstract repository contracts
└── presentation/
    ├── cubits/          # Feature-level state management
    └── views/           # Screens and widgets
```

---

## 🛠️ Tech Stack

| Layer | Technology |
|---|---|
| UI Framework | Flutter |
| Backend & Auth | Supabase |
| Realtime | Supabase Realtime |
| File Storage | Supabase Storage |
| Local Database | Hive |
| State Management | BLoC / Cubit |
| Dependency Injection | get_it |
| Navigation | go_router |
| Push Notifications | Firebase Cloud Messaging (FCM V1) |
| Serverless Functions | Supabase Edge Functions (Deno) |
| Audio Recording | record |
| Networking | dio |
| Image Saving | gal |

---

## 📦 Key Packages

```yaml
dependencies:
  flutter_bloc: ^8.x        # State management
  supabase_flutter: ^2.x    # Backend & realtime
  hive_flutter: ^1.x        # Local caching
  get_it: ^7.x              # Dependency injection
  go_router: ^13.x          # Navigation
  record: ^5.x              # Audio recording
  dio: ^5.x                 # HTTP client
  gal: ^2.x                 # Save images to gallery
  equatable: ^2.x           # Value equality
  path_provider: ^2.x       # File system access
  firebase_core: ^3.x       # Firebase initialization
  firebase_messaging: ^15.x # Push notifications (FCM V1)
```

---


## 🔔 Push Notifications Architecture

Chattr uses **Firebase Cloud Messaging V1 API** for push notifications, with the full flow handled server-side via Supabase:

```
New message inserted in DB
        ↓
Supabase Database Webhook fires
        ↓
Supabase Edge Function (Deno)
  - Fetches sender name
  - Fetches chat members
  - Gets their FCM tokens from messenger_users table
  - Authenticates with FCM V1 via Service Account JWT
        ↓
FCM delivers notification to receiver's device
```

- FCM tokens are saved and refreshed automatically in `NotificationService`
- Edge Function uses **Service Account authentication** (not legacy server key)
- Notifications work when the app is **backgrounded or closed**

---

## 📄 License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.

---

<div align="center">
  <sub>Built with ❤️ using Flutter & Supabase</sub>
</div>
