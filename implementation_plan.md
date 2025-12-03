# Implementation Plan - Lint Fixes & Deprecation Updates

## Goal
Systematically fix all remaining lint errors and warnings identified by `flutter analyze` across the Sanchar project, focusing on `deprecated_member_use`, `use_build_context_synchronously`, and `prefer_interpolation_to_compose_strings`.

## Changes Applied

### 1. Deprecated Member Use
- **`Color.withOpacity`**: Replaced with `Color.withValues(alpha: ...)` in:
  - `lib/screens/chats_list_screen.dart`
  - `lib/screens/login_screen.dart`
  - `lib/screens/profile_screen.dart`
  - `lib/screens/chat_screen.dart`
  - `lib/screens/home_screen.dart`
  - `lib/screens/onboarding_screen.dart`
  - `lib/screens/select_contact_screen.dart`
  - `lib/screens/splash_screen.dart`
  - `lib/screens/user_profile_screen.dart`
  - `lib/utils/ui_helpers.dart`
- **`ColorScheme.background` / `onBackground`**: Replaced with `surface` / `onSurface` in:
  - `lib/screens/login_screen.dart`
  - `lib/screens/onboarding_screen.dart`
  - `lib/main.dart` (Removed deprecated properties from `ColorScheme.fromSeed` overrides)
- **`ColorScheme.surfaceVariant`**: Replaced with `surfaceContainerHighest` (or similar) in:
  - `lib/screens/chat_screen.dart`

### 2. Use BuildContext Synchronously
- Added `if (!mounted) return;` checks before using `BuildContext` across asynchronous gaps in:
  - `lib/screens/login_screen.dart`
  - `lib/screens/settings_screen.dart` (Refactored to use `if (!mounted) return;` pattern)
  - `lib/screens/splash_screen.dart`
  - `lib/screens/chat_screen.dart`
  - `lib/screens/profile_screen.dart`
- In `settings_screen.dart`, captured `ScaffoldMessenger` and `Navigator` before async calls where appropriate to ensure safety.

### 3. String Interpolation
- Updated string concatenation to interpolation in `lib/services/database_service.dart`.

### 4. Naming Conventions
- Renamed private `_databaseService` to `databaseService` in:
  - `lib/screens/chats_list_screen.dart`
  - `lib/screens/friend_requests_screen.dart`
  - `lib/screens/blocked_users_screen.dart`
  - `lib/screens/settings_screen.dart`
  - `lib/screens/user_profile_screen.dart`

## Verification
- Ran `flutter analyze` multiple times to verify fixes.
- Final run confirmed **No issues found!**.

## Next Steps
- Proceed with feature development (Story Viewer, Video Uploads, etc.) knowing the codebase is clean.
