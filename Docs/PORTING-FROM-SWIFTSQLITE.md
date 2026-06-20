# Hardening the SQLite shell: what's here, and the SDK follow-ups

This package's `sqlite3` shell port (`Sources/SQLiteKit/Sqlite3Shell`) is meant to
run **untrusted, LLM-generated SQL** safely when installed as a SwiftBash builtin.
Most of the confinement design is borrowed from [PicoMLX/SwiftSQLite](https://github.com/PicoMLX/SwiftSQLite)
(PR #1), which built a purpose-made sandboxed engine. This note records (a) what was
implemented here at the **shell layer**, and (b) the **SDK-level** follow-ups that
belong in the engine package, [`Cocoanetics/SQLiteKit`](https://github.com/Cocoanetics/SQLiteKit)
(/ its PicoMLX fork), because they need the raw `sqlite3*` handle the shell never sees.

## Guiding principle: the policy is not argv

The agent writes the command line, so security expressed as opt-in flags is no
boundary. The policy (`SQLitePolicy`) is bound by the trusted embedder
(`Sqlite3Builtin(policy:)`) or auto-derived from `Shell.current.sandbox`, and **no
in-band channel — argv or dot-command — may relax it** (argv `-hardened` can only
turn hardening *on*; `.limit` may lower but not raise; `.open` re-applies the policy).

## Feature-preservation guard (read before touching the authorizer)

PicoMLX needs **`sqlite-vec` (`vec0`)** and **FTS5**, both `CREATE VIRTUAL TABLE …`
plus function calls. Do **not** port SwiftSQLite's blanket default-deny authorizer:
it omits `SQLITE_CREATE_VTABLE`/`SQLITE_DROP_VTABLE`, so it would reject vec0/FTS5
table creation. Every SDK change below must keep vtables, functions, and PRAGMA
working; harden only the escape/DoS boundary.

## Implemented here (shell layer, this PR)

- **Embedder-bound `SQLitePolicy`** + automatic hardening under a sandbox; argv
  `-hardened` is tighten-only.
- **Result output cap** (`maxResultBytes`) with a truncation notice — bounds what
  flows back to the caller / `$(…)`. Covers stdout, stderr, **and** the pre-`Session`
  error path in `run` (argv-parse / open failures, whose messages can echo the argv),
  so none of those channels can stream an uncapped payload back.
- **Runtime limits** via `database.limit`: `SQLITE_LIMIT_ATTACHED=0`, `…_LENGTH`,
  `…_SQL_LENGTH`; **`.limit` raise-blocking** so the in-band channel can't undo them.
- **`PRAGMA temp_store=MEMORY`** to keep temp spill in-region.
- **Canonicalize-before-authorize** on the DB open, ATTACH targets, and all
  file-touching dot-commands (`.read/.import/.output/.once/.backup/.restore/.open`).
- **Policy re-application on `.open`** (not just safe mode).
- **Attempted-tier audit** (`FileAuditSink`, JSON Lines, `O_NOFOLLOW` + preflight),
  written outside the DB; destination is embedder-set, never an argv path.
- **Script-budget timeout** (`statementTimeout`) checked between statements.
  Known limitation: it does not bound a blocking stdin read — a `sqlite3` with no
  SQL argument reading a pipe that never reaches EOF can still block before the
  budget is checked. Bounding that needs a cancellation-aware, `Sendable` stdin
  source (ShellKit's `InputSource`); the interactive REPL is refused outright under
  a timeout for the same reason.

## SDK follow-ups (need the `sqlite3*` handle — out of this package)

Each cites the SwiftSQLite source that implements it.

1. **Intra-statement timeout** — `sqlite3_progress_handler` + `sqlite3_interrupt` on
   `Task` cancellation. The shell's between-statements budget can't interrupt a
   single long query (e.g. a recursive CTE). *(SwiftSQLite `SQLiteConnection.run` /
   `EngineContext.isExpired` / `csqliteProgressCallback`.)*
2. **Streaming / callback step API** so a row cap stops the engine *before* it
   materializes a whole result set — the true engine-memory bound the shell's
   output cap can't provide. *(SwiftSQLite `ConnectionHandle.step`.)*
3. **Committed / per-row audit** — `sqlite3_commit_hook` / `update_hook` /
   `rollback_hook` for a committed tier alongside the shell's attempted tier.
   *(SwiftSQLite `EngineContext` hooks + `Audit.swift`.)*
4. **`SQLITE_OPEN_NOFOLLOW`** on the open, to fully close the symlink-swap window the
   shell's canonicalize-before-authorize only narrows. *(SwiftSQLite
   `ConnectionHandle.open`.)*
5. **`SQLITE_DBCONFIG_DEFENSIVE` + `SQLITE_DBCONFIG_TRUSTED_SCHEMA=0`** as
   feature-neutral runtime config. **Not** deny-all-PRAGMA and **not** default-deny
   vtables (feature-preservation guard). *(SwiftSQLite `ConnectionHandle.configure`.)*
6. **Compile flags** in the engine's CSQLite: `SQLITE_OMIT_LOAD_EXTENSION` (safe —
   static vec/FTS register without the runtime API), `SQLITE_DEFAULT_FOREIGN_KEYS=1`;
   gate `SQLITE_DQS=0` / `SQLITE_USE_URI=0` behind the hardened path so they don't
   change default sqlite3 behavior. Verify all still build with the `FTS5` /
   `SQLiteVec` traits.
7. **`SQLITE_TEMP_STORE=3`** (always-memory, PRAGMA cannot change it) is the
   definitive temp-confinement fix. The shell re-pins `PRAGMA temp_store=MEMORY`
   before each hardened statement to undo an in-band `PRAGMA temp_store=FILE`, but
   that is best-effort; the compile flag removes the need entirely. (Codex review
   P2, PR #1.)
8. **Sound `VACUUM … INTO` block.** `VACUUM INTO 'file'` writes a database file
   directly — SQLite opens it itself, bypassing `Shell.authorize`, the `.backup`
   read-only block, and a read-only source. The shell refuses it under the
   hardened/read-only policy with a *lexical* guard (`writesViaVacuumInto` on
   string/comment/quoted-identifier-stripped SQL). That is robust against the
   quote/whitespace evasions seen so far but is still lexical; the sound fix is
   to reject the VACUUM-INTO action at the SQLite tokenizer/authorizer level in
   the SDK (the shell only has the raw SQL string). Until then, keep the lexical
   guard. (Codex review P1, PR #1.)
