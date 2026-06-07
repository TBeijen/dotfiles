# Dotfiles & Toolchain Migration Plan

## Context

**Primary driver: security.** Supply chain attacks and LLM agent unpredictability make it a priority to isolate credentials from CLI tools (claude, copilot, npm, gh). The current setup has no credential isolation — `aws sso login` tokens, keychain-stored SSO creds, and secrets in `~/.env` are accessible to every child process.

**Secondary goals:** Reproducible host setup (Mac + Linux), declarative tool versioning, per-project toolchains shareable with team, and eventually devcontainer-based development.

**Key constraint:** Step-by-step implementation. Each phase must be independently useful, and the current setup must remain as a fallback. No big-bang migration.

## Repos

| Repo | Location | Remote | Purpose |
|------|----------|--------|---------|
| **New dotfiles** (chezmoi) | `~/.local/share/chezmoi/` | `codeberg.org/TBeijen/dotfiles` | All new dotfile management |
| **Old dotfiles** | `~/dotfiles/` | `github.com/TBeijen/dotfiles` | Current setup, becomes archive |
| **Ansible playbook** | `~/ansible-osx/` | `github.com/TBeijen/ansible-osx` | Current macOS bootstrap, absorbed by chezmoi+mise |
| **SSH config** | `~/ssh_config/` | `codeberg.org/TBeijen/ssh_config` | SSH config, fold into chezmoi |

**Migration path:** Old GitHub dotfiles repo will be renamed to `dotfiles-archive`. The Codeberg repo becomes the canonical dotfiles source. The Ansible playbook and SSH config repos are absorbed into chezmoi and archived.

## Tools

| Tool | Purpose | Status |
|------|---------|--------|
| **chezmoi** | Dotfile management, templating, cross-platform | Installed (v2.70.5), repo initialized on Codeberg |
| **mise** | Tool version management, environments, task runner | Not installed |
| **fnox** | Credential/secrets management (by mise author) | Not installed |
| **starship** | Prompt engine (replacing oh-my-posh) | Not installed |
| **nono** | Process-level sandbox for LLM tools | In use for Claude Code |
| **devcontainers/devpod** | Full dev environment isolation | Future phase |

## Phase 0: Preserve Fallback

**Goal:** Ensure the current setup is always one toggle away.

1. Create a git branch `pre-migration` on the old `~/dotfiles` repo as a snapshot
2. Each subsequent phase wraps changes in feature flags — e.g., `if command -v mise &>/dev/null` guards — so falling back means just uninstalling a tool, not reverting files
3. The old `~/dotfiles/` directory stays in place throughout migration — chezmoi sources from `~/.local/share/chezmoi/`, not from `~/dotfiles/`

## Phase 1: chezmoi — Dotfile Management

**Goal:** Bring all dotfiles under declarative management in the new chezmoi repo. No behavioral change — same files, same locations, just managed by chezmoi instead of manual symlinks/includes. Also absorb the Ansible playbook's bootstrap responsibilities.

**What chezmoi replaces:**
- The manual symlink setup (`~/.zshrc` -> `~/dotfiles/common/.zshrc`, `~/.ssh/config` -> `~/ssh_config/config`)
- The `[include]` directive in `~/.gitconfig`
- The Ansible playbook (`~/ansible-osx/`) for macOS bootstrap

**Current state:** chezmoi initialized, empty repo at `~/.local/share/chezmoi/` with remote on Codeberg.

### chezmoi multi-machine model

chezmoi uses a data + template system to distinguish machine types. On first `chezmoi init`, it prompts for machine type and stores the answer:

```toml
# .chezmoi.toml.tmpl
{{- $machine_type := promptChoiceOnce . "machine_type" "Machine type" (list "workstation" "devcontainer" "server") }}

[data]
  machine_type = {{ $machine_type | quote }}
  is_corporate = true
```

Then `.chezmoiignore` (templated) gates what gets deployed:

```
{{ if ne .machine_type "workstation" }}
Brewfile
run_once_*-brew*.sh
run_once_*-macos-defaults.sh
run_once_*-omz.sh
private_dot_ssh/
{{ end }}

{{ if ne .chezmoi.os "darwin" }}
run_once_*-macos-defaults.sh
{{ end }}
```

