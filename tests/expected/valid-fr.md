<!-- marl-review -->
### Marl Review

Two defects, one of them in token checks.

| Gravité | Emplacement | Problème | Correction |
| --- | --- | --- | --- |
| haute | `src/auth.py:17` | The token comparison uses == and leaks timing. | Use hmac.compare_digest. |
| basse | `src/pay.py:42` | The retry loop never sleeps \| so it spins. | Sleep with backoff between attempts. |

Commit relu : `0123456789ab`. Jetons : 12 345 (11 000 en entrée, 1 345 en sortie) sur 3 requêtes.

Marl Review · Quavern
