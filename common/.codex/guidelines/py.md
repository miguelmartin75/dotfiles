# Python Code Guidelines

## Simplicity

- Prefer simple direct code and solutions over abstractions, unless clearly repeated many times, e.g. >3x
    - Three similar lines is better than a premature abstraction.
    - Add helpers only when the logic is used more than 3 times. When judging whether a helper is warranted, shared usage from tests counts toward that threshold.
    - Avoid trivial helpers that perform little to no computation unless they are used frequently and materially improve readability.
- Prefer simpler language features. Only reach for metaprogramming, framework indirection, or other advanced language specific constructs when they provide a quantifiable benefit.
    - Prefer plain functions and direct construction over builders, helper classes, or framework-style indirection unless stateful behavior, lifecycle management, polymorphism, or another concrete need justifies the abstraction.
- Keep Cyclic Code Complexity at a moderate level; if a function gets too long or branchy, refactor it into smaller parts.
    - When performing this refactor: take out the biggest chunks first in greedy manner until Cyclic Code Complexity is back to moderate; don't immediately refactor everything into helpers.
- Prefer the standard library and built-in platform APIs over third-party dependencies unless there is a clear justification.

## Scope and Simplicity

- Keep changes small and direct.
- Prefer simple direct code and solutions over abstractions, unless clearly repeated many times (>3x).
- Three similar lines is better than a premature abstraction.
- Prefer plain functions and direct construction over builders, helper classes, or framework-style indirection unless stateful behavior, lifecycle management, polymorphism, or another concrete need justifies the abstraction.
- Avoid trivial helpers that perform little to no computation unless they are used frequently and materially improve readability.
- Don't declare a constant if it is only used <3x. Magic constants are NOT scary.
- Prefer the simpler language feature or control-flow shape. Only reach for metaprogramming, framework indirection, or other advanced constructs when they provide a quantifiable benefit.
- Only use a more complex language construct such as a decorator, descriptor, metaclass, or dynamic attribute hook when it is necessary for correctness, measurable performance, meaningful LOC reduction, or another quantifiable improvement.

```py
# Do
# assume used >3 times
def normalize_slug(slug: str) -> str:
    return slug.strip().lower()

def build_route(title: str) -> dict[str, str]:
    slug = normalize_slug(title)
    return {"title": title, "path": f"/{slug}"}

# Don't
class RouteBuilder:
    def build(self, title: str) -> dict[str, str]:
        return {"title": title, "path": f"/{title.strip().lower()}"}
```

## Declaration Order

- Keep declarations topologically sorted where practical.
- Keep imports at module scope by default. Use local, lazy, or type-only imports only when they materially improve correctness, optionality, startup cost, or cycle management.
- Define helpers close enough to their usage that a reader can scan top-to-bottom without jumping.
- If declarations become mutually recursive or force awkward forward references, keep them adjacent only when a simpler refactor is not practical, and otherwise refactor to break the cycle.
- In Python modules, use this file order: imports, exported types, module constants, small pure helpers, larger functions, classes, module entry point if needed.
- Use `if TYPE_CHECKING:` for annotation-only imports or cycle avoidance instead of importing type-only modules at runtime.
- Do not use `from __future__ import annotations`; treat it as deprecated functionality and use modern Python annotations directly.

```py
# Do

# assume used >3 times
def normalize_slug(slug: str) -> str:
    return slug.strip().lower()

def route_path(title: str) -> str:
    return f"/posts/{normalize_slug(title)}"

def build_route(title: str) -> dict[str, str]:
    return {"title": title, "path": route_path(title)}

if __name__ == "__main__":
    from app.cli import main

    raise SystemExit(main())

# Don't
from app.cli import main

def build_route(title: str) -> dict[str, str]:
    return {"title": title, "path": route_path(title)}

DEFAULT_BASE_PATH = "/posts"

def route_path(title: str) -> str:
    return f"{DEFAULT_BASE_PATH}/{normalize_slug(title)}"

def normalize_slug(slug: str) -> str:
    return slug.strip().lower()
```

## Dependencies and Comments

- Do not add third-party dependencies unless they solve the problem directly.
- Prefer the standard library and built-in platform APIs over third-party dependencies unless there is a clear justification, such as measurable performance benefits, explicit instructions, or existing use in the same module.
- Keep comments brief and only where they add real clarity (where logic is unclear)
- Use docstrings for public APIs or non-obvious contracts, not to restate obvious code.