| Layer | Examples | Deployed where |
|-------|----------|----------------|
| **Universal dotfiles** | `.zshrc`, `.gitconfig`, `starship.toml`, mise config | Everywhere |
| **Host bootstrap** | Brewfile, `run_once` scripts, macOS defaults, GPG config | `machine_type == "workstation"` only |
| **Platform-specific** | Homebrew paths, Zscaler bundle, pnpm path | Gated by `{{ .chezmoi.os }}` |

### Absorbing the Ansible playbook

The Ansible playbook (`~/ansible-osx/osx.yaml`) does 6 things. Here's how each maps to chezmoi + mise:

| Ansible playbook | chezmoi + mise equivalent |
|---|---|
| **`osx_brew.yaml`** — installs ~80 brew packages + ~20 casks | **Brewfile** (chezmoi-managed) + `run_once_install-brew-packages.sh` that runs `brew bundle`. Tools that mise manages (node, python, terraform, kubectl, helm) are removed from Brewfile — mise handles them |
| **`osx_defaults.yaml`** — Finder hidden files, screenshot dir, DS_Store | **`run_once_setup-macos-defaults.sh`** — same `defaults write` commands |
| **`osx_omz.yaml`** — installs oh-my-zsh | **`run_once_install-omz.sh`** — curls the installer if `~/.oh-my-zsh` missing |
| **`osx_configure_gnupg.yaml`** — creates `~/.gnupg/`, templates `gpg.conf` + `gpg-agent.conf` | **No longer needed for git signing** — SSH signing replaces GPG. GPG config only needed if GPG is used for other purposes (encryption, etc.) |
| **`osx_config_repos.yaml`** — clones dotfiles, ssh_config, workspaces repos + creates symlinks | **`chezmoi init --apply`** replaces dotfiles clone. SSH config folded into chezmoi as `private_dot_ssh/`. Workspaces clone in `run_once_setup-workspaces.sh` |
| **`osx_misc.yaml`** — creates `~/Documents/Screenshots`, nvm dir, autoenv symlink | **`run_once` script** or chezmoi `create_` entries for dirs. autoenv symlink may not be needed if mise environments replace autoenv |

### Git commit signing: SSH signing (replacing GPG)

**Decision: switch to SSH signing everywhere** (host + devcontainers). GPG signing is dropped.

