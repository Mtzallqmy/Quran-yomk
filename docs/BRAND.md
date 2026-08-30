# ترتيل — Tarteel Brand & Product Identity Foundation

## Approval boundary

**APPROVED:** `ترتيل`, `Tarteel`, technical identifier `tarteel`, owner/developer `معتز العلقمي`, location `تعز، اليمن / Taiz, Yemen`.

**PROVISIONAL until owner approval:** final logo, final app icon, final brand colors, store artwork and screenshots. Nothing in this document promotes a generated placeholder to final artwork.

## Product metadata

| Field | Value |
|---|---|
| Arabic name | ترتيل |
| English name | Tarteel |
| Technical identifier | `tarteel` |
| Owner / Developer | معتز العلقمي |
| Location | تعز، اليمن / Taiz, Yemen |
| Copyright holder | معتز العلقمي |
| Privacy Policy URL | TBD / null |
| Terms URL | TBD / null |
| Support URL | TBD / null |
| Website URL | TBD / null |
| Contact email | TBD / null |

The rendered copyright year should be current/configurable. No company or legal entity is inferred.

## Visual direction

Tarteel is Arabic-first, calm, clean, modern and suitable for Quran/audio/radio without excessive ornament. Operational surfaces prioritize clarity and safety. Avoid neon/gaming aesthetics, clutter, decorative Arabic fonts for normal UI, low contrast, and generic dashboard-template styling.

## Design tokens

The conceptual token contract covers primary, secondary, accent, background, surface, text, muted text, success, warning, error, divider and player colors; spacing; radii; elevation; typography; icon sizes; layout widths; breakpoints; and motion. The current concrete color values in `apps/admin/lib/brand.ts` and `app/globals.css` are **PROVISIONAL** and replaceable.

Light and dark themes must preserve semantic token meaning rather than hard-coding component-specific colors.

## Typography

Use highly readable Arabic UI typography with compatible English fallback. General UI must not use a Mushaf/Quran display font when that harms interface readability.

Hierarchy: display → heading → title → body → caption → labels. Numeric/time and IDs should remain legible in mixed Arabic/English contexts; technical identifiers use a monospaced/ltr treatment where useful.

## RTL rules

RTL is structural, not merely `direction: rtl`:

- navigation and layout order follow Arabic reading direction;
- directional icons must mirror only when semantically directional;
- URLs, UUIDs, hashes and technical identifiers use isolated LTR rendering;
- dates/times/durations retain locale-aware formatting;
- tables use logical `text-align:start` and keep technical cells LTR;
- forms align labels and validation with the reading direction;
- mixed English names remain readable and isolated;
- back/forward semantics follow actual navigation, not a fixed glyph assumption.

## Accessibility

- sufficient text/background contrast;
- complete keyboard operation;
- visible `:focus-visible` indication;
- semantic labels and landmarks;
- accessible form errors with status/alert semantics;
- minimum practical touch targets;
- reduced-motion support;
- screen-reader-compatible controls and explicit destructive warnings.

## Logo specification

No final logo is approved. A future logo should be simple, calm, readable across Arabic/international contexts, work in light/dark modes, and be replaceable through an asset/token boundary without redesigning the app. A textual `ترتيل / Tarteel` identity is the safe current fallback.

## App icon specification

No final app icon is approved. Requirements:

- recognizable at small sizes;
- simple silhouette;
- relevant to Tarteel/Quran/audio without relying on readable text;
- Android adaptive-icon compatible;
- suitable for iOS masks and store backgrounds;
- adequate contrast in light/dark contexts;
- replaceable later without changing information architecture.

A placeholder is never a final approved icon.

## Artwork principles

Artwork must be calm and content-supportive. Do not imply rights ownership of Quran/reciter imagery or external station brands. External provider artwork must follow its actual rights/attribution metadata.

## UI principles

1. Arabic-first clarity.
2. Operational safety over decoration.
3. Obvious destructive/interruptive actions.
4. Real loading/empty/error/permission states.
5. Responsive desktop-first administration with acceptable tablet/mobile behavior.
6. Light/dark support through shared semantic tokens.
7. No secrets or privileged credentials in client code.

## About identity contract

Future About surfaces should expose: `ترتيل / Tarteel`, app version, `Developer: معتز العلقمي`, `Location: تعز، اليمن`, Privacy, Terms, Support and copyright. Unknown links remain disabled/TBD until configured.

## Future store identity

Store listings must reuse approved product metadata. Final logo, icon, screenshots and store artwork require owner approval in the future release phase.

## Legal/footer identity

Use the owner/developer name and location above. Do not fabricate a company, phone number, email, website, street address, Privacy Policy URL, Terms URL, support URL, or social account.
