#!/usr/bin/env bash
# Preserve reference images/videos as recoverable bytes in GitHub, not links.
set -euo pipefail
if [[ $# -ne 2 ]]; then
  echo "Usage: $0 /absolute/path/to/media.ext archived-filename.ext" >&2
  exit 2
fi
src=$1
name=$2
[[ -f "$src" ]] || { echo "Missing source media: $src" >&2; exit 2; }
[[ "$name" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]] || {
  echo "Use a simple filename without spaces or path separators." >&2; exit 2;
}
for command in gh git sha256sum mktemp; do
  command -v "$command" >/dev/null || {
    echo "Missing required executable: $command" >&2; exit 2;
  }
done
gh auth status >/dev/null
root=$(git rev-parse --show-toplevel)
cd "$root"
[[ -z "$(git status --porcelain)" ]] || {
  echo "Commit/stash other changes first: refusing to mix unrelated files." >&2
  exit 2
}
branch=$(git branch --show-current)
[[ -n "$branch" ]] || { echo "Check out a named branch first." >&2; exit 2; }
mkdir -p reference-media
target="reference-media/$name"
[[ ! -e "$target" ]] || { echo "Archive name already exists: $target" >&2; exit 2; }
expected=$(sha256sum "$src" | awk '{print $1}')
cp -- "$src" "$target"
actual=$(sha256sum "$target" | awk '{print $1}')
[[ "$expected" == "$actual" ]] || { echo "Copy hash mismatch" >&2; exit 1; }
size=$(wc -c < "$target" | tr -d ' ')
if (( size > 50000000 )); then
  command -v git-lfs >/dev/null || {
    echo "Files above 50 MB require git-lfs. Install Git LFS and retry." >&2
    rm -f "$target"
    exit 2
  }
  git lfs track 'reference-media/*'
  git add .gitattributes
fi
git add -- "$target"
git commit -m "assets(reference): preserve $name (sha256 $expected)"
git push -u origin "$branch"
remote=$(gh repo view --json nameWithOwner --jq .nameWithOwner)
echo "Uploaded: https://github.com/$remote/blob/$branch/$target"
echo "SHA-256: $expected"
echo "Verify the GitHub download and archive access permissions before claiming backup completion."