Why SSH signing wins:
- Git 2.34+ supports `gpg.format = ssh` — signs commits with SSH keys
- GitHub and Codeberg both support SSH signing keys
- No GPG daemon, no pinentry, no socket path issues — works identically on Mac and Linux
- Config is 3 lines in `.gitconfig` (chezmoi deploys everywhere)
- Enables clean signing-only key separation for devcontainers (see Phase 6)
- **Key rotation/revocation is safe**: GitHub records verification status at the time of verification, so revoking or rotating a signing key does not retroactively invalidate past commits ([GitHub docs: about commit signature verification](https://docs.github.com/en/authentication/managing-commit-signature-verification/about-commit-signature-verification))

This eliminates the GPG setup from the Ansible playbook entirely (`osx_configure_gnupg.yaml`, `gpg.conf.tmpl`, `gpg-agent.conf.tmpl`, pinentry-mac config). If GPG is still needed for non-git purposes (e.g., encrypting files), it can be set up separately.

### Steps

1. `chezmoi add` each managed file (follows symlinks, captures actual content):
   - `.zshrc`, `.gitconfig`, `.config/ghostty/config`
   - `.config/nono/profiles/*.json`
   - `.ssh/config` (from ssh_config repo)
   - zsh custom scripts, oh-my-posh themes
2. Set up `.chezmoi.toml.tmpl` with OS detection + machine type prompt
3. Create `.chezmoiignore` to gate host-only content
4. Create `Brewfile` from Ansible's brew package lists (minus mise-managed tools)
5. Create `run_once` scripts for bootstrap tasks (brew bundle, oh-my-zsh, macOS defaults, workspaces clone)
6. Template files that differ per-platform (PATH entries, Zscaler bundle path)
7. Generate SSH signing key (`ssh-keygen -t ed25519 -f ~/.ssh/id_signing`), register on GitHub/Codeberg as Signing Key only
8. Verify: `chezmoi diff` shows no drift, `chezmoi apply -n` is a no-op
9. Commit and push to Codeberg

**What stays outside chezmoi:**
- `~/workspaces/` tree (its own repos + workspace-specific state)
- `~/dotfiles/archive/` (historical reference, stays in old repo)

**Fallback:** `chezmoi purge` removes chezmoi management; old `~/dotfiles/` + Ansible setup still works.

**Files in chezmoi source (`~/.local/share/chezmoi/`):**
- `.chezmoi.toml.tmpl` — machine type, OS detection, corporate flag
- `.chezmoiignore` — conditional exclusions per machine type / OS
- `dot_zshrc.tmpl` — templated for platform differences
- `dot_gitconfig` — with signing config
- `private_dot_ssh/config` — absorbed from ssh_config repo
- `dot_config/ghostty/config`
- `dot_config/nono/profiles/` — nono sandbox profiles
- `dot_config/mise/config.toml` — global mise config (added in Phase 2)
- `Brewfile` — brew packages + casks (workstation only)
- `run_once_*.sh` — bootstrap scripts (conditional per machine type)
- Zsh custom scripts (structure TBD during implementation)

## Phase 2: mise — Tool Version Management

**Goal:** Replace nvm and pyenv with mise. Declarative, pinned tool versions. Near-zero shell startup cost.

**What mise replaces:**
- nvm lazy-load stubs (`zsh/99-zshrc.zsh` lines 53-62) — mise handles Node.js natively (~5ms init vs the lazy-load complexity)
- pyenv cached init (`zsh/99-zshrc.zsh` lines 15-30) — mise handles Python natively, no daily cache hack
- Ad-hoc Homebrew tool installs (terraform, kubectl, helm, etc.) — mise pins versions

**Steps:**
1. Install mise via Homebrew
2. Create `~/.config/mise/config.toml` with global tool defaults (node, python versions matching current nvm/pyenv)
3. Add `eval "$(mise activate zsh)"` to the zsh init, guarded by `command -v mise`
4. Verify node/python work via mise, then comment out (don't delete) the nvm lazy-load and pyenv cache blocks
5. Add per-project `.mise.toml` to one project repo as a trial — pin node, python, terraform versions
6. Add `~/.config/mise/config.toml` to chezmoi

**Startup time impact:** Removes ~650ms pyenv cache + nvm lazy-load complexity. mise activation adds ~5ms.

**Fallback:** Uncomment nvm/pyenv blocks, remove mise activation line. Original tools remain installed.

## Phase 3: starship — Prompt Engine

**Goal:** Replace oh-my-posh with starship. Run side-by-side initially — toggle via env var or terminal.

**What to preserve from oh-my-posh config (`tbnl-default.json`):**
- Status icon (checkmark/cross)
- Time display
- AWS profile indicator (orange, hidden when default)
- kubectl context + namespace (k8s blue)
- Python virtualenv, Node version
- Path display
- Git branch + dirty/clean status with color-coded ahead/behind
- Production warning (triple `!` when cluster/profile matches `prod` but not `non-prod`)

**What to add (new):**
- **Sandbox indicator** — detect when inside a devcontainer or nono sandbox (check for `DEVCONTAINER=true`, `NONO_PROFILE`, or `/.dockerenv`) and show a shield/lock icon
- **Credential elevation indicator** — when admin credentials are active (via fnox), show a warning segment

**Steps:**
1. Install starship via Homebrew (or mise: `mise use -g starship`)
2. Create `~/.config/starship.toml` (chezmoi-managed) translating the oh-my-posh segments
3. Add starship init behind a toggle: `USE_STARSHIP=true` env var, defaulting to oh-my-posh
4. Test side-by-side in different terminal tabs
5. Once satisfied, make starship the default and keep oh-my-posh config as archive

**Sandbox indicator approach (starship custom command):**
```toml
[custom.sandbox]
command = "echo sandbox"
when = '[ -n "$NONO_PROFILE" ] || [ -n "$DEVCONTAINER" ] || [ -f /.dockerenv ]'
format = "[$symbol$output]($style) "
symbol = " "
style = "bold green"
```

**Fallback:** Set `USE_STARSHIP=false`. oh-my-posh config untouched in old dotfiles.

## Phase 4: fnox — Credential Management

**Goal:** Move secrets out of the shell environment. Establish the credential model that LLM sandboxing builds on. This is the core security phase.

**What fnox replaces:**
- `~/.env` file sourced at shell start — secrets like `DPG_AKAMAI_UNHIDE` move to fnox with `env = false`
- `aws_set_profile()`, `aws_login()`, `aws_mfa()`, `aws_sso_to_iam()` — fnox AWS STS backend handles credential acquisition
- nono's `apple-password://` broker for `GH_TOKEN` — fnox becomes the single credential broker

**What fnox does NOT replace (keep these):**
- `aws_ecr_login()`, `aws-logins()`, `aws_ec2_find()`, `aws_eks_kubeconfig()`, `aws_asg_*()` — operational tools that consume credentials
- `kube_*` functions — operational k8s utilities
- `zscaler_bundle_on/off` — CA bundle management (not a secret)

**Steps:**
1. Install fnox via mise (`mise use -g fnox`)
2. Create `~/.config/fnox/fnox.toml` with initial secret definitions:
   - `GH_TOKEN` (backend: bitwarden, `env = false`)
   - `DPG_AKAMAI_UNHIDE` (backend: bitwarden, `env = false`)
3. Refactor the Akamai curl shortcuts (`CUAD`/`CUADF`) to call `fnox get` on demand instead of baking the secret into exported arrays at shell start
4. Remove the `~/.env` sourcing
5. Set up fnox AWS STS leases for one trial workspace (e.g., `tbnl/dev-ro`):
   - Create `fnox.toml` in the workspace directory
   - Configure AWS STS backend pointing to the SSO profile
   - Verify `fnox exec -- aws sts get-caller-identity` returns the expected role
6. Gradually migrate remaining workspaces

**fnox + Bitwarden:**
- fnox supports Bitwarden as a backend natively
- Store GH PAT, Akamai token in a dedicated Bitwarden folder
- Secrets are fetched on demand, never written to disk as plaintext
- Portable across machines (unlike keychain)

**GitHub PATs for fnox (preparation for Phases 6+7):**
Create fine-grained PATs on GitHub scoped narrowly:
- **claude-readonly**: `contents: read`, `metadata: read` on specific repos — for LLM agents
- **claude-push**: `contents: write`, `metadata: read` on specific repos — for LLM push (no admin, no branch protection bypass)
- **interactive**: broader scope for interactive shell use (or keep using SSH auth key on host)

Store all PATs in Bitwarden, inject via fnox. Each PAT maps to a fnox secret with appropriate `env` setting.

**Fallback:** Re-add `~/.env` sourcing, revert curl shortcuts. fnox secrets stay in Bitwarden regardless.

## Phase 5: Evolve sw() — Workspace Orchestration

**Goal:** Wire mise + fnox into `sw()`. Keep current workspace directory structure and UX. `sw <project> <env> [<cluster>]` works as before, but credentials come from fnox instead of `.envrc` + `AWS_PROFILE`.

**Approach:** Keep existing directories (`tbnl/dev-ro`, `dpg/ps-ops-do`, etc.). Add `fnox.toml` alongside existing `.envrc`. New `sw()` prefers fnox when available, falls back to autoenv when not.

**Coexistence pattern per workspace:**
```
~/workspaces/tbnl/dev-ro/
  .envrc              # existing — fallback
  .envrc.leave        # existing — fallback
  .mise.toml          # new — tool versions (optional)
  fnox.toml           # new — credential definition
  .kube/
    d -> ...          # unchanged
```

**Steps:**
1. Add `fnox.toml` to one trial workspace
2. Modify `sw()`: check for `fnox.toml` and activate credentials, else fall back to autoenv
3. Add `sw-admin` companion for credential elevation:
   - Spawns a subshell with admin-level fnox profile
   - TTL-bounded (e.g., 15 min default)
   - starship prompt shows elevation warning
4. Migrate workspaces one by one

**Fallback:** Remove fnox checks from `sw()`. autoenv `.envrc` files work as before.

## Phase 6: Harden LLM Sandboxing — nono + fnox MCP

**Goal:** LLM agents get scoped, read-only credentials via fnox MCP server. Defense in depth.

**Current nono setup (already good):**
- `claude-code-no-keychain.json`: denies keychain, allows claude-specific paths
- `claude-code-tb.json`: extends above, adds `deny_credentials` + `deny_keychains_macos`, brokers `GH_TOKEN` via Apple Passwords

**Changes:**
1. Replace nono `apple-password://` broker with fnox MCP server — single credential broker
2. Configure fnox MCP as Claude Code MCP server with read-only profile:
   - Only exposes read-only AWS credentials (5m TTL)
   - Only exposes scoped GH_TOKEN (read-only PAT)
   - Admin credentials are `env = false` — invisible even via MCP
3. Add fnox config paths to nono filesystem allowlist

**Credential access matrix:**

| Actor | AWS admin | AWS read-only | GH push | GH read | Git signing | Keychain |
|-------|-----------|---------------|---------|---------|-------------|----------|
| Interactive shell (default) | No | via sw() + fnox | SSH auth key | SSH auth key | SSH signing key | Yes |
| Interactive shell (elevated) | via sw-admin (TTL) | Yes | SSH auth key | SSH auth key | SSH signing key | Yes |
| Claude Code (host/nono) | Never | via fnox MCP (5m TTL) | scoped PAT via fnox | scoped PAT via fnox | signing key (file) | Never |
| Claude Code (devcontainer) | Never | via fnox MCP (5m TTL) | scoped PAT via fnox | scoped PAT via fnox | signing key (mounted file) | Never |
| npm/pip install | Never | Never | Never | Never | Never | Never |

### SSH key separation for signing vs authentication

The host has two SSH keys with distinct GitHub registrations:

| Key | GitHub registration | Can authenticate? | Can sign commits? | Available in devcontainer? |
|-----|-------------------|-------------------|-------------------|---------------------------|
| `~/.ssh/id_ed25519` | **Authentication Key** | Yes (full identity) | No | **Never** — not forwarded, not mounted |
| `~/.ssh/id_signing` | **Signing Key only** | No | Yes | Yes — mounted as read-only file |

**No SSH agent forwarding into devcontainers.** Agent forwarding would expose the auth key. Instead:
- Signing: via `id_signing` private key file mounted read-only into the container
- Push/pull: via fine-grained PAT injected by fnox (scoped to specific repos, `contents: write` only, no admin/bypass permissions)

Even if the signing key file is compromised, it can only sign commits (claim authorship) — it cannot authenticate to GitHub for any action.

**Git config (chezmoi-managed, universal):**
```ini
[gpg]
  format = ssh
[user]
  signingkey = ~/.ssh/id_signing
[commit]
  gpgsign = true
```

On the host, this works with either the key file directly or via ssh-agent (if loaded). In devcontainers, it uses the mounted file.

### GitHub org hardening (complementary)

Recommend reviewing these org-level settings for defense in depth:
- **Branch protection: "Do not allow bypassing the above settings"** — prevents even admins from bypassing
- **Rulesets** (org-level) — enforce protections across all repos, more granular than branch protection
- **Require approval for fine-grained PATs** — org admin approves before PATs are active against org repos
- **Audit log alerts** — monitor force pushes, protection changes, PAT creation

## Phase 7: DevContainers (Future)

**Goal:** Full dev environment isolation. Credential injection scoped per container.

**Deferred until Phases 1-6 are stable.**

### Devcontainer scope and lifecycle

Devcontainers are **scoped per project folder**. Config lives in `.devcontainer/devcontainer.json` per project (or `.devcontainer/{name}/devcontainer.json` for multiple configs, e.g., monorepos).

**Rebuild frequency: rare.** You rebuild when Dockerfile or devcontainer.json changes. Day-to-day you keep working in the running container. What matters:

| Survives rebuild | Lost on rebuild |
|---|---|
| Source code (bind-mounted from host) | Container filesystem (apt installs, etc.) |
| Named volumes (zsh history, `~/.claude`, caches) | Anonymous container state |
| Anything in Dockerfile/features | Ad-hoc changes to running container |

Rule: if you need it after rebuild, it goes in the Dockerfile or on a named volume.

### Key design points
- Base devcontainer includes mise + fnox client + chezmoi
- `chezmoi init --apply` in `postCreateCommand` deploys dotfiles (machine_type=devcontainer)
- **Default credentials** (read-only) come from fnox MCP on host via forwarded socket — auto-refresh on expiry
- **Elevated credentials** require out-of-band approval on host — TTL-bounded, never permanent
- Container never sees SSO tokens, keychain, or host SSH keys
- Zscaler CA bundle mounted read-only from host
- starship prompt shows sandbox indicator + elevation warning when admin creds active

### Credential model in devcontainers

**No SSH agent forwarding.** `SSH_AUTH_SOCK` is explicitly cleared in devcontainer config. This prevents the host auth key (`id_ed25519`) from being accessible inside the container.

**Signing:** The signing-only key (`id_signing`) is bind-mounted read-only into the container. Git uses it directly as a file (not via agent). The key is registered on GitHub as a Signing Key only — it cannot authenticate.

**Push/pull:** Fine-grained PAT injected by fnox, used via git credential helper. Scoped to specific repos with `contents: write` only — no admin, no branch protection bypass.

```jsonc
// devcontainer.json — credential model
{
  "mounts": [
    // Signing key (read-only, cannot authenticate)
    "source=${localEnv:HOME}/.ssh/id_signing,target=/home/vscode/.ssh/id_signing,type=bind,readonly",
    "source=${localEnv:HOME}/.ssh/id_signing.pub,target=/home/vscode/.ssh/id_signing.pub,type=bind,readonly",
    // Zscaler CA bundle
    "source=${localEnv:HOME}/.zscaler/bundle_combined.pem,target=/etc/ssl/certs/zscaler-bundle.pem,type=bind,readonly"
  ],
  "remoteEnv": {
    "SSH_AUTH_SOCK": "",              // clear — no agent forwarding
    "PODMAN_USERNS": "keep-id",      // correct file ownership
    "SSL_CERT_FILE": "/etc/ssl/certs/zscaler-bundle.pem",
    "NODE_EXTRA_CA_CERTS": "/etc/ssl/certs/zscaler-bundle.pem"
  }
}
```

### Credential lifecycle in devcontainers

Devcontainer credentials are short-lived by design. Two flows need to work:

**1. Default credential refresh (automatic)**

Default credentials (read-only AWS, scoped GitHub PAT) are injected via fnox MCP server running on the host, exposed to the container via a forwarded Unix socket. When credentials expire, the container requests fresh ones from fnox MCP — fnox on the host uses the host's SSO session to obtain new STS credentials. This is transparent to the user.

```
Container                    Host
   |                          |
   |-- fnox MCP: get creds -->|
   |                          |-- aws sts assume-role (ro) -->  AWS
   |                          |<-- STS session (15m TTL) ------
   |<-- creds (15m TTL) ------|
   |                          |
   | ... 15 min later ...     |
   |                          |
   |-- fnox MCP: get creds -->|  (automatic refresh)
   |<-- fresh creds ----------|
```

If the host's SSO session itself expires, the user re-authenticates on the host (`aws sso login`). The container never touches SSO.

**2. Credential elevation (out-of-band approval)**

When you need admin/write access from inside the devcontainer (e.g., `terraform apply`, `kubectl delete`), you trigger elevation from the **host** — the container cannot self-elevate.

**Near-term approach (host-side script):**
```bash
# Run on HOST terminal — not inside the container
elevate tbnl dev 15m
```

This script:
1. Uses fnox on the host to obtain admin-role STS credentials (requires host SSO session)
2. Writes credentials to a shared volume mounted into the container (e.g., `/tmp/elevated-creds/`)
3. Credentials have a 15-minute TTL enforced by AWS STS
4. Inside the container, a helper sources the elevated creds: `source /tmp/elevated-creds/env`
5. After TTL expires, the credentials are invalid regardless of whether the file remains

**Target approach (fnox MCP with approval):**
fnox MCP server supports approval flows. The container (or an LLM agent) requests admin credentials via MCP. fnox on the host prompts for approval — e.g., a terminal prompt, Touch ID, or a notification. Only after explicit host-side approval does fnox issue the elevated credentials with a TTL.

```
Container                    Host
   |                          |
   |-- fnox MCP: elevate ---->|
   |                          |-- prompt: "Allow admin for tbnl/dev? [y/N]"
   |                          |<-- user approves
   |                          |-- aws sts assume-role (admin) --> AWS
   |<-- admin creds (15m) ----|
```

This keeps the security invariant: **the container cannot obtain elevated credentials without explicit human approval on the host.**

**Starship prompt integration:** When elevated credentials are active, the starship prompt shows a warning segment (e.g., red `ELEVATED` badge). When they expire, the badge disappears automatically.

### Podman-specific
- VSCode setting: `"dev.containers.dockerPath": "podman"`
- `"PODMAN_USERNS": "keep-id"` in `remoteEnv` for correct file ownership
- Increase default Podman machine memory beyond 2GB

## References

**chezmoi + mise + devcontainers:**
- [Reproducible Dev Environment: chezmoi, mise, devcontainers, omnictl](https://medium.com/@pedrotychang/my-reproducible-developer-environment-chezmoi-mise-devcontainers-omnictl-aa27740a0acf) — Shows how chezmoi bootstraps mise via `run_once` scripts, mise config layering (global/project/`MISE_ENV`), and starship prompt for container context. Chezmoi can download mise binary inside containers during image build.

**Podman + devcontainers:**
- [Running Dev Containers Locally with Podman](https://geekingoutpodcast.substack.com/p/running-dev-containers-locally-with) — VSCode setting `"dev.containers.dockerPath": "podman"`, `"PODMAN_USERNS": "keep-id"` in `remoteEnv` for correct file ownership. Default Podman machine memory (2GB) is too low — increase it.

**Persistence across devcontainer rebuilds:**
- [Persist Zsh History in Devcontainers](https://gavinest.com/posts/devcontainers-persist-zsh-history/) — Named volumes survive rebuilds. Key gotcha: chezmoi apply overwrites `.zshrc` modifications from Dockerfile — use `postCreateCommand` for fixups that must survive dotfile application.
- [Persist Claude Across Rebuilds](https://www.eke.li/vscode/2026/03/14/persist-claude-across-rebuilds.html) — Named volume + symlink pattern for `~/.claude/` and `~/.claude.json`. `postCreateCommand` recreates symlinks after each rebuild.

**Cross-cutting patterns for Phase 7:**
1. Lifecycle ordering: chezmoi apply first, then mise install, then fixup scripts
2. Named volumes for: zsh history, Claude auth, mise cache (`~/.local/share/mise`)
3. Podman-specific: `dockerPath`, `PODMAN_USERNS`, memory increase
4. `postCreateCommand` is the safe place for post-dotfiles fixups

## Verification at Each Phase

| Phase | How to verify |
|-------|---------------|
| 0 | `git log --oneline pre-migration` on old repo shows snapshot |
| 1 | `chezmoi diff` shows no drift; `chezmoi apply -n` is a no-op |
| 2 | `node --version` and `python --version` work via mise; shell startup < 1s |
| 3 | starship prompt shows all segments; toggle back to oh-my-posh works |
| 4 | `fnox get gh_token` works; `printenv \| grep AKAMAI` shows nothing; `fnox exec -- aws sts get-caller-identity` returns expected role |
| 5 | `sw tbnl dev-ro d` activates fnox credentials + sets KUBECONFIG; `sw-admin` warns and spawns TTL subshell |
| 6 | Inside nono: `printenv \| grep AWS` shows nothing; Claude can request read-only creds via MCP |
| 7 | In devcontainer: `aws sts get-caller-identity` returns read-only role; creds refresh after expiry; `elevate` on host injects admin creds that expire after TTL |

## Implementation Order & Dependencies

```
Phase 0 (snapshot)
  |
  +-- Phase 1 (chezmoi) ---- manages config files for all subsequent phases
  |     |
  |     +-- Phase 2 (mise) ---- tool management, prerequisite for fnox install
  |     |     |
  |     |     +-- Phase 4 (fnox) ---- credential management, core security layer
  |     |           |
  |     |           +-- Phase 5 (sw evolution) ---- wires mise + fnox into workspace switching
  |     |           |
  |     |           +-- Phase 6 (nono hardening) ---- LLM sandboxing with fnox MCP
  |     |                 |
  |     |                 +-- Phase 7 (devcontainers) ---- full isolation, deferred
  |     |
  |     +-- Phase 3 (starship) ---- independent, can run in parallel with Phase 2+
```
