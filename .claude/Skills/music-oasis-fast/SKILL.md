---
name: mobile-fast-precise-execution
description: Use this skill for ANY coding task in a mobile app repo (Flutter, React Native, native iOS/Swift, native Android/Kotlin) — features, bug fixes, refactors, or reviews. Trigger it whenever the user is working in a mobile codebase and cares about speed/token cost, even if they don't say so explicitly, because the rules here (parallel tool calls, minimal reads, targeted edits, scoped verification) are the default for every mobile task, not an opt-in. It exists to keep Claude Code fast and cheap on execution WITHOUT trading away precision — no dropped edge cases, no skipped error handling, no silently-changed behavior. If a task risks losing detail to go faster, this skill says slow down for that part specifically rather than for the whole task.
---

# Fast, Precise Mobile Execution (Claude Code)

Speed here means *fewer wasted tool calls and tokens*, never *less correctness*. The two are not in
tension if you're disciplined about what to read, what to touch, and what to verify. This skill is
the default operating mode for mobile app work — apply it even when the user doesn't mention
performance or tokens.

---

## 1. Gather context fast, not shallow

- **Search before you read.** Use `grep`/`glob`/`rg` to find the exact symbol, widget, screen, or
  function first. Open files at the line range you need, not the whole file "just in case" — unless
  the file is small (<150 lines) or you're about to edit most of it anyway.
- **Parallelize independent lookups.** If you need to check 3 unrelated files (e.g. a model, its
  provider/viewmodel, and a test), issue those reads together in one turn instead of serially.
- **Follow the actual call graph, not assumptions.** Don't guess how a platform channel, navigation
  route, or state object is wired — grep for its usages. A wrong assumption costs far more tokens
  (a broken edit + a fix pass) than one extra search.
- **Read the test file before editing the code it tests.** It's the fastest way to learn the
  contract you must not break, and it's cheaper than inferring behavior from the implementation alone.

## 2. Edit precisely, not broadly

- **Patch, don't regenerate.** Targeted diffs only. Re-emitting a whole file to change a few lines
  both burns tokens and risks silently dropping code you didn't mean to touch — this is the single
  biggest source of "lost detail" bugs.
- **Preserve existing error handling and edge-case branches** even when they look redundant — a
  platform-specific null check, an empty-state branch, a try/catch around a flaky platform API call
  is very often there because of a bug report, not oversight. If you think a branch is genuinely
  dead, say so and ask, don't quietly remove it.
- **Match the file's existing patterns** (naming, state-management style, error propagation
  approach) instead of introducing a new pattern for one function — consistency is what makes the
  next change fast too.
- **One concern per edit pass.** Don't fold a refactor into a bug fix in the same diff; it forces
  wider review and hides the actual fix.
- **Batch edits across files in the same turn** when they're part of one logical change (e.g. a
  model field rename touching the model, its serializer, and two call sites) — don't ping-pong
  read → edit → read → edit when you already know all the call sites from step 1.

## 3. Verify at the right scope, every time

Fast does not mean skipping verification — it means verifying the *right amount*, precisely:

- **Type-check/analyze the touched files/module**, not a full clean rebuild, for routine edits
  (`flutter analyze <path>`, `tsc --noEmit` scoped where possible, targeted lint).
- **Run the tests that cover what you changed** first (by file/tag/name pattern), not the entire
  suite, unless the change is cross-cutting (shared model, DI graph, navigation shell) — then widen.
- **Full build/run is for the end of a task or a platform-specific risk area** (native module
  bridging, permissions, background execution, deep links) — not after every small edit.
- **When a change touches platform-specific code (iOS/Android/permissions/native modules),
  explicitly verify both platforms** even if you only tested one — mobile bugs live in platform
  divergence, and skipping the other platform is the classic way precision gets lost while going fast.

## 4. Where to deliberately slow down

Some categories are worth spending extra tokens on, even mid-task — flag these to the user rather
than rushing through:

- Auth, payments, keychain/keystore, or any secret-handling code.
- Data migrations (local DB schema changes, cache format changes) — a fast wrong migration is
  irreversible for users who already upgraded.
- Anything touching background execution, push notifications, or app lifecycle transitions —
  hard to test locally, easy to silently break.
- Any change to a shared/core module used across many screens — the review scope is the whole
  usage graph, not just the diff.

## 5. Reporting back — stay terse, stay complete

- Summarize *what changed and why* in a few lines, not a restatement of the diff.
- Always call out anything you deliberately left alone but noticed (a related bug, a TODO, a
  platform gap) — flagging it costs one line; missing it silently is the "lost detail" failure mode
  this skill exists to prevent.
- If you scoped verification narrowly (per §3), say what you ran and what you didn't, so the user
  knows what's still unverified rather than assuming full coverage.

## 6. Anti-patterns to avoid

- Rewriting a whole file for a one-line change.
- Skipping the other platform when a fix is platform-specific by nature.
- Removing "unused-looking" error handling without confirming it's actually dead.
- Running the full test suite/build for every micro-edit (slow, and trains the user to ignore your
  status updates) *or* running nothing at all until the very end (risks compounding a bad edit).
- Silently changing public API/widget signatures while doing an "internal" refactor.
- Batching unrelated changes into one diff because they happened to touch the same file.
