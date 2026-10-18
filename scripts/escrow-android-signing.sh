#!/usr/bin/env bash
# Encrypt AND publish the locally generated Android signing identity.
# Called by setup-android-signing.sh, never by GitHub Actions.
set -euo pipefail
umask 077
REPO="dbrckk/Jelly-bricks"
ARCHIVE_PATH="security/android-signing-recovery.age"
ALIAS="jellybricksdebug"
KEY_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/jelly-bricks/android-signing"
KEYSTORE="$KEY_DIR/jelly-debug.keystore"

for binary in age gh tar base64 keytool; do
  command -v "$binary" >/dev/null 2>&1 || {
    echo "Missing required signing-backup tool: $binary" >&2
    exit 1
  }
done
if [[ -z "${JELLY_SIGNING_PASS:-}" || ! -s "$KEYSTORE" ]]; then
  echo "Missing local signing key or password. Run setup-android-signing.sh." >&2
  exit 1
fi
if gh api "repos/$REPO/contents/$ARCHIVE_PATH" >/dev/null 2>&1; then
  echo "An encrypted signing recovery archive ALREADY exists in GitHub." >&2
  echo "Refusing to overwrite it or silently rotate a deployed signing key." >&2
  exit 1
fi

tmp="$(mktemp -d)"
trap 'rm -rf -- "$tmp"' EXIT
cp -- "$KEYSTORE" "$tmp/signing.keystore"
printf '%s' "$JELLY_SIGNING_PASS" > "$tmp/signing.password"
printf '%s' "$ALIAS" > "$tmp/signing.alias"
fingerprint="$(keytool -list -v -keystore "$KEYSTORE" \
  -alias "$ALIAS" -storepass:env JELLY_SIGNING_PASS \
  | sed -n 's/^[[:space:]]*SHA256:[[:space:]]*//p' \
  | head -n 1 | tr -d '[:space:]:' | tr '[:upper:]' '[:lower:]')"
if [[ ! "$fingerprint" =~ ^[a-f0-9]{64}$ ]]; then
  echo "Could not verify the local Android signing certificate." >&2
  exit 1
fi
printf '%s' "$fingerprint" > "$tmp/signing.sha256"
echo "Encrypting Android signing recovery bundle with age (scrypt + authenticated encryption)."
echo "Save the age recovery passphrase OUTSIDE GitHub. Without it this archive cannot be recovered."
# Never save an unencrypted tarball; age reads it through stdin.
tar -C "$tmp" -cf - signing.keystore signing.password signing.alias signing.sha256 \
  | age -p -a -o "$tmp/recovery.age"
test -s "$tmp/recovery.age" || exit 1
# Only encrypted bytes cross GitHub's contents API. The plaintext keystore
# and both passwords never appear in a commit, runner log or Actions artifact.
encrypted_base64="$(base64 < "$tmp/recovery.age" | tr -d '\n')"
gh api "repos/$REPO/contents/$ARCHIVE_PATH" -X PUT \
  -f message="security(android): encrypted recovery archive for persistent debug signer" \
  -f content="$encrypted_base64" >/dev/null
echo "Encrypted recovery archive published: https://github.com/$REPO/blob/main/$ARCHIVE_PATH"
echo "Key fingerprint: $fingerprint"