## Returns and Control Flow

- Prefer real control flow (if/elif/else/break) over early returns. Use early `return` only for real early exits, such as guard clauses, invalid input, empty data, or stopping a linear scan once the answer is found.
- Do not use `return` as a substitute for explicit branching when `if` / `else`, `switch`, `case`, or `match` would keep the alternatives clearer.
- Do not introduce a temporary variable only to immediately return it unchanged.
- In small callbacks, lambdas, comparators, or key functions, direct returns are fine.
- When a value is assembled across several steps, use a local variable and one final `return`.
- Preserve failure information required by the return contract.
- Catch only exceptions the operation is intended and able to handle. Let other failures propagate.
- When branches only select argument values for the same operation, select those values first and perform the operation once.
- When `None` represents absence, test with `is None` or `is not None` so valid falsey values retain their meaning.

For example, this parser must return both parsed numbers and rejected input strings.

```py
# Don't: the return contract loses rejected inputs.
def parse_numbers(values: list[str]) -> tuple[list[int], list[str]]:
    numbers: list[int] = []
    for value in values:
        try:
            numbers.append(int(value))
        except ValueError:
            pass

    return numbers, []
```

```py
# Do
def parse_numbers(values: list[str]) -> tuple[list[int], list[str]]:
    numbers: list[int] = []
    rejected: list[str] = []
    for value in values:
        try:
            numbers.append(int(value))
        except ValueError:
            rejected.append(value)

    return numbers, rejected
```

For example, this reader returns `None` for invalid integer text and lets file-read failures propagate.

```py
# Don't: file-read failures are also converted to None.
from pathlib import Path


def read_count(path: Path) -> int | None:
    try:
        return int(path.read_text())
    except Exception:
        return None
```

```py
# Do
from pathlib import Path


def read_count(path: Path) -> int | None:
    text = path.read_text()
    try:
        return int(text)
    except ValueError:
        return None
```

For example, select the format specification before formatting the number.

```py
# Don't: both branches perform the same operation.
def format_number(value: int, hexadecimal: bool) -> str:
    if hexadecimal:
        result = format(value, "x")
    else:
        result = format(value, "d")

    return result
```

```py
# Do
def format_number(value: int, hexadecimal: bool) -> str:
    if hexadecimal:
        spec = "x"
    else:
        spec = "d"

    return format(value, spec)
```

## Data Shapes

- Prefer named structured data for stable values that:
  - are stored or passed around as a named concept,
  - cross module or API boundaries,
  - have multiple independent call sites where field names materially improve clarity.
- Prefer tuples or other small local shapes for:
  - local temporary values,
  - return values that are immediately unpacked,
  - short-lived data used only at a small number of nearby call sites.
- Use named types for stable internal records; prefer `dataclass` in Python. Dataclasses themselves do not validate external input.
- Reuse existing types and parsing or serialization APIs when their contracts fit.
- Use dictionaries for lookups where keys identify entries, such as email addresses mapped to contacts. Use named records for defined fields describing one value, such as a contact's name and email.
- Compute cheap derived values from their current source instead of storing duplicate state that must be kept in sync.
- Do not convert a small local tuple-like result into a heavier named structure just for style clean-up if the caller immediately unpacks it.
    - When in doubt, keep the smaller, more local data shape.

A contact is a stable internal record shared between functions.

```py
# Don't
def format_contact(contact: dict[str, str]) -> str:
    return f"{contact['name']} <{contact['email']}>"
```

```py
# Do
from dataclasses import dataclass


@dataclass
class Contact:
    name: str
    email: str


def format_contact(contact: Contact) -> str:
    return f"{contact.name} <{contact.email}>"
```

```py
contact = Contact(name="Ada", email="ada@example.com")
contacts_by_email: dict[str, Contact] = {contact.email: contact}
```

A small tuple is enough when the result is immediately unpacked.

```py
def split_title_and_body(source: str) -> tuple[str, str]:
    title, separator, body = source.partition("\n")

    return title, body


title, body = split_title_and_body("Title\nBody")
```

A rectangle's area is cheap to derive. Storing it separately leaves it stale
when the width changes.

```py
# Don't
from dataclasses import dataclass, field


@dataclass
class Rectangle:
    width: int
    height: int
    area: int = field(init=False)

    def __post_init__(self) -> None:
        self.area = self.width * self.height


rect = Rectangle(width=2, height=3)
rect.width = 4
print(rect.area)  # 6: stale after changing width.
```

