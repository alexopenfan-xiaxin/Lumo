# Lumo project rules

## Local command restriction

Do not run `flutter` or `dart` commands on this machine. This includes `flutter pub get`, `flutter analyze`, `flutter test`, `flutter build`, `dart format`, and any wrapper or script that invokes Flutter or Dart locally.

Static file inspection and non-Flutter tooling are allowed. Flutter analysis, tests, and Android builds run only in GitHub Actions or another explicitly approved remote environment.

## Remote build workflows

| Workflow | Build output | Use |
| --- | --- | --- |
| `Run` | Signed release APK, Actions artifact, and GitHub Release | Distribution and public download. |
| `Debug` | Debug APK and Actions artifact | Development and device debugging. |

Never substitute one workflow for the other. Both workflows are manual GitHub Actions dispatches; do not use local Flutter or Dart builds.

### Release build and publishing

- `Run` must run `flutter pub get`, analysis, tests, release APK build, and `apksigner` verification before publishing.
- `Run` reads its Android signing key only from GitHub Actions Secrets: `LUMO_KEYSTORE_BASE64`, `LUMO_KEY_ALIAS`, `LUMO_KEY_PASSWORD`, and `LUMO_STORE_PASSWORD`.
- Never commit a keystore, `android/key.properties`, secret value, or private signing credential. Keep the generated keystore in an offline backup; replacing it prevents installed users from receiving normal app updates.
- Every successful `Run` publishes the verified APK as an Actions artifact named `lumo-release-apk` and as a public GitHub Release asset.
- Release tags use `v<pubspec semantic version>-build.<GitHub run number>` to make every package unique. Bump `pubspec.yaml` `version` for a new app version; never reuse an existing release tag for a different build.
- `Debug` remains unsigned by the release key and publishes only the `lumo-debug-apk` artifact; it must not create a GitHub Release.
- Keep repository visibility public without exposing any secret in source, logs, workflow output, issues, or releases.

## Continuous improvement

- After completing and verifying work, capture durable project-specific lessons in this file when they reduce repeated errors or manual work. Do not record secrets, one-off build IDs, temporary incidents, or private data.
- Before changing this project, read these rules and reuse established patterns, assets, dependencies, and workflows before adding new ones.
- Autonomously make small, scoped, reversible improvements that directly support the active request, then verify them at the appropriate risk level.
- Keep rules concise, actionable, and current: remove or correct a rule when it is contradicted by verified project reality.
- Do not self-authorize changes that alter product direction, public behavior, architecture, security posture, costs, external services, repository visibility, or signing ownership. Ask the user first.
- Treat failed checks and user corrections as root-cause signals: fix the shared cause, add the smallest suitable verification, and record the lesson here only when it will recur.

## Implementation principles

- Keep the four primary journeys complete: announcements, companions, discovery, and settings.
- Prefer Flutter and Material platform features before adding packages.
- Keep touch targets at least 44×44 logical pixels and add semantics to custom interactions.
- Respect `MediaQuery.disableAnimations`; motion must explain state or navigation.
- Reuse the design tokens in `lib/theme.dart`; do not scatter new brand colors through widgets.
