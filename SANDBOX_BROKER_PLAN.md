# Sandbox Credential Broker — Project Plan

## Context

The missing piece in agent/sandbox workflows: a sandboxed shell, devcontainer, or LLM agent needs scoped credentials, sometimes elevated. No off-the-shelf tool does **per-sandbox identity + human-in-loop approval + bundled credentials + low-friction steady state**.

## Position relative to existing tools

This project is **glue, not engine**. Each tool stays in its lane:

| Tool | Role |
|------|------|
| **granted** | Encrypted SSO session storage; TouchID-gated STS minting on host |
| **fnox** | Secret broker. Command-lease backend delegates AWS work to granted. Keychain backend for non-AWS secrets. MCP server exposes scoped allowlists to agents |
| **broker** (this project) | Per-sandbox identity + spawn wrapper + elevation approval flow + audit. Doesn't mint credentials — fnox/granted do |

What that means concretely:
- AWS credentials → broker asks fnox → fnox runs command-lease → command-lease invokes granted → granted returns STS
- Non-AWS secrets → broker asks fnox → fnox unlocks keychain item
- Approval prompt → broker shows notification + macOS dialog with TouchID gate
- Credential delivery to sandbox → broker writes file in per-sandbox mount

Broker is small. Maybe a single Go binary with a few subcommands.

## Goals

1. Each sandbox has its own credential scope (own AWS profiles, own PAT subset)
2. Sandbox requests elevation; host human approves once; broker delivers all components of the elevation
3. Elevated state is TTL-bounded, scoped to requesting sandbox, observable in prompt + tray
4. Default state is one-time setup, no per-action prompts
5. Audit trail of requests + decisions
6. Open-source friendly

## UX-first design

### Bundles: the unit of human approval

A **bundle** is a named, predefined set of credentials. Approving a bundle = one decision, multiple components delivered.

```toml
# ~/.config/broker/bundles.toml

[bundles.dpg-ops-readonly]
description = "Default DPG ops: read-only AWS + read-only GH"
[[bundles.dpg-ops-readonly.components]]
type = "aws"
profile = "dpg-ps-ops-ro"
[[bundles.dpg-ops-readonly.components]]
type = "fnox-secret"
name = "gh-readonly"
env_var = "GH_TOKEN"

[bundles.tf-apply]
description = "Terraform apply: workspace-AD + GH push"
default_duration = "15m"
max_duration = "1h"
require_reason = true
require_workspace_param = true
[[bundles.tf-apply.components]]
type = "aws"
profile = "${workspace}-ad"      # template — sandbox provides workspace
[[bundles.tf-apply.components]]
type = "fnox-secret"
name = "gh-push"
env_var = "GH_TOKEN"

[bundles.release]
description = "Release: GH push with release scope only"
default_duration = "10m"
[[bundles.release.components]]
type = "fnox-secret"
name = "gh-push-release"
env_var = "GH_TOKEN"
```

**Why bundles:** the human cognitive unit isn't "an AWS profile" — it's "I'm about to apply terraform" or "I'm about to ship a release." Bundles match that.

### Walkthrough 1: Morning baseline

```bash
broker shell --bundle dpg-ops-readonly --as claude-dpg-ops
```

