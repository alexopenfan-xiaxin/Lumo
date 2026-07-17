# Lumo project rules

## Local command restriction

Do not run `flutter` or `dart` commands on this machine. This includes `flutter pub get`, `flutter analyze`, `flutter test`, `flutter build`, `dart format`, and any wrapper or script that invokes Flutter or Dart locally.

Static file inspection and non-Flutter tooling are allowed. Flutter analysis, tests, and Android builds run only in GitHub Actions or another explicitly approved remote environment.

## Implementation principles

- Keep the four primary journeys complete: announcements, companions, discovery, and settings.
- Prefer Flutter and Material platform features before adding packages.
- Keep touch targets at least 44×44 logical pixels and add semantics to custom interactions.
- Respect `MediaQuery.disableAnimations`; motion must explain state or navigation.
- Reuse the design tokens in `lib/theme.dart`; do not scatter new brand colors through widgets.

