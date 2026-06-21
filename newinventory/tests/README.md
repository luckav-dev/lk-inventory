# Tests

Unit tests for the pure inventory logic (slot model, transfers, container
weight). They run under stock Lua 5.4 with light mocks and are **not** loaded by
FiveM (the `tests/` folder isn't referenced by `fxmanifest.lua`).

```bash
cd newinventory
LK_ROOT=. lua5.4 tests/run.lua
```

Covered: add/stack/no-stack, weight limits, partial/full remove, move into
empty, split, stack-merge, swap, cross-inventory weight rejection, container id
assignment, nested/self-nested container rejection, and container weight
propagation.

These cover the server-authoritative core. Framework, NUI, drops, weapons and
vehicle logic depend on FiveM natives and still need a live-server pass.
