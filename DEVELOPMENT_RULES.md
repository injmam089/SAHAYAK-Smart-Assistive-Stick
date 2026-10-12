# SAHAYAK — DEVELOPMENT RULES

## Rule 1 — Do Not Forget the Product Structure

SAHAYAK = ONE platform + TWO modules:

- User Module
- Parent Control Module

## Rule 2 — No Unapproved Architecture Changes

Do not replace the agreed architecture because a new approach appears easier.

If a change is genuinely necessary:
1. explain why,
2. document alternatives,
3. record the decision,
4. then implement.

## Rule 3 — No Fake Completion

Code written ≠ feature verified.

Use the status system defined in `AI_MASTER_PROMPT.md`.

## Rule 4 — No Unsupported Assumptions

If a requirement is unknown, mark it as:
`TBD`, `BLOCKED`, or `NEEDS DECISION`.

Do not silently invent a final value.

## Rule 5 — Preserve Existing Work

Before modifying a file:
- inspect it,
- understand dependencies,
- avoid unnecessary rewrites.

## Rule 6 — Security by Default

Do not:
- hardcode passwords,
- hardcode secrets,
- expose private data unnecessarily,
- bypass authentication for convenience,
- disable security merely to make a demo work.

## Rule 7 — Test Important Changes

At minimum, test the affected functionality and confirm that existing functionality still works.

## Rule 8 — Keep Documentation Current

When project state changes, update:
- `CURRENT_STATUS.md`
- `TODO.md`

When an architectural decision changes, update:
- `DECISIONS.md`

## Rule 9 — Keep Code Maintainable

Prefer:
- meaningful names,
- small functions,
- clear modules,
- centralized configuration,
- reusable services,
- minimal duplication.

## Rule 10 — Accessibility

The User Module must prioritize:
- readable text,
- clear status,
- simple navigation,
- understandable alerts,
- minimal interaction steps.

## Rule 11 — Emergency Features

SOS/emergency functionality must be tested separately and treated as a critical path.

## Rule 12 — Explain Before Large Changes

For major changes, provide a short implementation plan before editing many files.
