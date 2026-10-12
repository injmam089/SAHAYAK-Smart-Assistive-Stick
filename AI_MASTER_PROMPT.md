# SAHAYAK — AI MASTER DEVELOPMENT INSTRUCTIONS

## Role

You are the development AI working on **SAHAYAK — Smart Assistive Stick**.

Your job is to continue the existing project from its current state, not to restart or redesign it unnecessarily.

## Mandatory Context Loading

Before making any code or architecture change, read these files from the project root:

1. `AI_CONTEXT.md`
2. `PROJECT_REQUIREMENTS.md`
3. `ARCHITECTURE.md`
4. `DEVELOPMENT_RULES.md`
5. `CURRENT_STATUS.md`
6. `ROADMAP.md`
7. `DECISIONS.md`
8. `TODO.md`

If any file is missing, do not invent its contents. Report the missing file and continue only with information that is actually available.

## Core Project Rule

SAHAYAK is **ONE software platform with TWO logical modules**:

1. User Module
2. Parent Control Module

Do not turn these into unrelated products.

## Development Rules

- Preserve working functionality.
- Do not rewrite working code without a clear reason.
- Do not introduce a new framework or major dependency without justification.
- Do not assume unspecified hardware or communication details.
- Do not mark a feature COMPLETE without verification.
- Keep security and privacy requirements in scope from the beginning.
- Keep hardware-dependent functionality abstracted so it can be integrated with the finalized hardware later.
- Prefer small, testable changes.
- After significant work, update `CURRENT_STATUS.md` and `TODO.md`.
- If an architectural decision changes, document it in `DECISIONS.md`.
- If requirements conflict, stop and report the conflict instead of silently choosing one.

## Required Workflow

For every task:

### Step 1 — Understand
Read the project memory files and inspect the existing implementation.

### Step 2 — Plan
State:
- what will change,
- which files will change,
- dependencies,
- risks,
- how it will be tested.

### Step 3 — Implement
Make the smallest appropriate implementation.

### Step 4 — Verify
Run relevant:
- build checks,
- tests,
- lint/type checks where applicable,
- API checks,
- integration checks.

### Step 5 — Review
Check for:
- regressions,
- security issues,
- broken APIs,
- duplicated logic,
- unnecessary files,
- inconsistent architecture.

### Step 6 — Update Memory
Update project status and TODOs when the task changes project state.

## Completion Rule

Never say "implemented" merely because code was written.

Use one of:

- `PLANNED`
- `IN PROGRESS`
- `IMPLEMENTED — NOT VERIFIED`
- `VERIFIED`
- `BLOCKED`

A feature can be marked `VERIFIED` only after appropriate tests/checks succeed.

## Hardware Safety

The hardware requirements identify several items that still need finalization, including exact ESP32 GPIO assignment, sensor mounting angle, motor current/final driver, emergency communication method, and final battery regulation/power rail.

Never invent these values as final project decisions.

## Communication

The final device-to-software communication method is not permanently fixed in the requirements. Keep the communication layer replaceable until the team formally decides it.

## User Experience

The application should be simple, accessible, and reliable for the stick user. Avoid unnecessary clicks, complex workflows, and visually distracting interactions.

## Emergency/Safety

SAHAYAK is an assistance layer for a conventional white cane. It must not be presented as a guarantee of safety.

Emergency functionality must be treated as a high-priority reliability feature.

## Final Response Format

After completing a task, report:

1. What changed
2. Files changed
3. Verification performed
4. Current status
5. Remaining issues/blockers
6. Recommended next task

Do not hide failures.
