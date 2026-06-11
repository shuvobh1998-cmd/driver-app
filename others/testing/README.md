# Testing — no-QA team's safety net

You have no dedicated QA. These docs codify "what gets tested, how, and by whom" so quality doesn't slip.

## Read these

| File                                           | Purpose                                          |
| ---------------------------------------------- | ------------------------------------------------ |
| [`TESTING_STRATEGY.md`](TESTING_STRATEGY.md)   | Test pyramid, coverage targets, when to escalate |
| [`BACKEND_TEST_PLAN.md`](BACKEND_TEST_PLAN.md) | Jest unit + Supertest e2e + k6 load              |
| [`ADMIN_TEST_PLAN.md`](ADMIN_TEST_PLAN.md)     | Manual smoke checklist + optional Playwright     |
| [`MOBILE_TEST_PLAN.md`](MOBILE_TEST_PLAN.md)   | Widget tests + integration tests + device matrix |

## Guiding principle

> No test = no merge for critical paths. Smoke checklist run before every sprint demo.

"Critical paths" defined per surface in the strategy doc.
