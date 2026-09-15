#!/usr/bin/env python3
# SPDX-License-Identifier: LicenseRef-QOSL-1.0
# Copyright (c) 2026 Quavern
# This file is subject to the Quavern Open Source License, version 1.0.
# A copy is available at https://oss.quavern.com/licences/qosl/1.0/
"""Render the pull-request comment from review.json.

    render-comment.py REVIEW.json --sha SHA --language en|fr
                      [--diff-bytes N --reviewed-bytes N]

The first line is the marker the upsert step looks for; keep it first.
"""

from __future__ import annotations

import argparse
import json
import re
import sys

MARKER = "<!-- marl-review -->"

COPY = {
    "en": {
        "title": "Marl Review",
        "columns": ("Severity", "Location", "Problem", "Fix"),
        "none": "No defect found in this diff.",
        "unparsed": "The review did not come back in the expected format. The answer as returned:",
        "error": "The review could not run: `{code}` {message}",
        "commit": "Reviewed commit `{sha}`.",
        "commit_error": "Commit `{sha}`.",
        "truncated": "The diff is {total} bytes; only the first {reviewed} were reviewed.",
        "usage": "Tokens: {total} ({prompt} prompt, {completion} completion) over {requests} request{s}.",
        "footer": "Marl Review · Quavern",
        "severity": {"high": "high", "medium": "medium", "low": "low"},
    },
    "fr": {
        "title": "Marl Review",
        "columns": ("Gravité", "Emplacement", "Problème", "Correction"),
        "none": "Aucun défaut trouvé dans ce diff.",
        "unparsed": "La revue n’est pas revenue au format attendu. Réponse telle que reçue :",
        "error": "La revue n’a pas pu s’exécuter : `{code}` {message}",
        "commit": "Commit relu : `{sha}`.",
        "commit_error": "Commit `{sha}`.",
        "truncated": "Le diff fait {total} octets ; seuls les {reviewed} premiers ont été relus.",
        "usage": "Jetons : {total} ({prompt} en entrée, {completion} en sortie) sur {requests} requête{s}.",
        "footer": "Marl Review · Quavern",
        "severity": {"high": "haute", "medium": "moyenne", "low": "basse"},
    },
}


def number(value: int, language: str) -> str:
    text = f"{int(value):,}"
    return text.replace(",", " ") if language == "fr" else text


def cell(text: str, limit: int = 400) -> str:
    text = " ".join(str(text).split())
    if len(text) > limit:
        text = text[: limit - 1].rstrip() + "…"
    return text.replace("|", "\\|")


def fence(text: str) -> str:
    """A code fence longer than any backtick run in ``text``, so the answer cannot close it."""
    body = text if len(text) <= 20000 else text[:20000] + "\n…"
    longest = max((len(run) for run in re.findall(r"`+", body)), default=0)
    ticks = "`" * max(3, longest + 1)
    return f"{ticks}text\n{body}\n{ticks}"


def render(review: dict, *, sha: str, language: str, diff_bytes: int = 0, reviewed_bytes: int = 0) -> str:
    copy = COPY[language]
    lines = [MARKER, f"### {copy['title']}", ""]
    status = review.get("status")
    if status == "error":
        error = review.get("error") or {}
        lines.append(copy["error"].format(code=cell(error.get("code") or "?", 40), message=cell(error.get("message") or "", 300)).rstrip())
    elif status == "unparsed":
        lines.append(copy["unparsed"])
        lines.append("")
        lines.append(fence(str(review.get("raw") or "")))
    else:
        if review.get("summary"):
            lines.append(cell(review["summary"], 600))
            lines.append("")
        findings = review.get("findings") or []
        if findings:
            lines.append("| " + " | ".join(copy["columns"]) + " |")
            lines.append("| --- | --- | --- | --- |")
            for finding in findings:
                location = finding["file"] + (f":{finding['line']}" if finding.get("line") else "")
                lines.append(
                    f"| {copy['severity'][finding['severity']]} | `{cell(location, 200).replace('`', '')}` | "
                    f"{cell(finding['problem'])} | {cell(finding.get('fix') or '—')} |"
                )
        else:
            lines.append(copy["none"])
    lines.append("")
    meta = [copy["commit_error" if status == "error" else "commit"].format(sha=cell(sha[:12], 40))]
    if diff_bytes and reviewed_bytes and reviewed_bytes < diff_bytes:
        meta.append(copy["truncated"].format(total=number(diff_bytes, language), reviewed=number(reviewed_bytes, language)))
    usage = review.get("usage") or {}
    if usage.get("total_tokens"):
        requests = int(review.get("requests") or 0)
        meta.append(
            copy["usage"].format(
                total=number(usage.get("total_tokens", 0), language),
                prompt=number(usage.get("prompt_tokens", 0), language),
                completion=number(usage.get("completion_tokens", 0), language),
                requests=requests,
                s="" if requests == 1 else "s",
            )
        )
    lines.append(" ".join(meta))
    lines.append("")
    lines.append(copy["footer"])
    return "\n".join(lines) + "\n"


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("review")
    parser.add_argument("--sha", required=True)
    parser.add_argument("--language", choices=sorted(COPY), default="en")
    parser.add_argument("--diff-bytes", type=int, default=0)
    parser.add_argument("--reviewed-bytes", type=int, default=0)
    args = parser.parse_args()
    with open(args.review, encoding="utf-8") as handle:
        review = json.load(handle)
    sys.stdout.write(render(review, sha=args.sha, language=args.language, diff_bytes=args.diff_bytes, reviewed_bytes=args.reviewed_bytes))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
