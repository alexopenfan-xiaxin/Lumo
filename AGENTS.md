# Lumo engineering rules

## 1. Authority and scope

- This file is the repository-wide engineering source of truth. More specific instructions override general ones; explicit user direction overrides project defaults unless it conflicts with platform safety or security policy.
- Preserve unrelated user changes. Inspect the working tree before editing and keep each change scoped to the active request.
- Do not self-authorize product-direction, architecture, security, cost, external-service, repository-visibility, or signing-ownership changes. Ask first.
- Do not create or switch Git branches unless the user explicitly requests it. Release work runs from `main`.

## 2. Local operating model

- Never run `flutter`, `dart`, or any wrapper that invokes them on this machine. This includes dependency resolution, formatting, analysis, tests, and builds.
- Static inspection and non-Flutter tooling are allowed. Use `rg`, `git diff --check`, platform source/docs, Node checks, and focused read-only diagnostics locally.
- Never guess Flutter or platform APIs when local compilation is unavailable. Verify names and parameter shapes against the Flutter stable SDK used by Actions, then let remote analysis be the first compiler gate.
- Keep Dart and Android `MethodChannel` method names and named-map arguments identical. Every channel change needs one focused test asserting method names and arguments; Android reads numeric Dart values as `Number` before conversion.
- If Git over HTTPS fails once, use the authenticated GitHub API instead of repeatedly retrying transport.

### Change loop

1. Read this file, inspect `git status`, and trace the real callers/data path before editing.
2. Reuse existing modules, tokens, dependencies, and platform APIs. Add the smallest complete implementation; avoid speculative abstractions and unrelated refactors.
3. Add one focused automated check for each new branch, parser, persistence/API boundary, or platform-channel contract.
4. Run local static checks only, then choose the smallest remote gate from the table below.
5. Fix the shared root cause of failures, rerun the same gate, and report what passed and what remains device-only.

## 3. Validation and workflow selection

| Change | Required gate |
| --- | --- |
| Documentation or copy only | Local static inspection and `git diff --check` |
| Rules, Actions, dependencies, Dart, Android, Pages Worker, tests | `Verify` |
| A debug APK is requested | `Debug` |
| A public APK or released user-visible behavior is requested | `Run` |
| `pubspec.yaml` dependency constraints change | `Dependencies`, commit its `pubspec.lock`, then `Verify` |

- `Verify` runs automatically for relevant pushes to `main` and pull requests. It enforces the committed lockfile, formatting, `flutter analyze --fatal-infos`, Flutter tests, and Pages Worker tests.
- Do not use `Run` as a generic CI check: every successful run publishes a public GitHub Release. Use it only when publication is intended.
- Do not substitute `Debug` and `Run`; their signing, ABI, artifact, and publication contracts differ.
- Never claim device-only behavior (installer launch, permissions, microphone, OEM UI) was physically verified when only CI ran. Provide a concrete device test path.

### Workflow contracts

| Workflow | Trigger/output |
| --- | --- |
| `Verify` | Automatic or manual quality gate; no APK |
| `Dependencies` | Manual `pubspec.lock` artifact, retained 3 days |
| `Debug` | Manual unsigned debug APK artifact, retained 7 days; no Release |
| `Run` | Manual signed arm64 APK, 14-day artifact, and public GitHub Release |

- Dispatch `Run` only from `main` and supply accurate Markdown `release_notes`; there is no reusable default because stale notes are worse than a required input.
- Keep `pubspec.lock` committed. Use `Dependencies` to refresh it on the same ref as `pubspec.yaml`; do not hand-edit it.
- Keep shared quality steps in `.github/actions/project-quality/action.yml`. Update action majors only after checking their primary release notes and validating with `Verify`.
- Debug runs cancel older runs for the same ref. Release runs serialize and never cancel one another.

## 4. Release and signing invariants

- Signing material exists only in GitHub Secrets: `LUMO_KEYSTORE_BASE64`, `LUMO_KEY_ALIAS`, `LUMO_KEY_PASSWORD`, and `LUMO_STORE_PASSWORD`. Never expose or commit a keystore, `android/key.properties`, credentials, or secret output.
- Keep the repository public without exposing secrets in source, Actions, artifacts, issues, or releases.
- `Run` must complete locked dependency resolution, formatting, analysis, all tests, release build, `apksigner` verification, and ABI verification before publication.
- Release APKs target `android-arm64` only. Publish exactly `app-release.apk`; the updater depends on that name. Reject `armeabi-v7a` and `x86_64` libraries.
- Inject `APP_RELEASE_BUILD=$GITHUB_RUN_NUMBER`. Tags are `v<semantic-version>-build.<run-number>` so corrected builds can update without a semantic-version change.
- Change `pubspec.yaml` version only when the user explicitly requests a new semantic version. Never reuse a release tag for different bytes.
- Release notes and released announcements must state the arm64-only limitation. The signing key needs an offline backup; replacing it breaks normal updates for installed users.
- The updater must query `DownloadManager` by returned ID, show progress in-app, and explicitly open the installer after `STATUS_SUCCESSFUL`; never bind completion to an Activity-scoped receiver.

