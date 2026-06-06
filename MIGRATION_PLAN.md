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

**Migration path:** Old GitHub repo will be renamed to `dotfiles-archive`. The Codeberg repo becomes the canonical dotfiles source. GitHub auto-redirects the old name temporarily, but nothing should depend on it long-term.

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

**Goal:** Bring all dotfiles under declarative management in the new chezmoi repo. No behavioral change — same files, same locations, just managed by chezmoi instead of manual symlinks/includes.

**What chezmoi replaces:** The manual setup where `~/.gitconfig` has `[include] path = dotfiles/common/.gitconfig`, `ZSH_CUSTOM` points to `~/dotfiles/zsh/`, and Ghostty config uses `config-file` to include from dotfiles.

**Current state:** chezmoi initialized, empty repo at `~/.local/share/chezmoi/` with remote on Codeberg.

**Steps:**
1. `chezmoi add` each managed file: `.zshrc`, `.gitconfig`, `.config/ghostty/config`, `.config/nono/profiles/*.json`, oh-my-posh themes, zsh custom dir
2. Set up `.chezmoi.toml.tmpl` with OS detection for Mac vs Linux divergences (Homebrew prefix, Zscaler bundle path, pnpm path)
3. Template the files that differ per-platform (currently only a few: PATH entries, Zscaler bundle)
4. Verify: `chezmoi diff` shows no drift, `chezmoi apply -n` is a no-op on current machine
5. Commit and push to Codeberg

**Key decision — what goes where:**
- chezmoi manages files that land in `$HOME` (`.zshrc`, `.gitconfig`, `.config/*`)
- The zsh custom scripts (`00-scripts.zsh`, `10-aws_scripts.zsh`, etc.) currently live in `~/dotfiles/zsh/` and are sourced via `ZSH_CUSTOM`. These should move into chezmoi so they deploy to a chezmoi-managed location (e.g., `~/.config/zsh-custom/` or keep `~/dotfiles/zsh/` but managed by chezmoi)

**What stays outside chezmoi:**
- `~/workspaces/` tree (its own repos + workspace-specific state)
- `~/dotfiles/archive/` (historical reference, stays in old repo)

**Fallback:** `chezmoi purge` removes chezmoi management; old `~/dotfiles/` setup still works.

**Files in chezmoi source (`~/.local/share/chezmoi/`):**
- `.chezmoi.toml.tmpl` — chezmoi data/config with OS detection
- `.chezmoiignore` — exclude patterns
- `dot_zshrc` (or `dot_zshrc.tmpl` if templated)
- `dot_gitconfig`
- `dot_config/ghostty/config`
- `dot_config/nono/profiles/` — nono sandbox profiles
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

| Actor | AWS admin | AWS read-only | GH token | Keychain |
|-------|-----------|---------------|----------|----------|
| Interactive shell (default) | No | via sw() + fnox | via fnox get | Yes |
| Interactive shell (elevated) | via sw-admin (TTL) | Yes | via fnox get | Yes |
| Claude Code | Never | via fnox MCP (5m TTL) | via fnox MCP (scoped PAT) | Never |
| npm/pip install | Never | Never | Never | Never |

## Phase 7: DevContainers (Future)

**Goal:** Full dev environment isolation. Credential injection scoped per container.

**Deferred until Phases 1-6 are stable.** Key design points:
- Base devcontainer includes mise + fnox + chezmoi
- `chezmoi init --apply` in `postCreateCommand` deploys dotfiles
- Credentials come from fnox MCP on host, exposed via socket
- Container never sees SSO tokens, keychain, or host SSH keys
- Zscaler CA bundle mounted read-only from host
- starship prompt shows sandbox indicator (detects `/.dockerenv` or `DEVCONTAINER`)

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
