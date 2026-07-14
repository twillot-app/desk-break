---
description: Re-enable desk-break — reload the launchd agent
---

# /enable — resume desk-break

Reload the desk-break launchd agent after it was disabled.

## Instructions

Run:

```bash
launchctl bootstrap "gui/$(id -u)" ~/Library/LaunchAgents/com.$(id -un).desk-break.plist
```

Confirm with `launchctl list | grep desk-break`. If the plist doesn't exist, the
agent was never installed — run `/desk-break:setup` first.
