#!/usr/bin/env bash
set -euo pipefail

# ----------------------------
# Runpod bootstrap: apt + curl, Claude Code, auth pause, git clone w/ PAT
# ----------------------------

# ====== CONFIG (edit these) ======
REPO_HTTPS_URL="${REPO_HTTPS_URL:-https://github.com/aadijain725/design2garmentcode-impl.git}"   # <-- change
CLONE_DIR="${CLONE_DIR:-repo}"                                         # <-- change if you want
BRANCH="${BRANCH:-3d-draping-enabled}"                                  # optional, e.g. "main"
# =================================

log()  { printf "\n\033[1;32m[%s]\033[0m %s\n" "$(date +'%H:%M:%S')" "$*"; }
warn() { printf "\n\033[1;33m[%s]\033[0m %s\n" "$(date +'%H:%M:%S')" "$*"; }
die()  { printf "\n\033[1;31m[%s]\033[0m %s\n" "$(date +'%H:%M:%S')" "$*"; exit 1; }

need_cmd() { command -v "$1" >/dev/null 2>&1; }

# Ensure we're in a predictable HOME (Runpod containers usually have /root)
: "${HOME:=/root}"

log "1) System prep: apt update + install curl/git"
if ! need_cmd apt-get; then
  die "apt-get not found. This script expects Ubuntu/Debian base image."
fi

export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y --no-install-recommends \
  ca-certificates curl git openssh-client

log "2) Install Claude Code (if not already installed)"
# Claude installer typically puts binary at ~/.local/bin/claude
if [ ! -x "$HOME/.local/bin/claude" ] && ! need_cmd claude; then
  curl -fsSL https://claude.ai/install.sh | bash
else
  warn "Claude appears to already be installed. Skipping install."
fi

# Make sure ~/.local/bin is in PATH for *this shell* and future shells
if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
  export PATH="$HOME/.local/bin:$PATH"
fi

# Persist PATH fix for future shells
grep -q 'export PATH="\$HOME/.local/bin:\$PATH"' "$HOME/.bashrc" 2>/dev/null || \
  echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"

if ! need_cmd claude; then
  die "Claude still not found on PATH. Try: ls -l $HOME/.local/bin/claude"
fi

log "Claude version:"
claude --version || true

log "3) Authenticate Claude Code (browser login)"
warn "This is interactive. We'll run: claude login"
warn "It will print a URL/code. Complete it in your browser."
echo
read -r -p "Press ENTER to run 'claude login' now: " _

set +e
claude login
LOGIN_EXIT=$?
set -e

if [ $LOGIN_EXIT -ne 0 ]; then
  die "claude login failed (exit=$LOGIN_EXIT). On Runpod, make sure you can open the login URL in your local browser."
fi

echo
read -r -p "When authentication is complete, press ENTER to continue... " _

log "4) Git clone with PAT for push privileges"
if [ -d "$CLONE_DIR/.git" ]; then
  warn "Directory '$CLONE_DIR' already looks like a git repo. Skipping clone."
else
  read -r -p "GitHub username (for HTTPS auth): " GH_USER
  read -r -s -p "GitHub PAT (fine-grained) with Contents: Read+Write: " GH_PAT
  echo

  # Build an authenticated URL without printing PAT to logs.
  # Note: This URL will be used only for the clone command.
  AUTH_URL="$(echo "$REPO_HTTPS_URL" | sed -E "s#https://#https://$GH_USER:$GH_PAT@#")"

  # Clone (optionally a specific branch)
  if [ -n "$BRANCH" ]; then
    git clone --branch "$BRANCH" "$AUTH_URL" "$CLONE_DIR"
  else
    git clone "$AUTH_URL" "$CLONE_DIR"
  fi

  # Set remote to clean URL (no credentials embedded in repo config)
  git -C "$CLONE_DIR" remote set-url origin "$REPO_HTTPS_URL"

  # Store creds for this instance (optional):
  # Git credential store writes plaintext in ~/.git-credentials.
  warn "Optional: storing credentials for this instance (plaintext) via git credential.helper=store."
  warn "This is convenient on short-lived pods, but it's plaintext on disk."
  read -r -p "Store git credentials on this instance? (y/N): " STORE_CREDS
  if [[ "$STORE_CREDS" =~ ^[Yy]$ ]]; then
    git config --global credential.helper store

    # Trigger credential storage by doing a harmless authenticated operation:
    AUTH_URL2="$(echo "$REPO_HTTPS_URL" | sed -E "s#https://#https://$GH_USER:$GH_PAT@#")"
    git -C "$CLONE_DIR" ls-remote "$AUTH_URL2" >/dev/null
    log "Credentials stored at ~/.git-credentials (plaintext)."
  else
    log "Skipping credential storage."
  fi
fi

log "Done."
log "Repo is at: $CLONE_DIR"
log "Next: cd $CLONE_DIR && claude ."
