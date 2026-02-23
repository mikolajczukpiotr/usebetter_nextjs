import { withTenant } from "@usebetterdev/tenant/next";
import { getContext } from "@usebetterdev/tenant";
import { tenant } from "@/lib/tenant";

export const GET = withTenant(tenant, async () => {
  const db = tenant.getDatabase();
  if (!db) return Response.json({ error: "No tenant context" }, { status: 500 });
  const projects = await db.project.findMany();
  return Response.json(projects);
});

export const POST = withTenant(tenant, async (request) => {
  const body = await request.json();
  const ctx = getContext();
  const db = tenant.getDatabase();
  if (!db || !ctx) return Response.json({ error: "No tenant context" }, { status: 500 });
  const project = await db.project.create({
    data: { ...body, tenantId: ctx.tenantId },
  });
  return Response.json(project, { status: 201 });
});
