#!/usr/bin/env bash
set -euo pipefail

# --- Configuration ---
USERNAME="ansible-jenkins"
SSH_PUB_KEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEEkKCnoRuPhoediY62pe+VxVE6pwsAbKbqNnWxP37aK ansible-jenkins"  # <-- paste your public key here

# --- Must run as root ---
if [[ $EUID -ne 0 ]]; then
  echo "ERROR: This script must be run as root (or via sudo)." >&2
  exit 1
fi

# --- Detect OS family ---
if [[ -f /etc/os-release ]]; then
  . /etc/os-release
  ID_LIKE="${ID_LIKE:-}"
  case "$ID_LIKE" in
    *debian*) SUDO_GROUP="sudo" ;;
    *rhel*|*fedora*) SUDO_GROUP="wheel" ;;
    *)
      case "$ID" in
        debian|ubuntu) SUDO_GROUP="sudo" ;;
        rhel|centos|fedora|rocky|alma|ol) SUDO_GROUP="wheel" ;;
        *) echo "ERROR: Unsupported OS: $ID"; exit 1 ;;
      esac
      ;;
  esac
else
  echo "ERROR: /etc/os-release not found, cannot detect OS." >&2
  exit 1
fi

echo "Detected sudo group: ${SUDO_GROUP}"

# --- Create user ---
if id "$USERNAME" &>/dev/null; then
  echo "User ${USERNAME} already exists, ensuring group membership..."
  usermod -aG "$SUDO_GROUP" "$USERNAME"
else
  echo "Creating user ${USERNAME}..."
  useradd -m -s /bin/bash -G "$SUDO_GROUP" "$USERNAME"
fi

# --- Deploy SSH authorized key ---
SSH_DIR="/home/${USERNAME}/.ssh"
AUTH_KEYS="${SSH_DIR}/authorized_keys"

mkdir -p "$SSH_DIR"
chmod 700 "$SSH_DIR"

if ! grep -qF "$SSH_PUB_KEY" "$AUTH_KEYS" 2>/dev/null; then
  echo "$SSH_PUB_KEY" >> "$AUTH_KEYS"
  echo "SSH public key added."
else
  echo "SSH public key already present."
fi

chmod 600 "$AUTH_KEYS"
chown -R "${USERNAME}:${USERNAME}" "$SSH_DIR"

# --- Passwordless sudo ---
SUDOERS_FILE="/etc/sudoers.d/200-${USERNAME}"
echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" > "$SUDOERS_FILE"
chown root:root "$SUDOERS_FILE"
chmod 0440 "$SUDOERS_FILE"

echo "Done. User ${USERNAME} is ready."