---
description: Uninstall desk-break — unload the agent and remove its files
---

# /uninstall — remove desk-break

Fully remove desk-break. **Confirm with the user first** — this stops the reminder
and deletes the runner/plist.

## Instructions

1. Confirm the user wants to uninstall.
2. Unload and remove the agent + runner:

   ```bash
   launchctl bootout "gui/$(id -u)/com.$(id -un).desk-break" 2>/dev/null
   rm -f ~/Library/LaunchAgents/com.$(id -un).desk-break.plist ~/.local/bin/desk-break.sh
   ```

3. Ask whether to also delete config, localized data, and stats history. Only if yes:

   ```bash
   rm -rf ~/.config/desk-break ~/.local/share/desk-break
   ```

Report exactly what was removed and what (if anything) was kept.
