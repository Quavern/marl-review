#!/usr/bin/env bash
# SPDX-License-Identifier: LicenseRef-QOSL-1.0
# Copyright (c) 2026 Quavern
# This file is subject to the Quavern Open Source License, version 1.0.
# A copy is available at https://oss.quavern.com/licences/qosl/1.0/
#
# Run Marl Code once over the diff and write $OUT_DIR/report.json and $OUT_DIR/review.json.
# The instruction is fixed (prompts/review.txt) and passed as the argument; the diff
# goes in on stdin, so its text is attached as data and never parsed for @file
# references. No approval flag is passed: in exec, every change is refused.
# Env: MARL_API_KEY, LANGUAGE (en|fr), OUT_DIR, ACTION_DIR.
set -uo pipefail

: "${OUT_DIR:?}"
: "${ACTION_DIR:?}"
case "${LANGUAGE:-en}" in
  en) language="English" ;;
  fr) language="French" ;;
  *) echo "language must be en or fr" >&2; exit 2 ;;
esac

prompt="$(sed "s/__LANGUAGE__/${language}/" "$ACTION_DIR/prompts/review.txt")"

if [ ! -s "$OUT_DIR/diff.patch" ]; then
  printf '%s\n' '{"result":"{\"findings\":[],\"summary\":\"The pull request has no textual diff.\"}","requests":0,"usage":{}}' > "$OUT_DIR/report.json"
else
  marl exec --json "$prompt" < "$OUT_DIR/diff.patch" > "$OUT_DIR/report.json"
  status=$?
  if [ ! -s "$OUT_DIR/report.json" ]; then
    printf '%s\n' "{\"result\":\"\",\"error\":{\"code\":\"REVIEW-0002\",\"message\":\"marl exec exited with status ${status} and no report\"}}" > "$OUT_DIR/report.json"
  fi
fi

python3 "$ACTION_DIR/scripts/parse-findings.py" "$OUT_DIR/report.json" > "$OUT_DIR/review.json"
