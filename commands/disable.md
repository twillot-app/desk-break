---
description: Disable desk-break — unload the launchd agent but keep all files
---

# /disable — pause desk-break

Stop desk-break from firing, without removing anything.

## Instructions

Run:

```bash
launchctl bootout "gui/$(id -u)/com.$(id -un).desk-break"
```

Confirm it's gone with `launchctl list | grep desk-break` (no output = disabled).
Tell the user to re-enable later with `/desk-break:enable`. Config, data, and stats
are untouched.
