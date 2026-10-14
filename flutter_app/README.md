# StoryUp Mobile — Flutter OTT MicroDrama Application

A cross-platform mobile application for **StoryUp** (MicroDrama Vertical Video OTT Platform), fully converted from native Android Jetpack Compose Kotlin into production-ready Flutter (Dart).

---

## 🎨 Visual Identity & Architecture

- **Color Palette:** Iconic Obsidian Pitch Black (`#000000`), Midnight Dark Surfaces (`#0D0D12` / `#16161D`), Hot Magenta Pink (`#E90064`), Neon Glow (`#FF5EA8`), and Gold Accents (`#FFD166`).
- **Typography:** Google Fonts **Bebas Neue** (display/posters/ranks) + **Montserrat** (body/metadata/headings).
- **Aspect Ratio:** 9:16 vertical cinema layout with swipeable episode gestures and auto-hiding overlays.
- **State Management:** Reactive `ChangeNotifier` with `Provider` (`AuthProvider` and `DramaProvider`), preserving 1:1 parity with Kotlin Compose's `DramaViewModel` and `StateFlow` streams.
- **Zero Video Proxying:** Direct CDN streaming via Flutter `video_player` from Cloudinary / S3 / HLS edge endpoints.

---

## 📱 Screen Breakdown & Feature Parity

| Feature / Screen | Kotlin (Jetpack Compose) | Flutter Equivalent | Description |
|---|---|---|---|
| **Authentication** | `AuthScreen.kt` | [`lib/screens/auth_screen.dart`](lib/screens/auth_screen.dart) | Indian 10-digit Phone OTP verification + One-tap bypass testing mode |
| **Home Screen** | `HomeScreen.kt` | [`lib/screens/home_screen.dart`](lib/screens/home_screen.dart) | Auto-scrolling Hero Carousel, "Top 10 on StoryUp" with large typography rank badges, Trending & New Releases |
| **Explore Feed** | `ExploreScreen.kt` | [`lib/screens/explore_screen.dart`](lib/screens/explore_screen.dart) | TikTok/Reels-style full-screen vertical swipe previews with instant "Watch Full Series" and floating action icons |
| **Premium VIP Pass** | `PopularScreen.kt` | [`lib/screens/popular_screen.dart`](lib/screens/popular_screen.dart) | VIP AutoPay subscription pricing, 24-Hour ₹1 Trial Pass, PhonePe UPI launcher |
| **My Library** | `LibraryScreen.kt` | [`lib/screens/library_screen.dart`](lib/screens/library_screen.dart) | Tabbed Watchlist & Watch History with watched timestamp progress bars |
| **User Profile** | `ProfileScreen.kt` | [`lib/screens/profile_screen.dart`](lib/screens/profile_screen.dart) | VIP Status, transaction history, Creator Studio access, and Admin credential portal |
| **Search Engine** | `SearchScreen.kt` | [`lib/screens/search_screen.dart`](lib/screens/search_screen.dart) | 350ms debounced backend API search, quick search tags, and responsive results grid |
| **Drama Detail** | `DramaDetailScreen.kt` | [`lib/screens/drama_detail_screen.dart`](lib/screens/drama_detail_screen.dart) | Backdrop banner, interactive episode picker (Free vs VIP lock badges), Star reviews & comments tabs |
| **Vertical Player** | `VerticalPlayerScreen.kt` | [`lib/screens/vertical_player_screen.dart`](lib/screens/vertical_player_screen.dart) | 9:16 vertical player, gesture swiping between episodes, comments drawer, speed toggle (0.75x–2.0x), screen lock, and VIP lock gate on Ep 6+ |
| **Creator Studio** | `CreatorStudioScreen.kt` | [`lib/screens/creator_studio_screen.dart`](lib/screens/creator_studio_screen.dart) | Creator analytics (Views, Followers, Watch time, Estimated revenue) & episode upload form |
| **Admin Panel** | `AdminModerationScreen.kt` | [`lib/screens/admin_moderation_screen.dart`](lib/screens/admin_moderation_screen.dart) | 4-tab admin moderation studio (Upload Video, Create Series, Manage Catalog, DMCA Reports) |

---

