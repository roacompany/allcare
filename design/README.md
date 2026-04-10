# BabyCare Design System

## Color Tokens

All colors defined in `tokens/babycare-tokens.json`.

Source of truth: `BabyCare/Assets.xcassets/Colors/` (18 dynamic color sets, light + dark variants)

Swift reference: `BabyCare/Utils/Constants.swift` — `AppColors` enum

### Token categories

| Category | Description |
|----------|-------------|
| `brand`    | Primary brand color (pastel pink #FF9FB5) |
| `activity` | Per-activity colors: feeding, sleep, diaper, solid, bath, temperature, medication |
| `semantic` | background, cardBackground, success, health, coral, indigo, sage, warmOrange, skyBlue, softPurple |
| `pastel`   | Pastel palette: pink, blue, mint, yellow, purple, orange |
| `typography` | SF Pro system font sizes (largeTitle → caption2) |
| `spacing`  | 4 / 8 / 12 / 16 / 20 / 24 / 32 / 40 pt scale |
| `radius`   | Corner radii: 8 / 12 / 16 / 20 / pill |

## Design Files

`.pen` files in `screens/` — create with Pencil MCP (`open_document`).

## Screenshot Pipeline

```bash
xcodebuild test \
  -project BabyCare.xcodeproj \
  -scheme BabyCare \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:BabyCareUITests/ScreenshotTests
```

Output: `/tmp/babycare_screenshots/`

## ROA Design System

Token validation:

```bash
roa verify    # validate tokens vs source
roa report    # coverage report
```

Config: `.roa-design.json` (project root)

## Notes

- All colors support dark mode via Asset Catalog dynamic colors
- Pastel colors in `Constants.swift` use hardcoded hex (no dark variant — use with `.opacity()` for dark mode)
- Typography uses iOS system font only (no custom fonts)
- Do NOT modify Swift source files when updating tokens — update the colorset `Contents.json` via Xcode
