#!/bin/sh
set -eu

base_commit="${PHP_BASE_COMMIT:-004cb827501d1ddaf98daacb185a53e0816f78a7}"
security_commit="${PHP_SECURITY_COMMIT:-712e60f9edfd03f0960fc4fc3c2c375f42b90aa2}"
security_ref="${PHP_SECURITY_REF:-refs/heads/PHP-7.4-CVE-2026-109618-109619}"
expected_patch_sha="${PATCH_SHA256:-de1b914a84b25196b82ede7d8c0031d43be72f232b259b984e7ef72507b10631}"
patch_file="${1:-patches/CVE-2026-109618-109619.patch}"
repo_dir="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
case "$patch_file" in
    /*) ;;
    *) patch_file="${repo_dir}/${patch_file}" ;;
esac
work_dir="$(mktemp -d)"

cleanup() {
    rm -rf "$work_dir"
}
trap cleanup EXIT INT TERM

echo "${expected_patch_sha}  ${patch_file}" | sha256sum -c -

# Preserve and verify the published patch bytes, but normalize CRLF in the
# temporary copy consumed by git-apply. The source trees use LF line endings.
normalized_patch="$work_dir/security.patch"
sed 's/\r$//' "$patch_file" > "$normalized_patch"

git init -q "$work_dir/php-src"
git -C "$work_dir/php-src" remote add origin https://github.com/php/php-src.git
git -C "$work_dir/php-src" fetch -q --depth=2 origin "$security_ref"

actual_security_commit="$(git -C "$work_dir/php-src" rev-parse FETCH_HEAD)"
test "$actual_security_commit" = "$security_commit"

actual_parent="$(git -C "$work_dir/php-src" rev-parse "${actual_security_commit}^")"
test "$actual_parent" = "$base_commit"

git -C "$work_dir/php-src" checkout -q --detach "$base_commit"
git -C "$work_dir/php-src" apply --check "$normalized_patch"
git -C "$work_dir/php-src" apply "$normalized_patch"

actual_files="$(git -C "$work_dir/php-src" diff --name-only | sort)"
official_files="$(git -C "$work_dir/php-src" diff --name-only "$base_commit" "$actual_security_commit" | sort)"
test "$actual_files" = "$official_files"

git -C "$work_dir/php-src" add -A
patched_tree="$(git -C "$work_dir/php-src" write-tree)"
official_tree="$(git -C "$work_dir/php-src" rev-parse "${actual_security_commit}^{tree}")"
test "$patched_tree" = "$official_tree"

file_count="$(printf '%s\n' "$actual_files" | sed '/^$/d' | wc -l | tr -d ' ')"
test "$file_count" = "17"

echo "Provenance verified: ${security_commit} is the exact 17-file patch applied to ${base_commit}."
