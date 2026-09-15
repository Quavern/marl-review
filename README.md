# Marl Review

A GitHub Action that reviews a pull request with Marl Code and posts **one** comment: the concrete defects the diff introduces (bugs, security problems, data loss, broken contracts), each with its file, line, severity, problem and fix. The comment is updated in place on every push. Style remarks and praise are not part of the output.

## Use it

```yaml
name: Marl Review

on:
  pull_request:

permissions:
  contents: read
  pull-requests: write

jobs:
  review:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - uses: Quavern/marl-review@v1
        with:
          token: ${{ secrets.MARL_API_KEY }}
```

Store a Marl API token as the repository secret `MARL_API_KEY`. An organisation service token (`qv_s_…`, created on my.quavern.com) is recommended: it is not tied to one person and follows the organisation's Marl Code policy.

| Input | Default | |
| --- | --- | --- |
| `token` | — | Marl API token. When empty, the review is skipped with a notice. |
| `version` | `latest` | Marl Code release to install. |
| `base` | the pull request's base commit | Commit to diff against. |
| `max-diff-bytes` | `200000` | A larger diff is cut; the comment gives both sizes. |
| `language` | `en` | `en` or `fr`, for the comment and the findings. |
| `fail-on` | `none` | `high` fails the job when a high-severity defect is found. |
| `github-token` | the workflow token | Writes the comment (`pull-requests: write`). |
| `comment-author` | `github-actions[bot]` | Only this author's earlier Marl Review comment is updated. |

Outputs: `findings` (JSON list) and `report` (status, findings, summary, usage).

## What happens in a run

1. Marl Code is downloaded from `dl.quavern.net`, from the release manifest, and its SHA-256 is checked.
2. The diff between the base and the head of the pull request is written to a file, cut to `max-diff-bytes`.
3. `marl exec --json` runs once, read-only: no approval flag is passed, so every file change or command the model asks for is refused. The instruction is fixed and lives in [`prompts/review.txt`](prompts/review.txt); the diff is attached as data on standard input, and the instruction tells the model that the diff and the repository are untrusted text, never instructions.
4. The answer is checked: findings without a file, a known severity or a problem are dropped. If the answer is not the expected JSON, the comment shows it as returned instead of guessing.
5. The comment starting with `<!-- marl-review -->` and written by `comment-author` is updated, or created when there is none.

## Pull requests from forks

GitHub does not give repository secrets to workflows triggered by pull requests from forks, so those runs have no token and the review is skipped with a notice. This is deliberate: Marl Review does not support `pull_request_target`, which would run with your secrets on code you have not reviewed.

## Cost

Each run is one Marl Code session charged to the token's Marl plan, in the same five-hour and weekly credit windows as any other use. The comment states the tokens used. A run with a large diff costs more; lower `max-diff-bytes` to cap it.

## Privacy

The diff, and any repository file Marl Code reads for context, is sent to the Marl API at `api.quavern.ai` and processed under the [Quavern privacy policy](https://quavern.com/privacy.html). Quavern does not use it to train foundation models. Do not run Marl Review on repositories whose content may not leave your organisation.

## Licence

The files of this repository are under the Quavern Open Source License, version 1.0 (`LicenseRef-QOSL-1.0`), a draft under legal review: see [`LICENSE.md`](LICENSE.md). Marl Code itself is not open source; this action downloads its published binary.
