# Integration tests — Task List

Detail for each item is in [plan.md](plan.md). Check items off as they land.
The v1 list lives in `tasks/todo.md` and is separate.

## Phase 1 — The stack
- [x] I1: Shared stack and the navigation journey, run both ways
- [x] I2: Failure screenshots

### Checkpoint: The stack
- [x] `fvm flutter test test/integration` and `fvm flutter test integration_test -d windows` both pass the navigation journey
- [x] `fvm flutter test` (no args) still passes and does not run `integration_test/`
- [x] A forced failure leaves a PNG in `build/integration_failures/`

## Phase 2 — Core journeys
- [x] I3: Send a request and history journeys
- [x] I4: Environments, variables and production journeys

### Checkpoint: Core journeys
- [x] analyze clean, both runners green, 614 existing tests untouched

## Phase 3 — Feature journeys
- [x] I5: Session journey
- [x] I6: Multi-step flow journey
- [x] I7: Hosts & notes journey

### Checkpoint: Feature journeys
- [x] analyze clean, both runners green

## Phase 4 — Whole-app journeys and wrap-up
- [ ] I8: Persistence and keyboard journeys
- [ ] I9: Break-on-purpose check, docs and final runs

### Checkpoint: Done
- [ ] All SPEC-integration-tests.md success criteria checked
