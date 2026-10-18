#!/usr/bin/env bash
# Restore a persistent Android signing identity from its GitHub age archive.
# A recovery passphrase entered on the local terminal is REQUIRED.
# GitHub Actions secrets alone cannot be read back as plaintext.
set -euo pipefail
umask 077
REPO="dbrckk/Jelly-bricks"
ARCHIVE_PATH="security/android-signing-recovery.age"
KEY_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/jelly-bricks/android-signing"
KEYSTORE="$KEY_DIR/jelly-debug.keystore"

for binary in age gh tar base64 keytool; do
  command -v "$binary" >/dev/null 2>&1 || {
    echo "Missing required recovery tool: $binary" >&2
    exit 1
  }
done
if (( $# != 0 )); then
  echo "Usage: bash scripts/recover-android-signing.sh" >&2
  exit 2
fi
if [[ -e "$KEYSTORE" || -L "$KEYSTORE" ]]; then
  echo "A local signing keystore already exists; refusing to overwrite it." >&2
  exit 1
fi
gh auth status >/dev/null
tmp="$(mktemp -d)"
trap 'unset JELLY_SIGNING_PASS; rm -rf -- "$tmp"' EXIT

# GitHub stores only age ciphertext; there is no server-side decryption path.
gh api "repos/$REPO/contents/$ARCHIVE_PATH" --jq .content \
  | tr -d '\n' | base64 --decode > "$tmp/recovery.age"
if [[ ! -s "$tmp/recovery.age" ]]; then
  echo "Encrypted GitHub recovery archive not found or empty." >&2
  exit 1
fi
echo "Enter your OFFLINE age recovery passphrase to decrypt the GitHub archive."
age -d -o "$tmp/recovery.tar" "$tmp/recovery.age"

# Extract exact fixed paths from the authenticated archive, not arbitrary
# tar member names or symlinks. Never unpack unknown paths into $HOME.
tar -xOf "$tmp/recovery.tar" signing.keystore > "$tmp/verified.keystore"
JELLY_SIGNING_PASS="$(tar -xOf "$tmp/recovery.tar" signing.password)"
alias_name="$(tar -xOf "$tmp/recovery.tar" signing.alias)"
archived_sha="$(tar -xOf "$tmp/recovery.tar" signing.sha256)"
export JELLY_SIGNING_PASS
if [[ "$alias_name" != "jellybricksdebug" || ! "$archived_sha" =~ ^[a-f0-9]{64}$ \
      || -z "$JELLY_SIGNING_PASS" || ! -s "$tmp/verified.keystore" ]]; then
  echo "Authenticated archive contains unexpected or incomplete signing material." >&2
  exit 1
fi
cert="$(keytool -list -v -keystore "$tmp/verified.keystore" \
  -alias "$alias_name" -storepass:env JELLY_SIGNING_PASS \
  | sed -n 's/^[[:space:]]*SHA256:[[:space:]]*//p' \
  | head -n 1 | tr -d '[:space:]:' | tr '[:upper:]' '[:lower:]')"
pin="$(gh variable get JELLY_ANDROID_CERT_SHA256 --repo "$REPO" 2>/dev/null || true)"
normalized_pin="$(printf '%s' "$pin" | tr -d '[:space:]:' | tr '[:upper:]' '[:lower:]')"
if [[ "$cert" != "$archived_sha" ]] \
    || [[ -n "$normalized_pin" && "$normalized_pin" != "$cert" ]]; then
  echo "Encrypted signing identity differs from GitHub's pinned certificate." >&2
  exit 1
fi
mkdir -p "$KEY_DIR"
chmod 700 "$KEY_DIR"
mv -- "$tmp/verified.keystore" "$KEYSTORE"
chmod 600 "$KEYSTORE"
echo "Recovered the original signing identity, fingerprint: $cert"

existing="$(gh secret list --repo "$REPO" --json name --jq '.[].name')"
found=0
for name in JELLY_ANDROID_KEYSTORE_B64 JELLY_ANDROID_KEYSTORE_PASSWORD JELLY_ANDROID_KEYSTORE_ALIAS; do
  if printf '%s\n' "$existing" | grep -Fxq "$name"; then
    found=$((found + 1))
  fi
done
if (( found == 3 )); then
  echo "Existing GitHub signing secrets were preserved; no rotation or replacement."
elif (( found == 0 )); then
  gh variable set JELLY_ANDROID_CERT_SHA256 --repo "$REPO" --body "$cert"
  base64 < "$KEYSTORE" | tr -d '\n' \
    | gh secret set JELLY_ANDROID_KEYSTORE_B64 --repo "$REPO"
  printf '%s' "$JELLY_SIGNING_PASS" \
    | gh secret set JELLY_ANDROID_KEYSTORE_PASSWORD --repo "$REPO"
  printf '%s' "$alias_name" \
    | gh secret set JELLY_ANDROID_KEYSTORE_ALIAS --repo "$REPO"
  echo "Reinstalled the recovered signing identity in GitHub Actions."
else
  echo "WARNING: Some signing secrets already exist. No secrets were overwritten." >&2
  echo "Reconcile the partial secrets before generating another Android APK." >&2
  exit 1
fi
echo "Keep the age recovery passphrase and an offline keystore backup safe."
