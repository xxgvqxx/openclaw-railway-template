#!/bin/bash
set -e

# Ensure /data and OpenClaw state paths are writable by openclaw
mkdir -p /data/.openclaw/identity /data/workspace
chown -R openclaw:openclaw /data 2>/dev/null || true
chmod 700 /data 2>/dev/null || true
chmod 700 /data/.openclaw 2>/dev/null || true
chmod 700 /data/.openclaw/identity 2>/dev/null || true

# Persist Homebrew to Railway volume so it survives container rebuilds
BREW_VOLUME="/data/.linuxbrew"
BREW_SYSTEM="/home/openclaw/.linuxbrew"

if [ -d "$BREW_VOLUME" ]; then
  # Volume already has Homebrew — symlink back to expected location
  if [ ! -L "$BREW_SYSTEM" ]; then
    rm -rf "$BREW_SYSTEM"
    ln -sf "$BREW_VOLUME" "$BREW_SYSTEM"
    echo "[entrypoint] Restored Homebrew from volume symlink"
  fi
else
  # First boot — move Homebrew install to volume for persistence
  if [ -d "$BREW_SYSTEM" ] && [ ! -L "$BREW_SYSTEM" ]; then
    mv "$BREW_SYSTEM" "$BREW_VOLUME"
    ln -sf "$BREW_VOLUME" "$BREW_SYSTEM"
    echo "[entrypoint] Persisted Homebrew to volume on first boot"
  fi
fi

# Fix HOME for gosu: gosu changes uid/gid but does NOT update $HOME.
# Without this, $HOME stays as /root (from USER root in Dockerfile),
# so os.homedir() in Node.js returns /root, and the OpenClaw gateway
# reads config from /root/.openclaw/ instead of /home/openclaw/.openclaw/.
# Since /root has 700 perms, the openclaw user can't access it at all.
export HOME=/home/openclaw

# Ensure OpenClaw's HOME-based config path points to the Railway volume.
# The gateway resolves config from ~/.openclaw/openclaw.json (HOME-based).
# This symlink makes ~/. openclaw/ → /data/.openclaw/ (the persistent volume).
OPENCLAW_HOME_DIR="${HOME}/.openclaw"
OPENCLAW_DATA_DIR="${OPENCLAW_STATE_DIR:-/data/.openclaw}"
if [ ! -L "$OPENCLAW_HOME_DIR" ] && [ "$OPENCLAW_HOME_DIR" != "$OPENCLAW_DATA_DIR" ]; then
  mkdir -p "$(dirname "$OPENCLAW_HOME_DIR")"
  rm -rf "$OPENCLAW_HOME_DIR"
  ln -sf "$OPENCLAW_DATA_DIR" "$OPENCLAW_HOME_DIR"
  echo "[entrypoint] Symlinked $OPENCLAW_HOME_DIR -> $OPENCLAW_DATA_DIR" >&2
fi

echo "[entrypoint] Starting wrapper (HOME=$HOME, deploy marker v5)" >&2
exec gosu openclaw node src/server.js
