#!/bin/bash
set -e

# Ensure /data is owned by openclaw user and has restricted permissions
chown openclaw:openclaw /data 2>/dev/null || true
chmod 700 /data 2>/dev/null || true

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

# Ensure OpenClaw's HOME-based config path points to the Railway volume.
# The gateway resolves config from ~/.openclaw/openclaw.json (HOME-based),
# NOT from OPENCLAW_STATE_DIR. Without this symlink, config patches are
# written to /data/.openclaw/ but the gateway reads from /home/openclaw/.openclaw/.
OPENCLAW_HOME_DIR="/home/openclaw/.openclaw"
OPENCLAW_DATA_DIR="${OPENCLAW_STATE_DIR:-/data/.openclaw}"
if [ ! -L "$OPENCLAW_HOME_DIR" ] && [ "$OPENCLAW_HOME_DIR" != "$OPENCLAW_DATA_DIR" ]; then
  mkdir -p "$(dirname "$OPENCLAW_HOME_DIR")"
  rm -rf "$OPENCLAW_HOME_DIR"
  ln -sf "$OPENCLAW_DATA_DIR" "$OPENCLAW_HOME_DIR"
  echo "[entrypoint] Symlinked $OPENCLAW_HOME_DIR -> $OPENCLAW_DATA_DIR" >&2
fi

echo "[entrypoint] Starting wrapper (deploy marker v4)" >&2
exec gosu openclaw node src/server.js
