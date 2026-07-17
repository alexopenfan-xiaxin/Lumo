# Lumo design system

> Mobile-first source of truth. Page overrides live in `pages/` when needed.

## Direction

Lumo is an emotional-companion app for quiet daily use. Its signature is a soft luminous orbit: one restrained halo appears around avatars, meaningful status, and shared-element transitions. The original warm, editorial character is retained; generic AI purple, heavy glassmorphism, and decorative motion are intentionally rejected.

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
- Corners: 12 for controls, 18 for cards, 24 for hero surfaces, full circles for avatars.
- Elevation: borders first; only primary CTA, hero, and modal may cast a soft shadow.

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
