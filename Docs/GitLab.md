# GitLab port (`glab`)

Pure-Swift port of [`gitlab-org/cli`](https://gitlab.com/gitlab-org/cli)
(`glab`). Targets the `glab issue` surface first; everything else is
TODO.

## Targets

| Target / Product | Role |
|------------------|------|
| `GitLab` (lib)        | API client (`X-Next-Page` pagination, Bearer auth), Codable models, `RepositoryReference` (with nested-subgroup support), `Configuration` + `ConfigurationResolver`. No ArgumentParser dependency. |
| `GlabCommand` (lib)   | The full subcommand tree as `AsyncParsableCommand` types. Importable across packages — SwiftBash extends `GlabCommand` to register the whole tree as a Bash builtin. |
| `glab` (exec)         | Four-line `Entry.swift` wrapper. `@main` delegates to `GlabCommand.main()`. |

Layout under `Sources/GitLab/{Lib,GlabCommand,glab}/` per the
SwiftPorts umbrella convention (see [AGENTS.md](../AGENTS.md)).

## What works

### Issue surface (parity with `glab issue --help` from upstream)

```
glab issue list           --repo, --assignee, --author, --label, --milestone,
                          --search, --all, --closed, --confidential,
                          --per-page, --page, --json
glab issue view <id|url>  --repo, --web, --comments, --json
glab issue create         --title (req), --description, --label, --assignee,
                          --milestone, --confidential, --json
glab issue update <id>    --title, --description, --label/--unlabel,
                          --assignee/--unassign, --milestone, --confidential/--public,
                          --lock-discussion/--unlock-discussion, --weight,
                          --due-date, --json
glab issue close <id>
glab issue reopen <id>
glab issue note <id>      --message (req)
glab issue subscribe <id>
glab issue unsubscribe <id>
glab issue delete <id>
glab issue board [view]   Opens the kanban board page in a browser
                          (terminal kanban TUI from upstream is not ported)
```

`<id>` for any of the above is one of: `123`, `#123`, or a full URL
like `https://gitlab.com/group/sub/repo/-/issues/123`. URL form
overrides `--repo` and switches the API client to the URL's host
automatically — same behaviour as upstream `glab`.

### Auth surface

```
glab auth status   [-h <host>] [--show-token]
glab auth login    [-h <host>] [--with-token]   PAT-based
glab auth logout   [-h <host>]
glab auth token    [-h <host>]                  Print resolved token
```

Token resolution order, mirroring upstream:

1. `GITLAB_TOKEN` env var
2. `GITLAB_ACCESS_TOKEN` env var
3. `OAUTH_TOKEN` env var
4. Keychain (`com.swiftgl.glab`, account = host)
5. nil

Host resolution: explicit `-h` flag > `GITLAB_HOST` > `GITLAB_URI` >
`GL_HOST` > `gitlab.com`.

`auth login` is **PAT-only**. Create a token at
<https://gitlab.com/-/user_settings/personal_access_tokens> (or the
equivalent on a self-hosted instance) and paste it. Pipe a token
non-interactively with `--with-token`. The OAuth device-flow / web
callback login from upstream `glab` is not implemented here.

### Repository reference

Parses any of:

- `OWNER/REPO`
- `GROUP/SUB/REPO` (and arbitrarily deeper subgroup chains)
- `HOST/OWNER/REPO`, `HOST/GROUP/.../REPO` — first segment becomes
  the host iff it contains a `.`
- a full HTTPS / SSH git remote URL

`encodedPath` percent-encodes only the `/` separators
(`gitlab-org%2Fcli`, `group%2Fsub%2Frepo`) — the form GitLab's REST
API expects.

### Host resolution

When `-R` carries no host (`-R group/repo`), the resolver:

1. Checks the cwd's `origin` git remote — if it parses to a GitLab
   URL, the **host** from that remote is grafted onto the `-R` path.
   Lets `glab issue list -R group/repo` "just work" inside a clone of
   any self-hosted instance with no `--hostname` / `GITLAB_HOST`.
2. Falls back to `GITLAB_HOST` / `GITLAB_URI` / `GL_HOST` if the cwd
   has no usable remote.
3. Falls back to `gitlab.com` if nothing else applies.

Explicit hosts (`-R host.example.com/group/repo`, full URL form)
always win — no inference happens when a host is already present.
With no `-R` at all, both the host and path are inferred from the
cwd remote.

## What doesn't work yet

- **OAuth device flow** for `auth login` (PAT-only today).
- **Editor-driven description / body editing** — upstream `glab` lets
  you pass `-d -` or omit `-t` to drop into `$EDITOR`. Not ported;
  pass the body inline via `-d "..."`.
- **`glab mr ...`** — merge requests not implemented yet. The
  underlying API client and Configuration are reusable.
- **`glab repo ...`** — repos not implemented.
- **Kanban board TUI** — `glab issue board` opens the board page in
  a browser (`https://<host>/<path>/-/boards`). The terminal kanban
  interface from upstream isn't ported.
- **`glab ci ...`** (pipelines), `glab release ...`, `glab snippet
  ...`, `glab variable ...`, `glab schedule ...`, `glab cluster ...`,
  `glab incident ...`, `glab token ...` — all upstream surfaces
  beyond issues + auth.

## Testing

```bash
swift test --filter GitLabTests
```

`GitLabTests` covers `RepositoryReference` parsing across the formats
listed above, `Configuration` env-var precedence, `IssueArgument`
parsing (numeric, `#123`, URL), `Issue` JSON decoding from a captured
fixture, and argv parsing for every issue + auth subcommand.

## Live verification

`glab issue list --repo gitlab-org/cli --per-page 5` and `glab issue
view --repo gitlab-org/cli 1` work end-to-end against gitlab.com
without auth (read-only public endpoints). With a PAT in
`GITLAB_TOKEN`, write-side commands (`create`, `update`, `close`,
`reopen`, `note`, `subscribe`, `unsubscribe`, `delete`) work against
projects you have access to.
