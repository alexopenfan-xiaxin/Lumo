# Lumo design system

> Mobile-first source of truth. Page overrides live in `pages/` when needed.

## Direction

Lumo is an emotional-companion app for quiet daily use. Its signature is a soft luminous orbit around people and meaningful status. The interface follows the spacious, content-first structure common in Chinese community apps: warm paper backgrounds, white grouped surfaces, weak dividers, black line icons, and clear Chinese hierarchy. Generic AI purple, visible Material 3 styling, heavy glassmorphism, and decorative motion are intentionally rejected.

Visual references are stored in `references/domestic-profile-reference.jpg` and `references/domestic-settings-reference.jpg`. Reuse their information hierarchy and grouping, never their unrelated social, wallet, creator, or regulatory content.

## Tokens

| Role | Light | Dark |
|---|---|---|
| Primary / apricot clay | `#C47F5B` | `#E0A17D` |
| Action / accessible clay | `#A45F41` | `#E0A17D` |
| Secondary / eucalyptus | `#6F8F86` | `#8DB0A6` |
| Tertiary / fog blue | `#7893A5` | `#9AB6C7` |
| Background | `#F8F5F0` | `#171513` |
| Surface | `#FFFCF8` | `#211E1B` |
| Foreground | `#2B2622` | `#F4ECE4` |
| Muted text | `#756E68` | `#BDB3AA` |
| Border | `#E8E0D8` | `#39332E` |
| Positive | `#4F9177` | `#79B69D` |
| Error | `#BB6258` | `#E68A80` |

- Display: ZCOOL XiaoWei, 24–32sp, short Chinese headings only.
- Body: Android system sans, 14–16sp, line height 1.45–1.65.
- Spacing: 4 / 8 / 12 / 16 / 20 / 24 / 32.
- Corners: 16 for controls and cover art, 24 for grouped surfaces and hero areas, full circles for avatars.
- Elevation: grouped surfaces stay flat; only the floating dock and modal may cast a soft shadow.

## Components

- Primary pages use 16–20dp horizontal gutters and generous top whitespace. Display type is reserved for brands, page titles, and companion names.
- Functional lists sit inside one white 24dp group with 64dp rows and 1px inset dividers. Ordinary controls do not use colored square icon tiles.
- The fourth primary destination is `个人`; its settings button opens a secondary centered-title settings page.
- The floating four-item dock remains, but selected state uses filled icon, brand-colored label, and weight only—never a sliding tonal pill.
- Discovery uses two-column 3:4 companion covers with text directly below the image and no outer card.

## Motion

- Page/list entry: 220–320ms ease-out, 12px maximum translation.
- Press: native ripple; haptic only for send, save, and important toggles.
- Shared companion avatar: Flutter `Hero`.
- One orchestrated motion per screen; no looping decorative animation.
- When `MediaQuery.disableAnimations` is true, durations become zero.

## Interaction and accessibility

- Minimum target 44×44dp; bottom navigation has four destinations.
- Custom cards and artwork require `Semantics` labels.
- Text contrast targets WCAG AA; never communicate state by color alone.
- Bottom sheets and dialogs use explicit action labels and predictable back dismissal.
- Content must clear status/navigation safe areas and support 320–600dp widths.
