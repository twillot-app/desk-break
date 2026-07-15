---
description: Set up or reconfigure desk-break (language, interval, reminder style, music, persona)
---

# /setup — configure desk-break

Run the desk-break **setup** flow.

## Instructions

Invoke the `desk-break` skill and follow its **setup flow** — ask the configuration
questions (language, interval, reminder style, music, persona, fun-pack toggles),
write `~/.config/desk-break/config.env`, install the runner and i18n data, register
the launchd agent, then verify with a quick `--test`.

If the skill isn't available in this agent, follow the setup steps in
`skills/health/desk-break/SKILL.md` directly.
