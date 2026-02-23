# Notes on `@usebetterdev/tenant` — Observations & Gotchas

> Package version: `0.4.0-beta.2` (pre-release)
> Evaluated: 2026-02-23

---

## 1. Package Name Is NOT `better-tenant`

The npm package is **`@usebetterdev/tenant`**, not `better-tenant`. The scoped name
caused confusion because the project is marketed as "Better Tenant" but the npm
package uses the `@usebetterdev` scope.

---

## 2. Node.js 22+ Required

The library enforces Node.js 22+ in its `engines` field. This is significantly
higher than the typical LTS baseline. Check `node --version` before attempting
to install or run — older Node versions will fail at runtime even if install
succeeds.

---

## 3. `@prisma/adapter-pg` Is a Hard Peer Dependency

The Prisma adapter (`@usebetterdev/tenant/prisma`) requires:
- `@prisma/client >= 7.0.0` ✓ (already in project)
- `@prisma/adapter-pg >= 7.0.0` ✗ (NOT yet installed)
- `pg` (the underlying Postgres driver) ✗ (NOT yet installed)

This means the `PrismaClient` used by the tenant module **must** be instantiated
with a `PrismaPg` driver adapter:

```typescript
const adapter = new PrismaPg({ connectionString: process.env.DATABASE_URL! });
const prisma = new PrismaClient({ adapter });
```

This is different from the standard singleton in `src/lib/prisma.ts` which uses
the default constructor. **Two separate PrismaClient instances** will coexist:
one for tenant routes (with `PrismaPg`) and one for non-tenant routes
(standard constructor).

---

## 4. Superuser Role Bypasses RLS — Critical Security Issue

PostgreSQL superusers bypass **all** RLS policies. If `DATABASE_URL` connects
as a superuser (common in dev environments using the default `postgres` user),
RLS provides **zero isolation**. This would silently allow cross-tenant data
leakage with no errors.

The app must connect as a non-superuser role. This needs explicit setup in the
database before the security model functions correctly.

---

## 5. Two-Client Pattern Is by Design

The library intentionally creates a second `PrismaClient` wrapping `PrismaPg`
rather than patching the existing singleton. The tenant-scoped client opens
interactive transactions and uses `SET LOCAL` for RLS context. The regular
singleton (`src/lib/prisma.ts`) is kept for global tables (`global_config`)
that have no RLS and don't need transaction scoping.

---

## 6. `getDatabase()` Returns `undefined` Outside Tenant Context

Calling `tenant.getDatabase()` outside a `withTenant()` handler (or `runAs()`/
`runAsSystem()` block) returns `undefined`. Every tenant route must guard:

```typescript
const db = tenant.getDatabase();
if (!db) return Response.json({ error: "No tenant context" }, { status: 500 });
```

Or use a wrapper that throws. There is no automatic error — you get `undefined`
silently.

---

## 7. Middleware Must Be Scoped — Not Applied Globally

The docs explicitly warn: *"The tenant middleware requires a valid tenant
identifier on every request it handles, so applying it too broadly will reject
requests to non-tenant routes."*

In Next.js, `withTenant()` is a per-route wrapper, not a global middleware.
This is actually the correct pattern for App Router — apply only to routes
that serve tenant data. Non-tenant routes (global config, auth, health checks)
must NOT use `withTenant()`.

---

## 8. RLS Migration Is Two-Phase

The library's CLI only generates the RLS SQL — it does NOT run migrations.
Prisma still owns the migration runner. The workflow is:

1. `prisma migrate dev` — applies schema (tables, columns)
2. `prisma migrate dev --create-only` — creates an empty migration file
3. `@usebetterdev/tenant-cli migrate -o <file>` — writes RLS SQL into that file
4. `prisma migrate dev` — applies the RLS migration

Skipping step 2-4 means tables exist but have no RLS policies — data is
**not isolated**.

---

## 9. Unique Constraints Must Be Tenant-Scoped

A `@@unique([email])` constraint would allow only one user with a given email
**across all tenants**. The correct pattern is `@@unique([tenantId, email])` —
each tenant can have their own user with the same email.

---

## 10. Pre-Release API — Versions Change Frequently

This package went through 7 versions in 9 days (0.1.0 → 0.4.0-beta.2,
Feb 13–22 2026). The API surface has changed between versions. Pinning to
an exact version (`0.4.0-beta.2`) is essential. Do not use `^` or `~`
version ranges.

---

## 11. Documentation URLs Redirect Frequently

Several doc pages redirect (e.g., `/tenant/prisma/` → `/tenant/guides/adapters/`,
`/tenant/next/` → `/tenant/guides/adapters/`). For LLM/agent usage the
recommended entry point is `https://docs.usebetter.dev/llms.txt` which provides
a stable summary with links.

---

## 12. `Tenant` Model Must Be `@@map("tenants")`

The library's CLI and internal queries expect the tenants table to be named
`tenants` (lowercase, plural). The Prisma model name can be `Tenant` but must
have `@@map("tenants")`.

---

## 13. `tenantId` on Related Tables Must Be `@db.Uuid` and `@map("tenant_id")`

The RLS policy SQL generated by the CLI references the `tenant_id` column by
its database column name (not the Prisma field name). The column must exist
as `tenant_id` in the database. Always use:

```prisma
tenantId  String  @map("tenant_id") @db.Uuid
```
