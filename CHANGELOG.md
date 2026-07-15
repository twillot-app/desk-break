# Changelog

All notable changes to the **desk-break npm package** are documented here. The
format follows [Keep a Changelog](https://keepachangelog.com/), and the project
adheres to [Semantic Versioning](https://semver.org/).

> These versions track the npm package (`npx desk-break`). The Claude Code plugin
> is versioned independently in [`.claude-plugin/plugin.json`](./.claude-plugin/plugin.json).

## [0.2.0] - 2026-07-15

### Added

- Credibility badges in `README.md` and `README.zh-CN.md` — npm version,
  supported Node, license, and macOS platform. All are data-driven from the
  published package, so they stay accurate as new versions ship.

## [0.1.0] - 2026-07-15

First npm release — `npx desk-break` installs and manages the reminder for any
agent (Codex, Cursor) or no agent at all.

### Added

- **npm CLI** — `npx desk-break setup` installs the runner + localized data,
  writes a default config, and registers the launchd agent. Also `test`, `stats`,
  `report`, `enable`, `disable`, `uninstall [--purge]`, and a `--dry-run` that
  previews every step without touching anything. macOS-guarded, zero dependencies.
- Documented the exercise engine the package ships: no-equipment moves with
  animated demo cards, body-part focus with anti-repetition, and
  industry-flavored copy.

### Changed

- **Repo restructured** to a root-level Claude Code plugin (matching the
  `mattpocock/skills` layout): the skill now lives at `skills/health/desk-break/`,
  commands at `commands/`, and the plugin manifest at
  `.claude-plugin/plugin.json`; `marketplace.json` `source` is now `./`. The
  installed runner is unaffected — existing setups keep working.
- **Docs consolidated** — `USAGE.md` / `USAGE.zh-CN.md` merged into the READMEs,
  reordered so Features → Install (with a dedicated Codex section) → Usage come
  first.

### Removed

- `USAGE.md` and `USAGE.zh-CN.md` (content merged into the READMEs).

[0.2.0]: https://www.npmjs.com/package/desk-break/v/0.2.0
[0.1.0]: https://www.npmjs.com/package/desk-break/v/0.1.0