## 💳 PhonePe UPI AutoPay Integration

- **Trial Pass:** ₹1 setup fee for a 24-hour unlimited pass, converting to ₹599/month recurring mandate.
- **Deep Linking:** Uses `url_launcher` with `upi://pay?pa=...` target schemes for PhonePe, GPay, Paytm, and BHIM.
- **Android Manifest Queries:** Preconfigured `<queries>` in `android/app/src/main/AndroidManifest.xml` to support Android 11+ package visibility.
- **Server Verification:** 2-step verification handshake with backend `/api/subscription/verify` ensuring cryptographic confirmation before VIP perks are unlocked.

---

## 📂 Project Directory Structure

```text
flutter_app/
├── pubspec.yaml                 # Dependencies & asset configuration
├── analysis_options.yaml        # Flutter linter rules
├── android/
│   └── app/src/main/
│       └── AndroidManifest.xml  # Permissions, cleartext traffic & UPI queries
├── assets/                      # App assets & icons
└── lib/
    ├── main.dart                # MultiProvider root, PopScope back handler & dialog overlays
    ├── config/
    │   ├── api_config.dart      # Platform-aware backend URL resolver
    │   └── theme.dart           # StoryUp dark theme, Hot Pink palette & Bebas Neue typography
    ├── models/
    │   ├── content_report.dart
    │   ├── drama_review.dart
    │   ├── drama_series.dart
    │   ├── episode.dart
    │   ├── episode_comment.dart
    │   ├── payment_transaction.dart
    │   ├── user_role.dart
    │   ├── user_subscription.dart
    │   └── watch_history.dart
    ├── providers/
    │   ├── auth_provider.dart   # Phone OTP, Admin authentication & session state
    │   └── drama_provider.dart  # Central reactive controller replacing DramaViewModel.kt
    ├── services/
    │   ├── api_service.dart     # HTTP client with 100% offline fallback seed data
    │   ├── local_storage_service.dart # SharedPreferences persistence (Watchlist, History, Tokens)
    │   └── payment_service.dart # PhonePe UPI AutoPay intent launcher & S2S verifier
    ├── widgets/
    │   ├── autopay_dialog.dart  # VIP 24h trial dialog (₹1 setup, ₹599 mandate)
    │   ├── drama_card.dart      # Standard & Top 10 rank thumbnail cards
    │   ├── episodes_sheet.dart  # Slide-up episode picker
    │   ├── hero_slider.dart     # Auto-scrolling carousel banner
    │   ├── payment_verification_dialog.dart # PhonePe S2S spinner
    │   ├── policies_dialog.dart # Terms & privacy policy modal
    │   ├── section_header.dart  # Section title with "See All >"
    │   ├── story_bottom_nav.dart# 5-tab persistent bottom bar
    │   └── story_top_bar.dart   # Brand header with antenna TV logo & "Renew Plan" button
    └── screens/
        ├── admin_moderation_screen.dart
        ├── auth_screen.dart
        ├── creator_studio_screen.dart
        ├── drama_detail_screen.dart
        ├── explore_screen.dart
        ├── home_screen.dart
        ├── library_screen.dart
        ├── popular_screen.dart
        ├── profile_screen.dart
        ├── search_screen.dart
        └── vertical_player_screen.dart
```

---

## 🚀 How to Run the Flutter Application

### Prerequisites
1. Install [Flutter SDK](https://docs.flutter.dev/get-started/install) (version 3.16.0 or later).
2. Install Android Studio (with Android SDK & Emulator) or VS Code with Flutter extension.
3. Start the Node.js backend server:
   ```bash
   cd ../backend
   npm start
   # Server runs on http://localhost:5000 (accessible on Android Emulator via 10.0.2.2:5000)
   ```

### Running on Mobile / Desktop / Web
```bash
cd flutter_app

# Fetch dependencies
flutter pub get

# Run on Android Emulator or connected physical device
flutter run

# Run on Chrome for web preview
flutter run -d chrome
```

### Admin Credentials for Testing
- **Email:** `bhuyanrajendra598@gmail.com`
- **Password:** `admin123`
*(Accessible from Profile screen -> "Admin Moderation Portal")*
