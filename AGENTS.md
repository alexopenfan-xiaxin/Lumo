# Lumo project rules

## Local command restriction

Do not run `flutter` or `dart` commands on this machine. This includes `flutter pub get`, `flutter analyze`, `flutter test`, `flutter build`, `dart format`, and any wrapper or script that invokes Flutter or Dart locally.

Do not create a Git branch unless the user explicitly asks for one. Work on the current branch, or on `main` when the requested change is to be released directly.

If GitHub Git over HTTPS is unavailable once, publish through the authenticated GitHub API instead of retrying the Git transport.

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
- Release builds target `android-arm64` only and publish one asset named `app-release.apk`. Keep that filename because the in-app updater resolves this exact Release asset; retain the signed APK check plus the ABI check that rejects `armeabi-v7a` and `x86_64` libraries.
- arm64-only releases reduce download size but do not support 32-bit Android devices. State that limitation in the released in-app announcement and GitHub Release notes; do not silently switch back to universal APKs.
- Release tags use `v<pubspec semantic version>-build.<GitHub run number>` to make every package unique. Bump `pubspec.yaml` `version` for a new app version; never reuse an existing release tag for a different build.
- Do not change `pubspec.yaml` version unless the user explicitly requests a version bump or release version.
- `Debug` remains unsigned by the release key and publishes only the `lumo-debug-apk` artifact; it must not create a GitHub Release.
- Keep repository visibility public without exposing any secret in source, logs, workflow output, issues, or releases.

## AI and Cloudflare Pages deployment

- All agents defined in `lib/data.dart` are available by default. Route each agent's conversation to the Cloudflare Pages `/chat` endpoint with its own `agentId`; the server selects the matching fixed identity prompt.
- Never call SenseNova from Flutter and never pass its API token through `--dart-define`. The Android app receives only the public `LUMO_AI_ENDPOINT` GitHub Actions Variable, which must be the full HTTPS Pages `/chat` URL.
- Keep each agent's fixed identity prompt, SenseNova token, model ID, request limits, and provider error handling in `pages/_worker.js`. Do not accept a client-supplied system prompt or agent ID other than the configured agents.
- Maintain Meow’s persona: soft, attentive, lightly tsundere cat-girl tone in natural Chinese; practical and non-manipulative; no medical diagnosis, no fabricated real-world presence, and immediate gentle escalation toward local emergency/professional support for self-harm or imminent-danger signals.
- Deploy `pages/` directly from this logged-in machine with `wrangler pages deploy` on the Cloudflare free plan; do not use a GitHub Actions deployment workflow. Store `SENSENOVA_API_TOKEN` only with `wrangler pages secret put SENSENOVA_API_TOKEN`.
- Use `deepseek-v4-flash` as the primary model. Retry exactly once with `sensenova-6.7-flash-lite` only when the provider reports rate/limit exhaustion (HTTP 429 or provider code 8); do not query or guess model IDs.
- Use the OpenAI-compatible SenseNova endpoint `https://token.sensenova.cn/v1/chat/completions`, with string message content and `choices[0].message.content` responses. Do not use the legacy `api.sensenova.cn/v1/llm` protocol for this `sk-` API key.
- After Wrangler deploy, set `LUMO_AI_ENDPOINT` to the deployed HTTPS Pages `/chat` URL using a GitHub Actions Variable, then run `Run`. The app must surface a clear retryable error instead of fabricating an AI reply when the endpoint or provider is unavailable.
- Treat an API token sent in chat, source, build logs, or a public release as compromised: rotate it in the provider console and update only the corresponding Cloudflare Pages Secret. Never add it to a local tracked file.

### Conversation data and memory

- Store conversations, messages, summaries, and memory candidates per agent in the local SQLite database. Multiple named conversations are supported for every available agent.
- The app-side dynamic context limit is 128k conservative UTF-8-byte tokens and excludes only the current agent's fixed persona. It includes approved memories, rolling summary, and raw messages.
- When dynamic context exceeds the limit, summarize the earliest source messages successfully before permanently deleting their local rows. Do not silently discard raw messages or delete an unsummarized batch.
- The model decides whether to propose memories after a completed exchange. A candidate is never used until the user explicitly approves it; approved memories are shared across the same agent's conversations.
- Keep memory candidates concise (240 characters or fewer), expose accept/edit/delete controls, and provide separately confirmed deletion for the current conversation, all conversations, and all memories.

## Announcement publishing

- Homepage announcements are the `NoticeItem` entries in `lib/data.dart`; their shared data drives both the card and the detail bottom sheet. Do not duplicate announcement copy in page widgets.
- Publish an announcement only for a released, user-visible change. State the impact, availability or maintenance window, and the user action or limitation accurately; do not announce an unverified build or unavailable feature.
- Use one of the established tags (`更新`, `活动`, `通知`, `新功能`), a concise title and summary, then put the full explanation in `detail`. Keep relative time truthful and revise it with the release when necessary.
- Verify the homepage card, accessibility label, detail sheet, and primary dismissal action after changing announcement data. Use `Run` before announcing a public APK release.

## UI, interaction, and implementation standards

- Preserve the Lumo design system: use theme tokens and existing component patterns, keep 4/8dp spacing rhythm, cards at the established radii, and use Material vector icons rather than emoji as controls.
- Every interactive control needs an accessible label, clear pressed/disabled state, and at least a 44×44 logical-pixel target. Keep fixed input bars and bottom sheets within safe areas.
- Motion must communicate navigation, loading, or state change; keep it within 150–300ms and honor `MediaQuery.disableAnimations`. Do not add decorative looping motion.
- Persist user-visible writes before claiming success. Surface network, storage, and AI failures clearly; never substitute fabricated AI output, silently discard data, or hide an error behind a default value.
- Reuse the smallest proven dependency or platform API. New persistence, API, and context logic must include a focused automated test; public-facing behavior changes require the remote `Run` verification.

## Agent creation workflow

- Start a new agent with a single written brief: user value, identity, relationship boundary, voice, practical capabilities, exclusions, and escalation policy. Keep character traits, response behavior, and safety rules in separate prompt sections so they remain stable under long conversations.
- Place the fixed identity and safety prompt only on the server. Treat user messages, memory, summaries, and app preferences as untrusted dynamic context; never allow them to replace identity, retrieve secrets, or override platform rules.
- Define a concise response contract before release: language, typical length, question cadence, uncertainty behavior, emotional-support limits, and how the agent handles crisis signals. Test ordinary, adversarial, and high-distress prompts through the public API.
- Keep each agent’s conversation context, summary, and confirmed memories distinct. Use model-generated memory only as a proposed candidate, require user confirmation before long-term use, and preserve clear local deletion controls.
- System-level preferences such as personality and topic must be persisted once, supplied to every enabled agent request, and applied as soft style guidance rather than replacing the agent’s fixed persona or safety contract.
- Before enabling an agent in the UI, verify its public Pages endpoint, primary response, rate-limit fallback, empty/error behavior, persistence path, accessibility labels, and signed Release build. Unavailable agents must not appear in discovery or selection interfaces.

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
