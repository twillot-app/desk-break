---
description: Show your desk-break exercise stats — streak, completion rate, and last 7 days
---

# /stats — desk-break exercise history

Run the desk-break stats report and present it to the user.

## Instructions

1. Run:

   ```bash
   ~/.local/bin/desk-break.sh --stats
   ```

2. Show the output. It includes: current streak (🔥) and best streak, today's
   completed vs. prompted counts, all-time totals with completion rate, current
   ignore streak, and a "last 7 days" bar chart of completed breaks.

3. If the command isn't found or reports nothing, desk-break may not be installed
   yet — point the user to `/desk-break setup`.

Notes:
- Output language follows the desk-break `LOCALE` setting (auto/en/zh).
- History comes from `~/.local/share/desk-break/history.log`; aggregates from
  `~/.local/share/desk-break/stats.env`.
