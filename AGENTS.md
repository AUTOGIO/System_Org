# Agent notes — System Organizer

Personal macOS automation hub (SwiftUI / SwiftPM). Prefer small, safe edits. Do not redesign features.

## Folder layout

| Path | Purpose |
|------|---------|
| `Sources/` | Application code (SwiftPM; use instead of `src/` / `app/`) |
| `Tests/` | Tests only |
| `scripts/` | Runnable helpers (`.sh`, `.py`, deploy helpers) |
| `config/` | Non-secret settings (JSON manifests) |
| `assets/` | Images, icons, logos |
| `docs/` | Guides and design notes |
| `docs/prompts/` | AI prompt files |
| `archive/` | Obsolete files kept for reference (do not delete casually) |
| Root | Only `README.md`, `AGENTS.md`, `.gitignore`, and toolchain files (`Package.swift`, `*.code-workspace`, etc.) |

Do not invent new top-level folders without asking. Prefer move over copy. Prefer edit over rewrite. Do not commit secrets (`.env`, keys, `Secrets.swift`). Do not put personal machine inventory into this file.