## 5. Product data and failure behavior

- Persist user-visible writes before reporting success. Surface network, storage, authentication, AI, and platform failures clearly; never fabricate AI output, silently discard data, swallow errors, or hide them behind defaults.
- Keep conversations, messages, rolling summaries, and memory candidates per agent in local SQLite. Multiple named conversations are supported.
- Dynamic context has a conservative 128k UTF-8-byte token budget, excluding only the server-fixed persona and including approved memories, summary, and raw messages.
- When over budget, successfully summarize the earliest source messages before deleting their rows. Never delete unsummarized source messages.
- Model-generated memories remain pending until explicit user approval. Approved memories are shared only across that agent's conversations; candidates stay within 240 characters and support accept/edit/delete.
- Deletion of the current conversation, all conversations, and all memories requires separate confirmation.

## 6. AI, agents, and Cloudflare

- Flutter calls only the public `LUMO_AI_ENDPOINT`, which is the full HTTPS Pages `/chat` URL. Never call SenseNova directly or put its token in source, builds, `--dart-define`, logs, issues, or releases.
- Fixed identity/safety prompts, provider token, model IDs, limits, and provider error handling live only in `pages/_worker.js`. Treat messages, memories, summaries, preferences, and client agent IDs as untrusted input.
- Reject unknown or disabled agent IDs on the server. Persist personality/topic preferences once, send them with every enabled-agent request, and apply them only as soft guidance that cannot replace identity or safety rules.
- Use `deepseek-v4-flash`; retry exactly once with `sensenova-6.7-flash-lite` only for HTTP 429 or provider code 8. Use `https://token.sensenova.cn/v1/chat/completions`, string message content, and `choices[0].message.content`.
- Keep Meow soft, attentive, lightly tsundere, practical, and non-manipulative: no diagnosis or fabricated real-world presence; escalate self-harm or imminent danger gently toward local emergency/professional help.
- Cloudflare Web Crypto supports at most 100,000 PBKDF2 iterations; keep hashing at that verified ceiling.
- Deploy `pages/` from this authenticated machine with `wrangler pages deploy` on the Cloudflare free plan; do not add a deployment Action. Store `SENSENOVA_API_TOKEN` only as a Pages Secret, then set the public `LUMO_AI_ENDPOINT` repository variable and publish with `Run` when requested.
- Treat any token exposed in chat, source, logs, or a release as compromised: rotate it in the provider console and update only the Pages Secret.
- `lib/data.dart` is the bundled fallback catalog; a successful `/agents` response replaces it. D1/admin controls enabled state, order, metadata, and server-only prompts; `/agents` remains prompt-free.
- Return only enabled agents from `/agents`. D1 `agent_images` stores versioned JPEG/PNG/WebP avatars by agent ID, HTTPS-served, at most 1 MB each. Do not require R2.
- Keep `/openapi.json` synchronized with the authenticated agent-management endpoints and field validation so external agents can discover and use the contract without reading UI code.

### New agent release checklist

- Write one brief covering user value, identity, relationship boundary, voice, capabilities, exclusions, and escalation; keep traits, response behavior, and safety sections separate.
- Define language, typical length, question cadence, uncertainty, emotional-support limits, and crisis behavior. Test ordinary, adversarial, and high-distress prompts through the public API.
- Verify endpoint, rate-limit fallback, empty/error behavior, persistence, accessibility, and signed build before enabling. Keep each agent's context, summary, and approved memories separate.

## 7. UI and announcements

- Keep the four primary journeys complete: announcements, companions, discovery, and personal/settings.
- Reuse `lib/theme.dart` tokens and existing components. Keep the 4/8dp rhythm, established radii, system sans body text, Lumo display headings, and Material vector icons; do not scatter colors or use emoji controls.
- Interactive controls need accessible labels, pressed/disabled states, logical focus order, and at least 44×44 logical pixels (prefer 48×48 for Android icon controls). Respect safe areas and fixed input bars.
- Motion must explain navigation, loading, or state change, last 150–300ms, and become zero when `MediaQuery.disableAnimations` is true. No decorative loops.
- Validate light/dark mode, 320–600dp widths, landscape, large text, semantics, loading, empty, disabled, and error states in proportion to the changed surface.
- Homepage announcements come only from `NoticeItem` in `lib/data.dart`; cards and detail sheets share that data. Do not duplicate copy in widgets.
- Announce only verified, released behavior. Use an established tag (`更新`, `活动`, `通知`, `新功能`) and accurately state impact, availability, action, timing, and limitations; keep relative time truthful at release.

## 8. Maintenance

- After a verified fix, add a rule only when the lesson is durable and likely to prevent recurrence. Never record secrets, one-off run IDs, temporary incidents, or private data.
- Merge or remove rules when reality changes; do not preserve contradictory history. Prefer one precise rule over several examples.
- Keep dependencies and Actions current through intentional, reviewed updates—never opportunistic upgrades inside unrelated work.