```py
# Do
from dataclasses import dataclass


@dataclass
class Rectangle:
    width: int
    height: int

    @property
    def area(self) -> int:
        return self.width * self.height


rect = Rectangle(width=2, height=3)
rect.width = 4
print(rect.area)  # 12: derived from the current dimensions.
```

## Naming

- Treat acronyms like normal words.
- Avoid vague prefixes and words that merely repeat context supplied by the enclosing module or type. Keep words that distinguish domain meanings or roles.
- Prefer standard abbreviations such as `dir`, `msg`, `arg`, `param`, `cfg`, `env`, `url`, `rect`, `coord`, `sym`, `lit`, `err`, and `opts`.
- Prefer subject-verb names, e.g. `file_exists`, `fileExists`, not `exists_file` or `existsFile`.
- For booleans, prefer names such as `is_ready`, `isReady`, `has_items`, `hasItems`, `can_write`, `canWrite`, and `should_retry`, `shouldRetry`.
- Make top-level declarations public only when they are part of the module's intended public API. Keep implementation details and internal module-local helpers private, using a leading underscore where that is the project convention.
- Error and exception types should end in `Error`.
- Prefer direct object construction when it keeps the code simple.
- Avoid the word `factory` in names. Use `create` for functions or methods that construct one logical value.
- Use `make` when the operation allocates many objects or builds a larger aggregate such as a collection, table, map, or buffer.
- Use names that distinguish returning a position or match (`find...`) from returning a boolean (`has...` or `contains...`).
- Prefer `add` over `append` for custom collection APIs.
- If both mutating and copy-returning forms exist, use names that make that distinction obvious.
- Prefer direct field or property access over trivial getters and setters.
- If an accessor is needed, prefer property syntax only for cheap, side-effect-free access. Use verb-prefixed methods when the operation has side effects or non-trivial cost.
- In Python, use `UpperCamelCase` for classes, dataclasses, enums, and exception types.
- Use `lower_snake_case` for variables, parameters, functions, methods, and modules.
- Use `UPPER_SNAKE_CASE` for module-level constants.
- For more complex construction logic, prefer free functions such as `create_route(...)` over `new_route(...)`.
- If a getter or setter is needed, use `@property` only for cheap, side-effect-free access. Use `get_foo` and `set_foo` when the operation has side effects, is not `O(1)`, or is otherwise more than simple field access.

```py
# Do
def parse_url(url: str) -> str: ...
def check_http_header(header: str) -> bool: ...
def file_exists(path: str) -> bool: ...
def add_route(routes: list[Route], route: Route) -> None: ...

class RouteError(Exception):
    pass

def create_route(title: str) -> Route: ...

# Don't
def parse_URL(url: str) -> str: ...
def check_HTTP_header(header: str) -> bool: ...
def exists_file(path: str) -> bool: ...
def append_route(routes: list[Route], route: Route) -> None: ...

class route_error(Exception):
    pass

def new_route(title: str) -> Route: ...
```

The `Job` type already supplies the job context. Keep `input` and `output`
because they distinguish the paths' roles.

```py
# Don't
from dataclasses import dataclass


@dataclass
class Job:
    job_name: str
    job_input_path: str
    job_output_path: str
```

```py
# Do
from dataclasses import dataclass


@dataclass
class Job:
    name: str
    input_path: str
    output_path: str
```

## Formatting

- Let the formatter handle mechanical spacing, but do not use formatting to hide control flow or overly dense code.
- For multiline string literals, start the content on the next line.
- Prefer multiline formatting once literals, parameter lists, function calls, or props stop fitting comfortably on one line.
- Follow language-specific indentation and syntax-spacing conventions.
- Use 4 spaces for indentation.
- Write slices without spaces around the colon, e.g. `data[:count]` and `data[i:-3]`.
- A `None` slice stop means through the end: `xs[idx:None]` is equivalent to `xs[idx:]`.

```py
xs = [10, 20, 30, 40]
xs[1:None]  # [20, 30, 40]
xs[1:]  # [20, 30, 40]
```

```py
# Do
xs = data[:count]
tail = data[i:-3]
msg = """
hello
world
"""

route = {
    "title": "Hello",
    "path": "/hello",
}

# Don't
xs = data[: count]
tail = data[i : -3]
msg = """hello
world
"""
```
