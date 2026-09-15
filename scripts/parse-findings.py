#!/usr/bin/env python3
# SPDX-License-Identifier: LicenseRef-QOSL-1.0
# Copyright (c) 2026 Quavern
# This file is subject to the Quavern Open Source License, version 1.0.
# A copy is available at https://oss.quavern.com/licences/qosl/1.0/
"""Read a `marl exec --json` report and write the normalised review.

    parse-findings.py REPORT.json > review.json

review.json is {"status": "ok"|"unparsed"|"error", "findings": [...], "summary": str,
"raw": str, "error": {"code", "message"} | null, "usage": {...}, "requests": int}.
Findings are validated one by one: an entry without a file, a known severity or a
problem is dropped, never guessed.
"""

from __future__ import annotations

import json
import re
import sys

SEVERITIES = ("high", "medium", "low")


def _object_in(text: str):
    """The review object in the model's answer: the whole text, a fenced block, or the
    outermost {...} span. Returns None when nothing parses."""
    candidates = [text.strip()]
    fenced = re.findall(r"```(?:json)?\s*(.*?)```", text, flags=re.DOTALL)
    candidates.extend(block.strip() for block in fenced)
    start, end = text.find("{"), text.rfind("}")
    if 0 <= start < end:
        candidates.append(text[start : end + 1])
    for candidate in candidates:
        try:
            value = json.loads(candidate)
        except ValueError:
            continue
        if isinstance(value, dict) and isinstance(value.get("findings"), list):
            return value
    return None


def _clean(entry) -> dict | None:
    if not isinstance(entry, dict):
        return None
    severity = str(entry.get("severity") or "").strip().lower()
    file = str(entry.get("file") or "").strip()
    problem = str(entry.get("problem") or "").strip()
    if severity not in SEVERITIES or not file or not problem:
        return None
    try:
        line = int(entry.get("line")) if entry.get("line") not in (None, "") else None
    except (TypeError, ValueError):
        line = None
    return {
        "file": file,
        "line": line if line and line > 0 else None,
        "severity": severity,
        "problem": problem,
        "fix": str(entry.get("fix") or "").strip(),
    }


def parse(report: dict) -> dict:
    review = {
        "status": "ok",
        "findings": [],
        "summary": "",
        "raw": "",
        "error": None,
        "usage": report.get("usage") or {},
        "requests": int(report.get("requests") or 0),
    }
    error = report.get("error")
    if error:
        review["status"] = "error"
        code = str(error.get("code") or "")
        message = str(error.get("message") or "")
        if code and message.startswith(code):
            message = message[len(code):].lstrip(" ·:-")
        review["error"] = {"code": code, "message": message}
        return review
    result = str(report.get("result") or "")
    value = _object_in(result)
    if value is None:
        review["status"] = "unparsed"
        review["raw"] = result
        return review
    findings = [clean for clean in (_clean(entry) for entry in value["findings"]) if clean]
    findings.sort(key=lambda item: (SEVERITIES.index(item["severity"]), item["file"], item["line"] or 0))
    review["findings"] = findings
    review["summary"] = str(value.get("summary") or "").strip()
    return review


def main() -> int:
    try:
        with open(sys.argv[1], encoding="utf-8") as handle:
            report = json.load(handle)
    except (OSError, ValueError, IndexError):
        report = {"error": {"code": "REVIEW-0001", "message": "marl exec produced no readable report"}}
    json.dump(parse(report), sys.stdout, ensure_ascii=False)
    sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
