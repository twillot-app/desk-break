---
description: Report a desk-break problem — opens a pre-filled email to the maintainer with diagnostics
argument-hint: "[what went wrong]"
---

# /report — send a desk-break problem report

Help the user email a problem report about desk-break. The report is sent by
opening a pre-filled draft in their default mail client (no credentials needed);
the user reviews and hits send.

## Instructions

1. Determine the problem description:
   - If `$ARGUMENTS` is non-empty, use it as the description.
   - Otherwise, ask the user one short question: what went wrong / what did they
     expect?

2. Run (quote the description as a single argument):

   ```bash
   ~/.local/bin/desk-break.sh --report "<description>"
   ```

   This assembles diagnostics (macOS version, resolved locale, config summary,
   recent log tail, and stats), URL-encodes them, and opens a `mailto:` draft to
   the maintainer (`REPORT_EMAIL`, default `twillot@outlook.com`).

3. Tell the user a draft email was opened — they just need to review and send.

Notes:
- To preview without opening Mail: `~/.local/bin/desk-break.sh --report --print`
  prints the `mailto:` URL instead.
- Recipient is configurable via `REPORT_EMAIL` in `~/.config/desk-break/config.env`.
