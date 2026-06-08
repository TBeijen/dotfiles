# Dotfiles — Conventions & Quick Reference

## Machine types

Set during `chezmoi init`, stored in `~/.config/chezmoi/chezmoi.toml`:

| Type | Purpose | What's included |
|------|---------|-----------------|
| `workstation` | MacBook (work/personal) | Everything: brew packages, macOS defaults, SSH hosts, full tool config |
| `devcontainer` | Ephemeral dev environment | Dotfiles + tool config only. No brew, no macOS defaults, no personal SSH hosts |
| `server` | Remote Linux host | Minimal dotfiles |

Gating is done via `.chezmoiignore` (skip entire files) and `{{ if eq .machine_type "workstation" }}` blocks in templates (skip sections within files).

## Git config conventions

**Identity per org** — `.gitconfig` uses two mechanisms:

```ini
# Path-based: catches repos at clone time (git creates dir before fetching)
[includeIf "gitdir:~/projects/dpg/"]
  path = ~/.gitconfig-dpg

# Remote-based: works regardless of path (including devcontainers)
[includeIf "hasconfig:remote.*.url:git@github.com:DPGMedia/**"]
  path = ~/.gitconfig-dpg
```

Both can coexist — they don't conflict.

**SSH key isolation** — per-org gitconfigs set `core.sshCommand` with `IdentityAgent=none` and `IdentitiesOnly=yes` to force a specific key and prevent the SSH agent from offering other keys.

## Sensitive values

Secrets and host-specific values (IPs, ports) go in `.chezmoi.toml` (local, not committed), referenced in templates via `{{ .variable_name }}`. Values are prompted during `chezmoi init` on a new machine, conditional on machine type.

## Chezmoi day-to-day commands

```bash
# See what chezmoi would change
chezmoi diff

# Apply changes (with preview)
chezmoi apply -v

# Edit a managed file (opens the SOURCE, not the target)
chezmoi edit ~/.gitconfig

# Add a new file to chezmoi management
chezmoi add ~/.some/config

# Add a file and follow symlinks (get content, not the symlink)
chezmoi add --follow ~/.some/symlinked-file

# Make a file a template (enables {{ }} syntax)
chezmoi chattr +template ~/.gitconfig

# See all managed files
chezmoi managed

# Dry-run apply (preview only, no changes)
chezmoi apply -n -v

# Re-initialize on a new machine (prompts for machine type, secrets)
chezmoi init codeberg.org/TBeijen/dotfiles --apply

# Update from remote repo
chezmoi update
```

## File naming in chezmoi source dir

| Prefix | Meaning |
|--------|---------|
| `dot_` | Deployed as `.filename` |
| `private_` | File permissions set to 0600 / dir to 0700 |
| `empty_` | Create empty file (avoid — add content or remove) |
| `.tmpl` suffix | Processed as Go template |
| `run_once_` | Script that runs once per machine (for bootstrap) |
| `run_onchange_` | Script that re-runs when its content changes |
