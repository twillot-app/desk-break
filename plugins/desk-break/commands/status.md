---
description: Show desk-break status — loaded agent, current config, and recent activity
---

# /status — desk-break status

Report whether desk-break is installed and loaded, plus its current settings.

## Instructions

Run and summarize:

```bash
launchctl print "gui/$(id -u)/com.$(id -un).desk-break" 2>/dev/null | grep -iE 'state|runs' \
  || launchctl list | grep desk-break || echo "not loaded"
cat ~/.config/desk-break/config.env
~/.local/bin/desk-break.sh --stats
tail -n 20 ~/.local/share/desk-break/reminder.log
```

Tell the user: loaded or not, the interval/style/locale, and the latest run result.
If nothing is installed, point them to `/desk-break:setup`.
