<!-- marl-review -->
### Marl Review

Two defects, one of them in token checks.

| Severity | Location | Problem | Fix |
| --- | --- | --- | --- |
| high | `src/auth.py:17` | The token comparison uses == and leaks timing. | Use hmac.compare_digest. |
| low | `src/pay.py:42` | The retry loop never sleeps \| so it spins. | Sleep with backoff between attempts. |

Reviewed commit `0123456789ab`. Tokens: 12,345 (11,000 prompt, 1,345 completion) over 3 requests.

Marl Review · Quavern
