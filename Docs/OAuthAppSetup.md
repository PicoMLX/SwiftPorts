# Registering SwiftGH's OAuth app

`gh auth login` runs the OAuth device flow against GitHub. That flow
needs a registered OAuth app — identified by a `client_id` — to know
what to show on the consent screen and what to attribute the granted
token to.

For development, SwiftGH currently embeds the **upstream gh** client
ID (`178c6fc778ccc68e1d6a`) so the flow works out of the box. **Before
SwiftGH ships publicly we need to register our own app and replace
that default.** Doing so is ~2 minutes of clicking, no money, no
secret to manage.

## Why our own app is the right thing

1. **Attribution.** Right now the consent screen says *"GitHub CLI
   wants to access your account"* and the resulting authorized app
   shows up in the user's
   [`Settings → Applications → Authorized OAuth Apps`](https://github.com/settings/applications)
   as "GitHub CLI" — the upstream gh project, run by GitHub
   themselves. That's misleading: the user authorized SwiftGH, not gh.
2. **Blame.** If SwiftGH ever has a token-handling bug, the audit
   trail in GitHub points at upstream gh because that's whose name is
   on the grant. They don't deserve that.
3. **Quota.** OAuth apps share rate limits across all users on the
   same `client_id`. Riding on gh's quota is fine when SwiftGH has
   ten users; less fine when it has ten thousand.
4. **Policy.** GitHub's Developer Policy expects each app to register
   its own ID. Reusing someone else's is allowed in practice (gh's ID
   is embedded in many third-party tools) but it's not the shape they
   want, and they reserve the right to revoke.

## What's involved

About 90 seconds of clicking. No client secret needed (device flow
doesn't use one). No paid plan, no review, no waiting period.

### Step-by-step

1. **Go to** <https://github.com/settings/applications/new>.

   This is your *personal* OAuth-app registration page. The app can
   be moved to the Cocoanetics organization afterward
   (`Settings → Transfer ownership`) if that's preferred for
   publicity / governance.

2. **Fill in:**

   | Field | Value |
   |---|---|
   | Application name | `SwiftGH` |
   | Homepage URL | `https://github.com/Cocoanetics/SwiftPorts` |
   | Application description | `Swift port of the GitHub CLI` *(optional)* |
   | Authorization callback URL | `http://localhost/swiftgh-unused` |

   The callback URL is **required by the form** but **not used by the
   device flow**. Any plausible URL is fine. Don't pick something a
   real local web server might intercept (e.g. `http://localhost:8080`).

3. **Click "Register application."**

4. **On the resulting page**, scroll down and check
   **"Enable Device Flow"**, then click **"Update application."**

   This is the gate that makes our `POST /login/device/code` requests
   succeed. Without it the API returns `device_flow_disabled`.

5. **Copy the Client ID** at the top of the page. It looks like a
   20-character hex string (e.g. `Iv1.abc123...` or
   `178c6fc778ccc68e1d6a`-shaped). **This is not a secret** — the
   same ID will be embedded in every SwiftGH binary.

6. **Do not generate a client secret.** Device flow does not need one.
   The "Generate a new client secret" button on the same page is for
   the web flow, which we deliberately don't support.

## Wiring the new ID into SwiftGH

Two options once the ID is in hand.

### Option A — replace the default (preferred for shipping)

Edit
[`Sources/SwiftGHCore/Auth/OAuthDeviceFlow.swift`](../Sources/SwiftGHCore/Auth/OAuthDeviceFlow.swift):

```swift
public static let swiftGHClientID = "<NEW_ID_HERE>"
```

Rename `ghCLIClientID` → `swiftGHClientID` (one call site, in
`Sources/SwiftGHCommand/Subcommands/Auth/AuthLogin.swift`).

Commit. Done.

### Option B — env-var override (preferred while testing)

Keep the upstream gh ID as the public default for now, but let your
own dev builds opt into the SwiftGH app:

```bash
export SWIFTGH_OAUTH_CLIENT_ID=<NEW_ID_HERE>
gh auth login
```

In `AuthLogin.swift`'s `clientID` option, add a fallback to
`ProcessInfo.processInfo.environment["SWIFTGH_OAUTH_CLIENT_ID"]` so
the env var beats the compiled-in default. Optional improvement; not
strictly needed.

## After registration

- Verify by running through the full flow:
  ```bash
  swift build
  env -u GH_TOKEN -u GITHUB_TOKEN .build/debug/gh auth login
  ```
  The browser page should now say *"SwiftGH wants to access your
  account"* and the entry in
  [Settings → Applications](https://github.com/settings/applications)
  should be "SwiftGH" linking to whatever Homepage URL you set.

- The previously authorized "GitHub CLI" entry (from earlier dev
  testing) is unrelated — it's gh's app, not ours, and revoking it
  affects upstream gh, not SwiftGH. Leave it alone.

- Tokens issued under the old client ID stay valid until the user
  revokes them; switching the default doesn't break existing logins,
  but new logins will be attributed correctly.

## What we still don't ship

- **Web OAuth flow.** Same client ID, but adds a localhost callback
  listener and `client_secret`. We've decided not to ship the web
  flow at all (too hostile to embedded use); device flow covers
  every supported environment. Keep the callback URL as the
  unused placeholder.

- **Fine-grained PATs.** GitHub's newer per-resource tokens are
  generated by users in their account settings, not via OAuth flows.
  SwiftGH consumes them via `--with-token` / `GH_TOKEN` like any
  other token; nothing to register.

## TL;DR

Public ship blocker, not a build blocker. Register at
<https://github.com/settings/applications/new>, enable Device Flow,
copy the client ID, paste into `OAuthDeviceFlow.ghCLIClientID`,
commit. Done.
