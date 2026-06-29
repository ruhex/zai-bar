# Changelog

All notable changes to **zai-bar** are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- _(nothing yet)_

### Changed

- _(nothing yet)_

### Fixed

- _(nothing yet)_

## [1.0.0] - 2026-06-29

### Added

- Initial release of **zai-bar**, a native macOS menu-bar widget for the z.ai
  GLM Coding Plan.
- **Menu-bar headline** showing the 5-hour token-window percentage
  (`TOKENS_LIMIT`, `unit=3`), color-coded green/orange/red, falling back to the
  weekly token window (`unit=6`) when the 5-hour figure is unavailable.
- **Popover** rendering every limit from `data.limits[]`, ordered as:
  5-hour tokens → weekly tokens → monthly web tools. Each row shows a progress
  bar, `% used`, used/total counts, and a live countdown to `nextResetTime`.
- **Per-model breakdown** (`usageDetails[]`) under the monthly web-tool limit.
- **Plan tier** (`data.level`) shown in the popover header.
- **Peak-hours block**: detects the 14:00–18:00 UTC+8 peak window, renders it in
  the user's local time, and shows the effective advanced-model
  (GLM-5.2 / GLM-5-Turbo) multiplier — 3× in peak, 2× off-peak, or 1× off-peak
  during the promo through 2026-10-01; GLM-4.7 is always 1×.
- **Auto-refresh every 5 minutes** plus an on-demand **Refresh** button; the
  reset countdown updates live every 30 seconds.
- **Keychain-backed API key** (service `zai-bar`, account `api-key`) with a
  Settings form to paste/save/remove the coding-plan key.
- **About line** in the popover, stamped from git by `release.sh`.
- Native `MenuBarExtra` + SwiftUI app, `LSUIElement = true` (no Dock icon), no
  third-party dependencies.
- **`release.sh`** build/release script that builds a **universal**
  (arm64 + x86_64) binary, signs it (Developer ID + notarization when
  credentials are present, otherwise adhoc), zips it with `ditto`, and
  publishes a GitHub Release.
- MIT license.

### Technical

- Target platform: **macOS 14.0+** (SwiftPM, `.macOS(.v14)`).
- Single endpoint: `GET https://api.z.ai/api/monitor/usage/quota/limit` with
  `Authorization: Bearer <key>`.
- Bundle id: `com.github.ruhex.zai-bar`.
- Outbound request is the only network activity — no telemetry.

[Unreleased]: https://github.com/ruhex/zai-bar/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/ruhex/zai-bar/releases/tag/v1.0.0
