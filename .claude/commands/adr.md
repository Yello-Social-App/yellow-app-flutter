---
description: Append a decision record to docs/DECISIONS.md
argument-hint: [the decision to record]
allowed-tools: Read, Edit, Bash(git diff:*), Bash(git log:*)
---

Append an ADR to `docs/DECISIONS.md` for: $ARGUMENTS

Read the existing entries first — match their voice and length, and take the
next number in sequence. Never renumber or delete an existing entry; a
reversed decision gets marked *Superseded by ADR-NNN* and stays.

Keep it to four short parts:

- **Status** — Accepted / Accepted (forced) / Superseded by ADR-NNN
- the decision itself, in one or two sentences
- **Why** — the actual reason, including the alternative that was rejected and
  what it would have cost
- **Revisit if / when** — the concrete condition that would reopen this

If the decision was to *not* use a pattern or library, say which one and why —
that's the part a future reader can't reconstruct.

Be honest about cost. An ADR that reads as pure upside isn't a decision, it's
an advertisement.
