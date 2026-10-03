# TypeScript

## Scope and Simplicity

- Use overloads, conditional types, mapped types, and complex generic helpers only when they are necessary for type safety, reduce repeated code, or provide other quantifiable improvements.
- Use `const` by default, `let` only when reassigned, and never `var`.
- Prefer `unknown` over `any` when the type is not yet known, and narrow it at the boundary.
- Prefer `satisfies` when validating object shapes without losing inference.
- Avoid type assertions (`as`) and non-null assertions (`!`) when control-flow narrowing or better data modeling can express the same intent.

```ts
// Do
type Route = {
  title: string;
  path: string;
};

// assume used >3 times
function normalizeSlug(slug: string): string {
  return slug.trim().toLowerCase();
}

function buildRoute(title: string): Route {
  const slug = normalizeSlug(title);
  const route = {
    title,
    path: `/${slug}`,
  } satisfies Route;
  return route;
}

// Don't
class RouteBuilder {
  build(title: string): Route {
    return {
      title,
      path: `/${title.trim().toLowerCase()}`,
    };
  }
}
```

## Declaration Order

- Use this file order: imports, exported types/interfaces, local types, module constants, small pure helpers, larger functions, classes, exports if needed.
- Use dynamic `import()` only when a dependency is truly lazy, optional, or environment-specific.

```ts
// Do
import { formatDate } from './date';

type RouteInfo = {
  title: string;
  date: Date;
  path: string;
};

const defaultBasePath = '/posts';

// assume used >3 times
function normalizeSlug(slug: string): string {
  return slug.trim().toLowerCase();
}

function routePath(title: string): string {
  return `${defaultBasePath}/${normalizeSlug(title)}`;
}

export function buildRoute(title: string, date: Date): RouteInfo {
  return {
    title,
    date,
    path: routePath(title),
  };
}

export function formatRouteDate(route: RouteInfo): string {
  return formatDate(route.date);
}
```

## Data Shapes

- For stable structured data, prefer `type` by default, including for named object shapes in application code.
- Use `interface` only when the intention is extension or implementation by other code, or when defining a library API where that openness is part of the contract.
- Prefer `type` for unions, tuples, mapped types, conditional types, function types, and other aliases.

```ts
// Do
function splitMdAndYaml(data: string): [md: string, yaml: SimpleYaml] {
  return [data, new SimpleYaml()];
}

const [md, yaml] = splitMdAndYaml(src);

type RouteInfo = {
  title: string;
  date: Date;
  uri: string;
};

routes.sort((a, b) => a.date.getTime() - b.date.getTime());
for (const route of routes) {
  console.log(route.title, '->', route.uri);
}

interface RoutePlugin {
  register(path: string): void;
}

// Don't
type ParsedMarkdown = {
  md: string;
  yaml: SimpleYaml;
};

function splitMdAndYamlBad(data: string): ParsedMarkdown {
  return { md: data, yaml: new SimpleYaml() };
}
```

## Naming

- Use `UpperCamelCase` for types, interfaces, classes, enums, and React components.
- Use `lowerCamelCase` for variables, parameters, functions, methods, and properties.
- Prefer `lowerCamelCase` for most module constants. Reserve `UPPER_SNAKE_CASE` for true cross-module or protocol-level constants such as environment keys or wire-format tokens.
- Avoid `I` prefixes on interfaces unless interoperating with an existing external API that already uses them.
- Use `find` or `findIndex` for returning an item or position, and `includes`, `has`, or `contains` for returning a boolean, matching the data structure and the standard library.
- If both mutating and copy-returning forms exist, use pairs such as `sort` / `toSorted`, `reverse` / `toReversed`, and `splice` / `toSpliced` when the runtime target supports them.
- If a getter or setter is needed, prefer property accessors only for cheap, side-effect-free access. Use `getFoo` and `setFoo` when the operation has side effects, is not `O(1)`, or is otherwise more than simple field access.

```ts
// Do
function parseUrl(url: string): URL {
  return new URL(url);
}

function checkHttpHeader(header: string): boolean {
  return header.includes(':');
}

function fileExists(path: string): boolean {
  return path.length > 0;
}

function addRoute(routes: Route[], route: Route): void {
  routes.push(route);
}

function createRoute(title: string): Route {
  return { title, path: `/${title}` };
}

// Don't
function parseURL(url: string): URL {
  return new URL(url);
}

function checkHTTPHeader(header: string): boolean {
  return header.includes(':');
}

function existsFile(path: string): boolean {
  return path.length > 0;
}

function appendRoute(routes: Route[], route: Route): void {
  routes.push(route);
}
```

## Formatting

- Use 2 spaces for indentation.
- For multiline template literals, start the content on the next line.

```ts
// Do
const xs = data.slice(0, count);
const msg = `
hello
world
`;

const route = {
  title: 'Hello',
  path: '/hello',
};

// Don't
const msgBad = `hello
world
`;
```
