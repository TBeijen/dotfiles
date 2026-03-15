# Shell Startup Optimizations

## 2026-03-15

### Context

Profiling zsh startup (`zprof` + wall-clock timing) revealed a ~1.8s shell startup time. The main contributors were:

| Component | Time | Visible in zprof? |
|-----------|------|-------------------|
| nvm (loaded twice) | ~1,230ms | Yes |
| ssh-add -A | ~555ms | No |
| pyenv (3 eval calls) | ~649ms | No |
| oh-my-zsh internals | ~290ms | Yes |
| oh-my-posh init | ~150ms | No (zprof reported ~32ms) |

### Completed

1. **Removed duplicate nvm load** (`zsh/99-zshrc.zsh`)
   - nvm was being sourced twice: once from `$HOMEBREW_PREFIX/opt/nvm/nvm.sh` and once from `$NVM_DIR/nvm.sh` (both resolve to the same Homebrew installation).
   - Removed the first block.

2. **Lazy-loaded nvm** (`zsh/99-zshrc.zsh`)
   - Replaced eager nvm sourcing with stub functions (`nvm`, `node`, `npm`, `npx`) that trigger the real nvm load on first use.
   - Startup saving: ~1,230ms → 0ms. First invocation in a session pays ~600ms one-time cost.
   - Revert instructions included as comments in the file.

3. **Removed azure oh-my-zsh plugin** (`common/.zshrc`)
   - Changed `plugins=(azure kubectl)` to `plugins=(kubectl)`.
   - Reduced `_omz_source` calls from 23 to 22.

4. **Removed `ssh-add -A`** (`zsh/99-zshrc.zsh`)
   - The `-A` flag pre-loads all keychain SSH keys at shell startup (~555ms).
   - This is redundant when `~/.ssh/config` has `UseKeychain yes` and `AddKeysToAgent yes`, which loads keys lazily on first use.
   - Saving: ~555ms.
   - Revert instructions included as comments in the file.

5. **Cached pyenv init** (`zsh/99-zshrc.zsh`)
   - Three `eval "$(pyenv ...)"` calls fork subprocesses totaling ~649ms.
   - Replaced with a cache file (`~/.cache/pyenv-init.zsh`) that is sourced directly and regenerated daily.
   - Saving: ~649ms (reduced to file read on subsequent startups).
   - Revert instructions included as comments in the file.

### Results

| Measurement | Time |
|-------------|------|
| Before optimizations | ~1.84s |
| After optimizations | ~0.95s |
| Without oh-my-posh | ~0.80s |

### Possible Further Improvements

- **Cache oh-my-posh init** (~150ms): Same caching approach as pyenv. The `eval "$(oh-my-posh init zsh ...)"` forks a subprocess; its output is static and could be cached.
- **oh-my-zsh overhead** (~290ms): The bulk of remaining time. `compinit`, `compaudit`, and 22 `_omz_source` calls for libs and the kubectl plugin. Reducing this would require dropping oh-my-zsh in favor of a lighter setup (e.g., manual plugin loading, or switching to a minimal framework like zinit/zplug).
- **Replace nvm with fnm** (Rust-based): Would eliminate the ~600ms first-use penalty of lazy-loaded nvm entirely. fnm initializes in ~1-5ms.
