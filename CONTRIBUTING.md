# Contributing to zai-bar

Thanks for your interest in improving zai-bar! This is a small native macOS app,
so the contributing flow is intentionally lightweight. A few things to know
before you start:

- zai-bar depends on **undocumented** z.ai `/api/monitor/*` endpoints. There is
  no public contract, so be conservative about assuming API behavior.
- The app targets **macOS 14+**, uses `MenuBarExtra` and the `@Observable`
  macro, and has **no third-party dependencies** — please keep it that way
  unless there's a compelling reason.

## Prerequisites

- macOS 14.0 (Sonoma) or newer.
- Swift 5.9+ toolchain (`swift --version`, or `xcode-select --install`).
- A z.ai GLM Coding Plan + a coding-plan API key (to see live data).

## Get the code

```bash
git clone https://github.com/ruhex/zai-bar.git
cd zai-bar
```

## Build & run

Quick dev run — the binary lives directly in your menu bar:

```bash
swift run
```

Build a universal, double-clickable `.app` (stamps `BuildInfo.swift` from git,
bundles the binary with `LSUIElement = true`):

```bash
./release.sh
open .build/ZAIBar.app
```

See the [README](./README.md#building-for-a-specific-architecture) for how to
build for a specific architecture (native vs. universal `--arch arm64 --arch x86_64`).

## First-run setup

1. Launch the app (a **⚡** icon appears in the menu bar).
2. Click **⚡** → paste your z.ai API key (`id.secret`) → **Save & connect**.

## Test your change

There's no automated test target yet — verify manually:

1. `swift run` and confirm the menu-bar headline shows the 5-hour token %.
2. Open the popover and check: limit rows render with progress bars, the reset
   countdown ticks, the peak-hours block reflects the current time, and the
   About line shows version/commit/source.
3. Exercise edge cases:
   - **Remove key** → popover returns to the settings form; the tray shows `z.ai`.
   - A bad/expired key → the tray shows a warning triangle and the popover shows
     an inline error.
   - No network → a network error message appears.
4. `./release.sh` should finish cleanly and produce a launchable, universal
   `ZAIBar.app` (verify with `file .build/ZAIBar.app/Contents/MacOS/ZAIBar`).

If your change touches the network layer, double-check it against the real
`api.z.ai` response (the `(type, unit)` window codes in particular).

## Commit messages

Use **Conventional Commits** in **English**. Subject line ≤ 72 chars,
imperative mood, no trailing period:

```
<type>(<scope>): <subject>

<optional body>
```

Common `type`s: `feat`, `fix`, `refactor`, `docs`, `chore`, `perf`, `style`,
`test`, `ci`. `scope` is optional (`ui`, `api`, `keychain`, `build`).

Examples:

```
feat(ui): show weekly token window in the popover
fix(api): handle 401 by clearing the cached key
chore(build): bump version to 1.1
```

Breaking changes: add a `!` after the type/scope (`feat(api)!: …`) and describe
the migration under a `BREAKING CHANGE:` footer.

## Pull request etiquette

- **One change per PR.** Keep PRs focused and reviewable.
- **Open an issue first** for features or API-shape changes. Bug fixes can go
  straight to a PR.
- **Branch off `main`** with a descriptive name
  (`feat/weekly-window`, `fix/expired-key-handling`).
- **Rebase onto the latest `main`** before opening and resolve conflicts yourself.
- **Don't reformat** unrelated code. Keep diffs minimal and on-topic.
- **Don't commit secrets.** `.gitignore` excludes `.env`, `*.key`, `*.pem`,
  etc. — never paste a real API key into code, issues, or PRs.
- **Describe what and why** in the PR description.

## Code style

- Match the existing Swift style (SwiftUI views, `@Observable` model,
  `@MainActor` where appropriate).
- No force-unwrapping beyond `URL(string:)` on hard-coded URLs.
- No new third-party dependencies without prior discussion.

## Reporting issues

See the [issue templates](./.github/ISSUE_TEMPLATE/). Bug reports are welcome —
please include your macOS version, zai-bar version/build (from the popover's
About line), and steps to reproduce.

Thanks for contributing!
