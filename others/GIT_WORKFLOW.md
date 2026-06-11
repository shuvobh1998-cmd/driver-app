# Git Workflow

> Every feature commits to GitHub. Clean history, easy rollback, visible progress.

## Branches

| Branch | Purpose | Protected? |
|---|---|---|
| `main` | Always deployable. Auto-deploys to Railway/Vercel. | ✅ Yes — no direct push |
| `develop` | Integration of sprint features | ✅ Yes — PR only |
| `feature/sprint-<N>-<feature-slug>` | Per-feature branch | No |
| `fix/<issue-slug>` | Bug fixes outside sprint scope | No |
| `hotfix/<slug>` | Urgent prod fix; branches from `main`, merges back to both | No |

### Examples
- `feature/sprint-1-auth-otp`
- `feature/sprint-4-driver-matching`
- `fix/refresh-token-rotation`
- `hotfix/payment-webhook-signature`

## Commit messages

**Conventional Commits.** Format:

```
<type>(<scope>): <short summary in present tense>

<optional body explaining WHY>

<optional footer: refs, breaking changes>
```

### Types

| Type | Use for |
|---|---|
| `feat` | New feature visible to API consumer or admin user |
| `fix` | Bug fix |
| `chore` | Tooling, deps, configs, no behavior change |
| `refactor` | Internal restructure, no behavior change |
| `docs` | Documentation only |
| `test` | Tests only |
| `perf` | Performance improvement |
| `style` | Formatting only (rare — Prettier handles it) |
| `ci` | CI/CD config |
| `db` | Migration / schema change |

### Scopes

`auth`, `users`, `drivers`, `vehicles`, `kyc`, `maps`, `fare`, `rides`, `trips`, `payments`, `wallet`, `scheduled`, `chat`, `notifications`, `admin`, `webhooks`, `infra`

### Examples

```
feat(auth): add phone OTP verification endpoint

Uses Firebase Auth as the OTP provider. Returns access+refresh
JWT pair on successful verification. Refresh token is hashed
before storage.

Refs: SPRINT_01 task #3
```

```
fix(trips): prevent state transition from ENDED to CANCELLED

The trip state machine guard was missing this check, causing
a 500 when admins tried to cancel an already-ended trip.

Refs: support ticket #142
```

```
db(payments): add wallet_ledger table

Append-only ledger for driver earnings audit trail.
Includes balance_after column to allow point-in-time queries.
```

## PR rules

1. **Title:** same format as commit message subject
2. **Description must include:**
   - What changed (1-3 bullets)
   - Why (link to sprint task)
   - How to test (curl / Postman / admin URL)
   - Screenshots if admin UI changed
3. **CI must be green:** lint, type-check, unit, e2e
4. **Reviewer:** for solo backend work, self-review the diff before merge; add a Flutter dev as reviewer for any API contract change so they know
5. **Squash on merge** to keep `main` history clean
6. **Delete branch** after merge

## Sprint tagging

After a sprint is fully done:

```bash
git tag -a v0.X.0-sprint-X -m "Sprint X — <theme>"
git push origin v0.X.0-sprint-X
```

This gives a clean rollback point and lets you compare sprint diffs:

```bash
git log v0.1.0-sprint-1..v0.2.0-sprint-2 --oneline
```

## When something breaks `main`

1. Don't `git push --force` to `main` — ever. Even if you're sure.
2. Open a `hotfix/*` branch, fix, PR back to `main`, then merge `main` back into `develop`.
3. If a deploy went out broken, Railway/Vercel can roll back to previous deploy from their dashboard — use that *first*, then fix forward.

## .gitignore essentials

See `.gitignore` at repo root. Highlights:
- `.env`, `.env.local`, `.env.*.local` — never committed
- `node_modules/`, `dist/`, `.next/`, `coverage/`
- `*.log`, `.DS_Store`
- `prisma/migrations/dev/` — only `prisma/migrations/<timestamp>_*` committed

## .env.example must always exist

When you add a new env var to `.env`, add it to `.env.example` in the same commit. CI fails if `.env.example` is stale.

## Pre-commit hooks (recommended)

`husky` + `lint-staged` to run on staged files:
- ESLint --fix
- Prettier --write
- Type-check
- Conventional Commits lint (commitlint)

Set up in Sprint 1.
