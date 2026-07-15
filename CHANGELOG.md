# Changelog

All notable changes to desk-break are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/), and the project adheres to
[Semantic Versioning](https://semver.org/).

## [0.4.0]

### Added
- **npm CLI** — `npx desk-break setup` installs the runner + localized data,
  writes a default config, and registers the launchd agent for any agent (Codex,
  Cursor) or no agent at all. Also `test`, `stats`, `report`, `enable`, `disable`,
  `uninstall [--purge]`, and a `--dry-run` that previews every step without touching
  anything. macOS-guarded, zero dependencies.
- No-equipment exercises with animated demo cards, body-part focus with
  anti-repetition, and industry-flavored copy (surfaced in this release's docs).

### Changed
- **Repo restructured** to a root-level Claude Code plugin (matching the
  `mattpocock/skills` layout): the skill now lives at
  `skills/health/desk-break/`, commands at `commands/`, and the plugin
  manifest at `.claude-plugin/plugin.json`; `marketplace.json` `source` is now `./`.
  The installed runner is unaffected — existing setups keep working.
- **Docs consolidated** — the separate `USAGE.md` / `USAGE.zh-CN.md` guides are
  merged into `README.md` / `README.zh-CN.md`, reordered so Features → Install →
  Usage come first, with a dedicated Codex install section.

### Removed
- `USAGE.md` and `USAGE.zh-CN.md` (content merged into the READMEs).
