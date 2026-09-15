# Contributing

- Run `tests/run.sh` before opening a pull request. It needs `bash`, `python3`, `jq`, `git` and `curl`, and no Marl token.
- A change to the comment updates the expectations with `UPDATE=1 tests/run.sh`; check the diff of `tests/expected/` by eye.
- A change to `prompts/review.txt` changes what every user pays for and receives: explain the reason and the effect in the pull request.
- Pull requests from forks are not reviewed by Marl Review itself (see README).

A contribution is received under the repository's licence (QOSL-1.0, section 2.5). Issues and pull requests are read; there is no guaranteed reply delay.
