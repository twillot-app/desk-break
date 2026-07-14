---
description: Fire one desk-break reminder now (fast ~8s dry-run; does not affect stats)
---

# /test — fire a desk-break reminder now

Trigger a single reminder immediately as a fast dry-run.

## Instructions

Run:

```bash
~/.local/bin/desk-break.sh --test
```

This shows the dialog / notification, speaks (if enabled), plays a short burst of
workout music, then stops — and does **not** change streak stats. Report the result
from the tail of `~/.local/share/desk-break/reminder.log`. For a real, full-length
fire instead, use `launchctl kickstart gui/$(id -u)/com.$(id -un).desk-break`.
