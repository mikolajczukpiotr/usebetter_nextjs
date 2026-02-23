# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
npm run dev       # Start development server (http://localhost:3000)
npm run build     # Production build
npm run lint      # Run ESLint
```

There are no tests configured yet.

## Docker (local database)

PostgreSQL 17 + pgAdmin via Docker Compose.

```bash
docker compose up -d        # Start Postgres + pgAdmin in background
docker compose down         # Stop containers (data persisted in volume)
docker compose down -v      # Stop and delete all data (full reset)
```

- **PostgreSQL**: `localhost:5432` — superuser `postgres/postgres`, app user `app_user/app_password`, database `usebetter`
- **pgAdmin**: zainstaluj osobno jako aplikację desktopową z https://www.pgadmin.org/download/ i połącz na `localhost:5432`

### First-time setup

```bash
docker compose up -d
npx prisma migrate dev
npx prisma generate
```

### Connect pgAdmin to the database

In pgAdmin, add a new server:
- Host: `postgres` (Docker service name, use inside Docker network) or `host.docker.internal`
- Port: `5432`
- Username: `postgres`
- Password: `postgres`

### Prisma

```bash
npx prisma generate          # Regenerate Prisma client after schema changes
npx prisma migrate dev       # Create and apply a new migration
npx prisma migrate deploy    # Apply migrations in production
npx prisma studio            # Open Prisma Studio (database GUI)
```

## Architecture

This is a **Next.js 16 App Router** project using:
- **React 19** with the `src/app/` directory structure
- **Tailwind CSS v4** — configured via `postcss.config.mjs`; uses `@import "tailwindcss"` in `globals.css` (not `@tailwind` directives)
- **Prisma 7** with PostgreSQL — schema at `prisma/schema.prisma`; generated client outputs to `src/generated/prisma/` (gitignored, must be generated locally)
- **TypeScript** throughout

### Prisma Setup Notes

- `prisma.config.ts` (project root) configures the schema path, migrations path, and reads `DATABASE_URL` from environment via `dotenv`
- The generated Prisma client is output to `src/generated/prisma/` — import from there, not from `@prisma/client`
- `DATABASE_URL` = postgres superuser — used by Prisma CLI for migrations only
- `RUNTIME_DATABASE_URL` = `app_user` (non-superuser) — used by the app at runtime; required for RLS to work
- Use the singleton at `src/lib/prisma.ts` in Server Components and API routes: `import { prisma } from "@/lib/prisma"`

## Multi-Tenancy (`@usebetterdev/tenant`)

Row-Level Security via `@usebetterdev/tenant@0.4.0-beta.2`. Tenant is identified by the `x-tenant-id` request header.

### Two Prisma clients

| Client | File | Use for |
|---|---|---|
| `prisma` | `src/lib/prisma.ts` | Global tables (`global_config`) — no RLS |
| `tenant` | `src/lib/tenant.ts` | Tenant-aware tables (`users`, `projects`, `categories`) |

### Tenant-aware route pattern

```typescript
import { withTenant } from "@usebetterdev/tenant/next";
import { tenant } from "@/lib/tenant";

export const GET = withTenant(tenant, async () => {
  const db = tenant.getDatabase();
  if (!db) return Response.json({ error: "No tenant context" }, { status: 500 });
  const projects = await db.project.findMany(); // RLS filters automatically
  return Response.json(projects);
});
```

### Global (non-tenant) route pattern

```typescript
import { prisma } from "@/lib/prisma";

export async function GET() {
  const config = await prisma.globalConfig.findMany();
  return Response.json(config);
}
```

### CLI config

`better-tenant.config.json` at the project root lists tenant-aware tables for the CLI:

```json
{ "tenantTables": ["users", "projects", "categories"] }
```

### Migration workflow

```bash
# 1. Apply schema migration (tables)
npx prisma migrate dev --name add_multi_tenancy

# 2. Create empty migration for RLS
npx prisma migrate dev --create-only --name better_tenant_rls

# 3. Fill it with generated RLS SQL (replace TIMESTAMP with actual prefix)
npx @usebetterdev/tenant-cli migrate \
  -o prisma/migrations/TIMESTAMP_better_tenant_rls/migration.sql

# 4. Apply the RLS migration
npx prisma migrate dev
```

### Verification

```bash
# Check RLS policies
npx @usebetterdev/tenant-cli check --database-url $DATABASE_URL

# Seed a test tenant
npx @usebetterdev/tenant-cli seed --name "Test Corp" --database-url $DATABASE_URL
```

> **Important:** `DATABASE_URL` must connect as a **non-superuser** role — PostgreSQL superusers bypass RLS.
