#!/usr/bin/env bash
# SPDX-License-Identifier: LicenseRef-QOSL-1.0
# Copyright (c) 2026 Quavern
# This file is subject to the Quavern Open Source License, version 1.0.
# A copy is available at https://oss.quavern.com/licences/qosl/1.0/
#
# Write the pull request's diff to $OUT_DIR/diff.patch, cut to MAX_BYTES, and print
# "diff_bytes=N" and "reviewed_bytes=N" for $GITHUB_OUTPUT.
# Env: BASE_SHA, HEAD_SHA, MAX_BYTES, OUT_DIR.
set -euo pipefail

: "${BASE_SHA:?base commit is required}"
: "${HEAD_SHA:?head commit is required}"
: "${MAX_BYTES:=200000}"
: "${OUT_DIR:?}"
mkdir -p "$OUT_DIR"

for sha in "$BASE_SHA" "$HEAD_SHA"; do
  if ! git cat-file -e "${sha}^{commit}" 2>/dev/null; then
    git fetch --no-tags --quiet origin "$sha" || true
  fi
done

full="$OUT_DIR/diff.full"
if git merge-base "$BASE_SHA" "$HEAD_SHA" >/dev/null 2>&1; then
  git diff --no-color --unified=3 "${BASE_SHA}...${HEAD_SHA}" > "$full"
else
  git diff --no-color --unified=3 "$BASE_SHA" "$HEAD_SHA" > "$full"
fi

total=$(wc -c < "$full" | tr -d ' ')
if [ "$total" -gt "$MAX_BYTES" ]; then
  head -c "$MAX_BYTES" "$full" > "$OUT_DIR/diff.patch"
  reviewed="$MAX_BYTES"
else
  cp "$full" "$OUT_DIR/diff.patch"
  reviewed="$total"
fi
rm -f "$full"
echo "diff_bytes=$total"
echo "reviewed_bytes=$reviewed"
