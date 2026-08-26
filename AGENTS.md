# AGENTS.md

## Code Guidelines

`CODE_GUIDELINES.md` adds non-overlapping style guidance.

- Keep changes small, direct, and focused on the task.
- Trust established upstream contracts, write the happy path directly, and add structure only when it earns its keep.
- Implement the required data flow in the fewest clear steps.
- Trust guarantees provided by the selected upstream system. Do not duplicate its validation unless this code owns that contract or must handle untrusted input.
- Preserve user-provided pseudocode structure when it is correct and complete.
- Start with one linear function. Inline one-use helpers.
- Add a helper only when logic is reused more than 3 times
- Avoid defensive branches unless a current requirement demonstrates the need.

## Compatibility

- Assume active development. Backwards compatibility is not required unless the task requires it.
- Update repository callers, tests, documentation, and examples with incompatible changes. Do not add compatibility shims, deprecated aliases, or migrations unless requested.
- Change external contracts, user-owned data formats, or production deployment contracts only when the task includes them.

## Python Design Rules

- Do not use leading underscores for repository-owned variables, fields, properties, methods, functions, classes, constants, or other declarations. Use public names directly instead of private backing fields with redundant properties. Python-required double-underscore hooks and private attributes required by third-party APIs are the only exceptions.
- Use conditionals or return values for expected outcomes. Raise exceptions for invalid boundary input, violated preconditions, I/O failures, or external failures. Catch only to recover, add context, or translate at a boundary.
- Use `list[T]` for variable-length homogeneous collections and fixed tuples for short-lived unpacked values. Use `dataclass` for named structured values stored, passed across boundaries, or used at multiple call sites.
- Prefer branching to early returns. Use early returns only for guards, successful searches, or measurable runtime improvements. Return simple expressions directly.
- When a return value must be assembled across multiple steps, use `result` as the default variable name and return it once.
- Order modules top-down by dependency: imports; constants and aliases; enums and classes; functions; entry point. Dependency order overrides grouping. Keep mutual recursion adjacent unless breaking the cycle is simpler.
- Keep literals inline for up to three same-meaning uses. Name them at four uses, or earlier to convey units, protocols, formats, sentinels, domain thresholds, or defaults.
- Prefer plain functions and direct construction. Add reuse abstractions only at four same-meaning uses; tests count. Use builders, frameworks, or metaprogramming only for concrete state, lifecycle, polymorphism, correctness, performance, or substantial code reduction.
- Large functions are acceptable for one operation. Do not create single-use helper functions.
- Before implementing functionality, check the standard library, then applicable runtime dependencies in `pyproject.toml`. Prefer the standard library; add a dependency only when neither meets the need.
- Use `msup` for dataclass serialization and CLI argument parsing in project code. Deviate only for unsupported requirements or explicit task instructions.

## Testing

- Do not introduce tests that cover source code content existence
- Aim to minimize the number of unit tests
