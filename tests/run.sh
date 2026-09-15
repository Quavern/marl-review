#!/usr/bin/env bash
# SPDX-License-Identifier: LicenseRef-QOSL-1.0
# Copyright (c) 2026 Quavern
# This file is subject to the Quavern Open Source License, version 1.0.
# A copy is available at https://oss.quavern.com/licences/qosl/1.0/
#
# Render every fixture and compare with tests/expected. UPDATE=1 rewrites the expectations.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
root="$(dirname "$here")"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
fail=0

check() {
  local name="$1"; shift
  local report="$here/fixtures/$1"; shift
  python3 "$root/scripts/parse-findings.py" "$report" > "$work/$name.review.json"
  python3 "$root/scripts/render-comment.py" "$work/$name.review.json" "$@" > "$work/$name.md"
  if [ "${UPDATE:-0}" = "1" ]; then
    cp "$work/$name.md" "$here/expected/$name.md"
  elif ! diff -u "$here/expected/$name.md" "$work/$name.md"; then
    echo "FAIL $name"; fail=1
  else
    echo "ok   $name"
  fi
}

check valid-en     report-valid.json    --sha 0123456789abcdef0123 --language en
check valid-fr     report-valid.json    --sha 0123456789abcdef0123 --language fr
check empty-en     report-empty.json    --sha abcdef012345 --language en
check unparsed-en  report-unparsed.json --sha abcdef012345 --language en
check error-en     report-error.json    --sha abcdef012345 --language en
check truncated-en report-empty.json    --sha abcdef012345 --language en --diff-bytes 1234567 --reviewed-bytes 200000
check missing-en   does-not-exist.json  --sha abcdef012345 --language en

# The review keeps only valid findings, highest severity first.
python3 "$root/scripts/parse-findings.py" "$here/fixtures/report-valid.json" > "$work/parsed.json"
if [ "$(jq -c '[.findings[] | [.severity, .file, .line]]' "$work/parsed.json")" != '[["high","src/auth.py",17],["low","src/pay.py",42]]' ]; then
  echo "FAIL parse order/validation"; fail=1
else
  echo "ok   parse order/validation"
fi

# The marker is the first line, as upsert-comment.sh expects.
for file in "$work"/*.md; do
  if [ "$(head -1 "$file")" != "<!-- marl-review -->" ]; then echo "FAIL marker in $file"; fail=1; fi
done

# A fence in the model's answer cannot close the comment's fence.
if ! grep -q '^````text$' "$work/unparsed-en.md"; then echo "FAIL fence length"; fail=1; else echo "ok   fence length"; fi

# review.sh calls marl with the fixed prompt as one argument and the diff on stdin.
repo="$work/repo"
mkdir -p "$repo" && git -C "$repo" init -q -b main
git -C "$repo" -c user.email=t@example.org -c user.name=t commit -q --allow-empty -m base
base="$(git -C "$repo" rev-parse HEAD)"
printf 'print("hello")\n' > "$repo/app.py"
git -C "$repo" add app.py
git -C "$repo" -c user.email=t@example.org -c user.name=t commit -q -m head
head="$(git -C "$repo" rev-parse HEAD)"
(
  cd "$repo"
  BASE_SHA="$base" HEAD_SHA="$head" MAX_BYTES=10 OUT_DIR="$work/out" bash "$root/scripts/diff.sh" > "$work/diff.out"
  PATH="$here/mock:$PATH" MOCK_REPORT="$here/fixtures/report-valid.json" LANGUAGE=fr OUT_DIR="$work/out" ACTION_DIR="$root" \
    bash "$root/scripts/review.sh"
)
if grep -q '^reviewed_bytes=10$' "$work/diff.out" && [ "$(wc -c < "$work/out/diff.patch" | tr -d ' ')" = "10" ] \
   && [ "$(jq -r '.status' "$work/out/review.json")" = "ok" ]; then
  echo "ok   diff cut and review call"
else
  echo "FAIL diff cut or review call"; fail=1
fi

# upsert-comment.sh creates one comment, then updates only its own.
python3 "$here/mock_github.py" > "$work/port" &
server=$!
for _ in $(seq 50); do [ -s "$work/port" ] && break; sleep 0.1; done
port="$(cat "$work/port")"
printf '<!-- marl-review -->\nfirst\n' > "$work/c1.md"
printf '<!-- marl-review -->\nsecond\n' > "$work/c2.md"
for body in c1 c2; do
  GITHUB_TOKEN=t0k GITHUB_API_URL="http://127.0.0.1:$port" GITHUB_REPOSITORY=o/r PR_NUMBER=7 BODY_FILE="$work/$body.md" \
    bash "$root/scripts/upsert-comment.sh" > /dev/null
done
state="$(curl -fsS "http://127.0.0.1:$port/log")"
kill "$server"
if [ "$(printf '%s' "$state" | jq -c '.log')" = '["POST","PATCH 12"]' ] \
   && [ "$(printf '%s' "$state" | jq -r '.comments[] | select(.id == 1) | .body')" = "$(printf '<!-- marl-review -->\nplanted by a contributor')" ] \
   && [ "$(printf '%s' "$state" | jq -r '.comments[] | select(.id == 12) | .body')" = "$(printf '<!-- marl-review -->\nsecond')" ]; then
  echo "ok   comment created once, updated in place, planted marker untouched"
else
  echo "FAIL upsert: $state"; fail=1
fi

exit "$fail"
