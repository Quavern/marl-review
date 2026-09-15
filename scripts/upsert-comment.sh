#!/usr/bin/env bash
# SPDX-License-Identifier: LicenseRef-QOSL-1.0
# Copyright (c) 2026 Quavern
# This file is subject to the Quavern Open Source License, version 1.0.
# A copy is available at https://oss.quavern.com/licences/qosl/1.0/
#
# Create or update the one Marl Review comment on a pull request.
# Only a comment that starts with the marker AND was written by COMMENT_AUTHOR is
# updated, so a marker pasted into someone else's comment is never touched.
# Env: GITHUB_TOKEN, GITHUB_API_URL, GITHUB_REPOSITORY, PR_NUMBER, BODY_FILE,
#      COMMENT_AUTHOR (default github-actions[bot]).
set -euo pipefail

: "${GITHUB_TOKEN:?}"
: "${GITHUB_REPOSITORY:?}"
: "${PR_NUMBER:?}"
: "${BODY_FILE:?}"
api="${GITHUB_API_URL:-https://api.github.com}"
author="${COMMENT_AUTHOR:-github-actions[bot]}"
marker="<!-- marl-review -->"

call() {
  curl -fsS --retry 3 \
    -H "Authorization: Bearer ${GITHUB_TOKEN}" \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "$@"
}

existing=""
page=1
while :; do
  batch="$(call "${api}/repos/${GITHUB_REPOSITORY}/issues/${PR_NUMBER}/comments?per_page=100&page=${page}")"
  found="$(printf '%s' "$batch" | jq -r --arg m "$marker" --arg a "$author" \
    '[.[] | select(.user.login == $a and (.body | startswith($m)))] | last | .id // empty')"
  if [ -n "$found" ]; then existing="$found"; fi
  count="$(printf '%s' "$batch" | jq 'length')"
  if [ "$count" -lt 100 ]; then break; fi
  page=$((page + 1))
done

payload="$(jq -Rs '{body: .}' < "$BODY_FILE")"
if [ -n "$existing" ]; then
  call -X PATCH "${api}/repos/${GITHUB_REPOSITORY}/issues/comments/${existing}" -d "$payload" > /dev/null
  echo "updated comment ${existing}"
else
  call -X POST "${api}/repos/${GITHUB_REPOSITORY}/issues/${PR_NUMBER}/comments" -d "$payload" > /dev/null
  echo "created comment"
fi