What happens:
1. Broker assigns sandbox ID `claude-dpg-ops`. Creates `~/.config/broker/sandboxes/claude-dpg-ops/`.
2. Broker asks fnox to materialize the bundle. fnox runs command-lease → granted unlocks SSO (TouchID #1 of the day, covers 8h) → returns STS for `dpg-ps-ops-ro`. fnox unlocks keychain item for `gh-readonly` (TouchID may or may not prompt depending on keychain ACL — see Friction section).
3. Broker writes results to sandbox mount:
   - `~/.config/broker/sandboxes/claude-dpg-ops/aws-credentials` (single profile `dpg-ps-ops-ro`)
   - `~/.config/broker/sandboxes/claude-dpg-ops/secrets/gh_readonly`
4. Spawns shell (or container, or nono — `--type` selects) with:
   - `SANDBOX_ID=claude-dpg-ops`
   - `AWS_SHARED_CREDENTIALS_FILE=~/.aws/credentials` (mounted from sandbox/aws-credentials)
   - Broker CLI on PATH inside

Prompt count: **1 TouchID** (granted SSO unlock). Subsequent shells with the same bundle reuse the granted SSO session — no prompt.

### Walkthrough 2: Elevation mid-work

Agent or human inside sandbox:

```bash
broker request tf-apply --workspace dpg-ps-ops --duration 15m --reason "apply VPC change"
```

What happens:

1. **Sandbox writes** `~/.broker/requests/<ts>-tf-apply.json`:
   ```json
   {
     "bundle": "tf-apply",
     "workspace": "dpg-ps-ops",
     "duration": "15m",
     "reason": "apply VPC change",
     "requested_at": "2026-06-29T15:23:00Z"
   }
   ```
2. **Sandbox CLI polls** `~/.broker/responses/<ts>-tf-apply.json` (timeout 60s).
3. **Host daemon (fsnotify)** sees the request. Validates: bundle exists, workspace matches sandbox config, duration ≤ max.
4. **Host shows macOS notification + dialog:**
   ```
   Sandbox claude-dpg-ops requests bundle "tf-apply" for 15min.

   Components:
     - AWS dpg-ps-ops-ad (admin)
     - GH push PAT

   Reason: apply VPC change

   [ Approve ]   [ Deny ]
   ```
5. **User clicks Approve. TouchID prompt** — single gesture.
6. **Broker (now authorized) asks fnox** to materialize the elevation bundle:
   - fnox runs command-lease for `dpg-ps-ops-ad` → granted (SSO already unlocked from earlier → no prompt) → returns admin STS
   - fnox unlocks `gh-push` from keychain (may prompt if first access, or cache hit if accessed before in same fnox session)
7. **Broker writes** updated credentials to sandbox mount:
   - Appends `dpg-ps-ops-ad` profile entry to `aws-credentials`
   - Writes `secrets/gh_push`
   - Writes response file with success + expiry timestamp
8. **Sandbox CLI returns** to caller: `Elevated 15m. AWS_PROFILE=dpg-ps-ops-ad available. GH_TOKEN updated.`
9. **Prompt (starship/OMP)** picks up new env, shows red `ELEVATED 14:59` countdown.
10. **Auto-expire** at TTL: broker daemon removes admin profile from `aws-credentials` and `gh_push` from secrets. Prompt drops badge.

Prompt count: **1 TouchID** for approval (granted/fnox both already unlocked).

### Walkthrough 3: LLM agent requesting via MCP

Agent talks MCP to broker (not directly to fnox):

```
agent → broker MCP: request_bundle(name="tf-apply", workspace="dpg-ps-ops", duration="15m", reason="apply X")
broker MCP → host daemon: relay request via filesystem
host daemon: show approval prompt
user: approve (TouchID)
host daemon: mint via fnox/granted, write to sandbox mount, write response
broker MCP → agent: bundle delivered, expires in 15m
agent: uses creds via AWS SDK / inserts GH_TOKEN where needed
```

UX is identical to the human flow. The agent just speaks MCP instead of CLI.

### Walkthrough 4: Voluntary revoke / extend

```bash
broker revoke              # drops current elevation, back to baseline
broker extend 10m          # request +10min (approval prompt again)
broker status              # show current bundle, TTL, audit summary
```

## Friction accounting

| Action | TouchID prompts |
|--------|-----------------|
| Morning: spawn first sandbox of the day | 1 (granted SSO unlock — 8h coverage) |
| Spawn another sandbox same day | 0 (granted SSO cached) |
| Switch role in active sandbox (sw command — non-elevation) | 0 (just env var change) |
| Default-bundle keychain secret first access | 0-1 (depends on keychain ACL — see below) |
| Elevation request approval | 1 (the gesture itself) |
| Subsequent access to same elevated secret within bundle TTL | 0 (cached) |
| Routine agent work with default bundle | 0 (creds already present) |

**Total typical day:** 1-3 TouchID gestures. The mental cost is: morning unlock + one click per elevation.

### Where TouchID actually triggers (the mechanism)

Three independent sources of TouchID prompts in this flow:

1. **Approval dialog** (broker daemon decision) — designed to require TouchID as the "Approve" gesture, via macOS `LocalAuthentication`. One prompt, intentional, this IS the security gesture.

2. **granted reading encrypted SSO session** — granted decrypts SSO data from its keychain item on first use. Cached in granted's process for ~8h. One prompt per day, not per STS mint.

3. **fnox reading a keychain-stored secret** — depends on the per-item ACL set when fnox stored it. This is where bundle materialization either consolidates or fragments.

### Keychain ACL choice per item

Each fnox-managed secret in Keychain has an ACL. Two relevant modes:

| ACL mode | fnox reads it | Security shape |
|----------|---------------|----------------|
| **"Always Allow" for fnox binary** | Silent, no prompt | Protection at fnox-binary layer + broker approval gate. Mirror of how `bw`, `op`, `gpg-agent` work. |
| **"Require User Presence"** (TouchID per access) | TouchID prompt every read | Defense-in-depth: hardware biometric required regardless of caller. More friction. |

### Mapping ACL choice to bundle role

| Bundle role | Recommended ACL | Why |
|-------------|-----------------|-----|
| Baseline bundles (RO PAT, JIRA, default scoped tokens) | "Always Allow" for fnox | Routine, low-sensitivity, silent steady state |
| Elevation bundles (admin AWS, push PATs, release tokens) | "Always Allow" for fnox (default) | Approval gate provides the security gesture; per-item TouchID would add prompts without much marginal security |
| High-sensitivity exceptions (e.g., production data export) | "Require User Presence" | When per-item biometric is genuinely worth the friction |

### What "1 TouchID per elevation" requires

Assuming:
1. Approval dialog uses TouchID gate → 1 prompt
2. fnox binary has "Always Allow" ACL on the bundle's components → 0 prompts
3. granted's SSO session is already cached from morning → 0 prompts

Total: **1 TouchID per elevation, regardless of bundle component count.**

If keychain items use "Require User Presence" instead:

1. Approval dialog: 1 prompt
2. fnox unlocks each component: 1 prompt per secret

Total: **1 + N TouchID prompts**, with N = number of fnox-managed components in the bundle.

### The honest tradeoff

The "Always Allow for fnox" design treats the **broker approval dialog** as the security gesture, with **fnox as the trusted broker binary**. Threat protection comes from:
- Broker daemon owns approval — won't materialize bundle without TouchID-gated dialog
- fnox is invoked by broker (controlled path), not by arbitrary shell processes during elevation
- Even a compromised sandbox can't read fnox secrets directly — it would need to invoke fnox, which would only release elevated components after broker approves a fresh elevation request

This is roughly the same security shape as standard password-manager CLI agents (op, bw, gpg-agent). Convenient and acceptable for laptop-scoped use.

Per-item TouchID is available for the rare cases where you want hardware confirmation on every single access. Used selectively per bundle/secret, not as default.

## Architecture

```
 ┌─────────────────────────────────────────────────────────────┐
 │ Host                                                          │
 │                                                              │
 │  granted    encrypted SSO session, TouchID-gated             │
 │     ▲                                                        │
 │     │ invoked by                                             │
 │  fnox       command-lease backend → granted-bridge.sh        │
 │             keychain backend for non-AWS secrets             │
 │             MCP server (per-sandbox config / allowlist)      │
 │     ▲                                                        │
 │     │ invoked by                                             │
 │  broker-daemon (Go, launchd)                                 │
 │     - fsnotify on ~/.config/broker/sandboxes/*/requests/     │
 │     - shows macOS dialog/notification with bundle details    │
 │     - on approve: asks fnox to materialize bundle components │
 │     - writes results to sandbox mount + response file        │
 │     - audit log per request                                  │
 │     - TTL tracker: auto-revoke on expiry                     │
 │                                                              │
 │  broker (Go CLI)                                             │
 │     shell  --bundle <baseline> --as <id> [--type host|nono|  │
 │                                            devcontainer]     │
 │     status                                                   │
 │     revoke <id>                                              │
 │     list                                                     │
 │     bundles                                                  │
 │                                                              │
 │  broker-tray (Go, optional, getlantern/systray)              │
 │     - active sandboxes + elevations + countdowns             │
 │     - quick revoke / approve from menu                       │
 └─────────────────────────────────────────────────────────────┘
                              ▲
                              │ bind mount per-sandbox dirs
                              ▼
 ┌─────────────────────────────────────────────────────────────┐
 │ Sandbox                                                       │
 │  SANDBOX_ID=claude-dpg-ops                                   │
 │  AWS_SHARED_CREDENTIALS_FILE=~/.aws/credentials (mounted)    │
 │  ~/.broker/                                                  │
 │    requests/     (write)                                     │
 │    responses/    (read)                                      │
 │    secrets/      (read)                                      │
 │                                                              │
 │  broker request <bundle> [--workspace X] [--duration T]      │
 │                          [--reason "..."]                    │
 │  broker revoke                                               │
 │  broker status                                               │
 │                                                              │
 │  broker-mcp  (for agents: same protocol as CLI over MCP)     │
 └─────────────────────────────────────────────────────────────┘
```

## Components

### `broker` (host + sandbox CLI, single binary)

Subcommands:
- `broker shell --bundle <b> --as <id> [--type ...] [--workspace ...]` — host
- `broker request <bundle> [opts]` — sandbox
- `broker revoke [id]` — both
- `broker extend <dur>` — sandbox
- `broker status` — both
- `broker list` — host (list sandboxes)
- `broker bundles` — list available bundles
- `broker daemon start|stop|status` — host (manages launchd)

Detects context via `SANDBOX_ID` env var: present → sandbox mode, absent → host mode.

### `broker-daemon` (host, launchd)

- Watches `~/.config/broker/sandboxes/*/requests/`
- Single Go binary, ~500 LOC estimate
- Config: `~/.config/broker/config.toml` (default approval timeout, log retention) + `~/.config/broker/bundles.toml`

### `broker-mcp` (sandbox, for agents)

- Implements MCP tools: `request_bundle`, `revoke`, `status`
- Same logic as CLI; just MCP wrapping

### `granted-bridge.sh` (host)

- Tiny shell wrapper called by fnox command-lease
- Translates granted's `credential_process` JSON → fnox's expected `{credentials, expires_at}`
- ~15 lines

### `broker-tray` (host, optional v2)

- Menu bar app
- Go + `getlantern/systray`

## Phased delivery

### Phase 0: Spike with shell scripts

Build the whole flow in shell first:
- `broker-request.sh` writes request JSON
- `broker-daemon.sh` polls with `fswatch`, prompts via `osascript`, runs `fnox lease create` or `granted assume`, writes results
- One bundle hardcoded
- Validates UX and the fnox-bridge pattern before any Go

### Phase 1: Go reimplementation

- `broker` host CLI + daemon
- `broker request` sandbox CLI
- launchd plist
- Config-driven bundles
- Audit log
- Single sandbox type: host shell

### Phase 2: Sandbox types

- `--type devcontainer` (devcontainer feature that mounts the broker dirs and installs `broker`)
- `--type nono` (extends nono profile with mounts)
- `--type devpod` (devpod provider config)

### Phase 3: MCP

- `broker-mcp` sandbox-side server
- Devcontainer feature installs it as a Claude Code MCP server

### Phase 4: Tray app

### Phase 5: Open source

## Bundle authoring as the long-term value

Bundles are the human-facing primitive. A good bundle catalog is what makes this useful day-to-day. Examples:

- `default-readonly` — baseline for most sandboxes (RO AWS + RO PAT)
- `tf-apply` — workspace-AD + push PAT (workspace param required)
- `release` — narrow push PAT for releases
- `incident` — broad cross-account RO + escalation hints
- `data-export` — specific data role + short TTL
- `pr-review` — RO + GH read PAT (no AWS)

These are reusable, shareable patterns. A team could converge on a shared bundle catalog.

## Open questions

- **Naming**: candidates: `sandgate`, `passport`, `keep`, `gatekeep`, `permit`. Decide in Phase 1.
- **Bundle granularity**: are bundles defined globally, or per-sandbox? Probably both — global catalog + per-sandbox allowlist.
- **Workspace param**: how does the sandbox know which workspace it's "in" for `${workspace}` template expansion? Via the spawn-time `--bundle baseline-dpg-ops` declaring it, or via `WS_*` env vars from `sw()`.
- **Multi-host**: out of scope v1. v2: relay request to phone via a small webhook.
- **Audit log format**: JSONL.
- **Upstream fnox vs. broker**: should bundle-with-approval-flow live in fnox itself? Worth a discussion with jdx. Broker can be lighter if some of this goes upstream.
- **Reason field**: free text, or structured (link to JIRA ticket etc.)? Free text v1.
- **What about non-AWS cloud (GCP, Azure)?** Granted supports GCP; bundles can include GCP profiles. Keep architecture cloud-agnostic.

## Day-in-the-life summary

Morning:
- `broker shell --bundle dpg-ops-readonly --as me` (1 TouchID for granted SSO)
- Work in shell. Run kubectl, gh, aws — all read-only. No prompts.

Mid-morning:
- Need to fix a thing. Inside shell: `broker request tf-apply --workspace dpg-ps-ops --reason "..."`
- macOS notification. Click Approve. TouchID. (2nd of the day.)
- Prompt shows red ELEVATED 14:58 countdown.
- Apply. Done in 5min. `broker revoke` (or just wait).
- Prompt drops back to baseline.

Afternoon:
- Spawn an agent for some chore: `broker shell --bundle dpg-ops-readonly --as claude-chore --type nono`
- Agent runs, reads logs, suggests fixes. No prompts.
- Agent decides it wants to push: requests via MCP. Notification. TouchID. (3rd of the day.)
- Agent does its thing, push happens, creds revoke at TTL.

End of day: maybe 3 TouchID gestures, lots of work, zero unexplained credential exposure.

## What this is NOT

- Not a replacement for proper IAM/Identity Center hygiene at org level
- Not a substitute for org-wide JIT platforms in companies that need centralized control
- Not a way to evade audit — local audit log is for your own records
- Not a way to bypass your org's session policies — credentials inherit whatever AWS hands out
