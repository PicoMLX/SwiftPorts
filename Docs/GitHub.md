# GitHub port (`gh`)

Pure-Swift port of [`cli/cli`](https://github.com/cli/cli) (`gh`).
Targets a broad slice of the upstream surface — auth, repos, PRs,
issues, releases, projects (v2 GraphQL), workflows, runs, gists,
search, plus account-level admin.

## Targets

| Target / Product | Role |
|------------------|------|
| `GitHub` (lib)        | REST + GraphQL API client, OAuth device flow, Codable models, `RepositoryReference` parsing, `Configuration` + `ConfigurationResolver`, hosts.yml read/write. No ArgumentParser dependency. |
| `GhCommand` (lib)     | The whole AsyncParsableCommand subcommand tree. Importable across packages — SwiftBash extends `GhCommand` to register the entire `gh` surface as a Bash builtin. |
| `gh` (exec)           | Four-line `Entry.swift` wrapper. `@main` delegates to `GhCommand.main()`. |

Layout under `Sources/GitHub/{Lib,GhCommand,gh}/` per the SwiftPorts
umbrella convention (see [../AGENTS.md](../AGENTS.md)).

## Auth

```
gh auth login    [--web] [--clipboard]   OAuth device flow
gh auth status   [-h <host>] [--show-token]
gh auth logout   [-h <host>]
gh auth token    [-h <host>]             Print resolved token
```

`auth login --web` runs the device-code OAuth flow against
github.com (or `--hostname` for GitHub Enterprise). On approval, the
token lands in the macOS Keychain. `--clipboard` copies the user
code to the clipboard before opening the verification URL.

OAuth client-ID setup for the publish-time swap: see
[OAuthAppSetup.md](OAuthAppSetup.md).

Token resolution order, mirroring upstream:

1. `GH_TOKEN` env var
2. `GITHUB_TOKEN` env var
3. Keychain (`com.swiftgh.gh`, account = host)
4. `~/.config/gh/hosts.yml` `oauth_token` field (the upstream
   `--insecure-storage` fallback)
5. nil

Repo inference: `git remote get-url origin` via
`ForgeKit.ProcessGitClient`.

## Subcommand surface

```
gh repo       view / list / create / clone / fork / archive /
              edit / rename / delete
gh pr         list / view / create / edit / merge / close / reopen /
              ready / lock / checkout / checks / comment / diff /
              update-branch
gh issue      list / view / create / edit / close / reopen / lock /
              pin / develop / comment
gh release    list / view / create / download / delete
gh workflow   list / view / run / disable / enable
gh run        list / view (--jobs / --job / --log / --exit-status) /
              watch / rerun / cancel / download
gh project    list / view / create / edit / close / delete /
              copy / template / link / unlink /
              field-list / field-create / field-delete /
              item-list / item-add / item-archive / item-edit /
              item-create / item-delete
gh gist       list / view / create / delete
gh label      list / create / edit / delete / clone
gh search     code / commits / issues / repos / prs
gh org        list (more on the way)
gh ssh-key    list / add / delete
gh gpg-key    list / add / delete
gh variable   list / set / delete (repo + env scopes)
gh secret     list / set / delete (repo + env + dependabot scopes)
gh cache      list / delete
gh config     get / set / list
gh api        the generic raw-API hatch
gh browse     open the resolved repo / PR / issue / file / commit
              in your browser (with `--no-browser` for printing only)
gh version
```

## Networking

- REST against `https://api.github.com` (or `https://<host>/api/v3`
  for GHES).
- GraphQL against `https://api.github.com/graphql`.
- Pagination follows the `Link: rel="next"` header (the GitHub
  convention, contrast with GitLab's `X-Next-Page`).
- Rate-limit headers (`X-RateLimit-Remaining`, `X-RateLimit-Reset`)
  are surfaced to callers; `gh api` shows them when verbose.
- 401 → `APIError.unauthenticated`, 404 → `.notFound`,
  403 + remaining=0 → `.rateLimited(resetAt:)`.

## Local git integration

`gh repo clone`, `gh pr checkout`, `gh pr create`, `gh issue develop`,
and `gh repo fork` shell out to the user's `git` binary via
`ForgeKit.ProcessGitClient`. That preserves their actual ssh-agent,
credential helper, commit-signing config, and hooks. Embedders that
can't run `Process` (sandboxed iOS / server contexts) can inject
`ForgeKit.NoGitClient` — git-aware commands fail fast with a clear
"this command needs git" message instead of crashing.

## Adopts

- [`swift-argument-parser`](https://github.com/apple/swift-argument-parser)
- [`swift-http-types`](https://github.com/apple/swift-http-types)
- [`swift-configuration`](https://github.com/apple/swift-configuration)
  (with `YAML` + `CommandLineArguments` traits)
- [`swift-crypto`](https://github.com/apple/swift-crypto)
- [`Yams`](https://github.com/jpsim/Yams) for hosts.yml read/write
- Apple's `Security` framework for Keychain access
- `ZipKit` (sibling port) for `gh run view --log` and `gh run download`

## Skipped / out of scope

- **`gh attestation`** — Sigstore + transparency-log stack, large
  dependency footprint.
- **`gh codespace ssh`** — needs dev-tunnels and PTY plumbing.
- **`gh extension install`** — upstream extensions are Go binaries;
  the plugin model doesn't translate cleanly.
- **Web-OAuth flow** — device-code OAuth is sufficient.

## Testing

```bash
swift test --filter GitHubTests
```

`GitHubTests` covers SDK decode round-trips, OAuth device-flow
state machine, networking against a `URLProtocol` mock, hosts.yml
parsing, command argv parsing for the bigger commands, and a tiny
set of opt-in live API tests gated by `GH_TOKEN` env var.

Fixtures: `Tests/GitHubTests/Fixtures/` holds captured GitHub API
JSON responses used by the decode tests.
