#!/usr/bin/env bash
# Run locally. NEVER run this on GitHub Actions and NEVER commit the keystore.
# No private signing bytes, passwords or base64 payloads are written to stdout.
set -euo pipefail

REPO="dbrckk/Jelly-bricks"
ALIAS="jellybricksdebug"
KEY_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/jelly-bricks/android-signing"
KEYSTORE="$KEY_DIR/jelly-debug.keystore"

if (( $# != 0 )); then
  printf 'Usage: bash scripts/setup-android-signing.sh\n' >&2
  exit 2
fi
for binary in keytool base64 gh age tar; do
  if ! command -v "$binary" >/dev/null 2>&1; then
    printf 'Missing required command: %s\n' "$binary" >&2
    exit 1
  fi
done
if [[ ! -r /dev/tty ]]; then
  echo "Run from an interactive terminal; no signing password is accepted in arguments." >&2
  exit 1
fi
gh auth status >/dev/null
actual_repo="$(gh repo view "$REPO" --json nameWithOwner --jq '.nameWithOwner')"
if [[ "$actual_repo" != "$REPO" ]]; then
  echo "Unexpected GitHub repository; refusing to upload signing material." >&2
  exit 1
fi

# Never overwrite an already configured signing identity; this could make
# every installed Android package impossible to update without data loss.
existing="$(gh secret list --repo "$REPO" --json name --jq '.[].name')"
if printf '%s\n' "$existing" | grep -Eq '^JELLY_ANDROID_KEYSTORE_(B64|PASSWORD|ALIAS)$'; then
  echo "A signing secret already exists. Refusing to replace it." >&2
  echo "Check the existing certificate fingerprint and reuse the original keystore." >&2
  exit 1
fi

umask 077
mkdir -p "$KEY_DIR"
chmod 700 "$KEY_DIR"
if [[ -L "$KEYSTORE" ]]; then
  echo "Keystore path must not be a symbolic link." >&2
  exit 1
fi
printf 'Local signing keystore: %s\n' "$KEYSTORE"
if [[ -e "$KEYSTORE" ]]; then
  echo "An existing keystore was found; it will be reused, never replaced."
else
  echo "A NEW persistent debug keystore will be created locally."
fi
printf 'Password (minimum 12 characters; hidden): ' > /dev/tty
IFS= read -r -s JELLY_SIGNING_PASS < /dev/tty
printf '\nConfirm password: ' > /dev/tty
IFS= read -r -s confirmation < /dev/tty
printf '\n' > /dev/tty
trap 'unset JELLY_SIGNING_PASS confirmation' EXIT
if [[ "${#JELLY_SIGNING_PASS}" -lt 12 || "$JELLY_SIGNING_PASS" != "$confirmation" ]]; then
  echo "Password is too short or confirmation differs." >&2
  exit 1
fi
unset confirmation
export JELLY_SIGNING_PASS

if [[ ! -e "$KEYSTORE" ]]; then
  keytool -genkeypair -keystore "$KEYSTORE" \
    -alias "$ALIAS" -keyalg RSA -keysize 3072 -validity 10000 \
    -dname "CN=Jelly Bricks Android Debug,O=Jelly Bricks,C=FR" \
    -storepass:env JELLY_SIGNING_PASS -keypass:env JELLY_SIGNING_PASS >/dev/null
fi
chmod 600 "$KEYSTORE"
certificate="$(keytool -list -v -keystore "$KEYSTORE" \
  -alias "$ALIAS" -storepass:env JELLY_SIGNING_PASS \
  | sed -n 's/^[[:space:]]*SHA256:[[:space:]]*//p' \
  | head -n 1 | tr -d '[:space:]:' | tr '[:upper:]' '[:lower:]')"
if [[ ! "$certificate" =~ ^[0-9a-f]{64}$ ]]; then
  echo "Keystore certificate could not be verified; no secrets uploaded." >&2
  exit 1
fi
existing_pin="$(gh variable get JELLY_ANDROID_CERT_SHA256 --repo "$REPO" 2>/dev/null || true)"
normalized_pin="$(printf '%s' "$existing_pin" | tr -d '[:space:]:' | tr '[:upper:]' '[:lower:]')"
if [[ -n "$normalized_pin" && "$normalized_pin" != "$certificate" ]]; then
  echo "Pinned certificate differs. Refusing to rotate Android signing identity." >&2
  exit 1
fi
echo "Public signing SHA-256: $certificate"

# Escrow the keystore AND its password in an age-encrypted GitHub file,
# protected by an independent recovery passphrase supplied interactively.
# This must succeed before uploading Secrets; an encrypted public file is
# only safe when its recovery passphrase is kept privately and securely.
if [[ ! -f scripts/escrow-android-signing.sh ]]; then
  echo "Run this setup script from the Jelly-bricks repository root." >&2
  exit 1
fi
bash scripts/escrow-android-signing.sh

# Set the public pin BEFORE uploading the secrets. If an upload fails,
# fix the partial GitHub setup; NEVER regenerate the keystore.
gh variable set JELLY_ANDROID_CERT_SHA256 --repo "$REPO" --body "$certificate"
base64 < "$KEYSTORE" | tr -d '\n' \
  | gh secret set JELLY_ANDROID_KEYSTORE_B64 --repo "$REPO"
printf '%s' "$JELLY_SIGNING_PASS" \
  | gh secret set JELLY_ANDROID_KEYSTORE_PASSWORD --repo "$REPO"
printf '%s' "$ALIAS" \
  | gh secret set JELLY_ANDROID_KEYSTORE_ALIAS --repo "$REPO"

echo "Permanent Android DEBUG signer configured in GitHub Actions."
echo "The encrypted GitHub escrow includes the keystore AND signing password."
echo "Protect the independent age recovery passphrase: it is never stored in GitHub."
echo "Keep an additional secure offline copy; GitHub is not a disaster-proof vault."
echo "Do not remove an already installed APK without first exporting player saves."
echo "Trigger the Godot Android Native APK workflow on main to verify the signature."
