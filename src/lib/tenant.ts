import { PrismaClient } from "@/generated/prisma/client";
import { PrismaPg } from "@prisma/adapter-pg";
import { betterTenant } from "@usebetterdev/tenant";
import { prismaDatabase } from "@usebetterdev/tenant/prisma";

const adapter = new PrismaPg({ connectionString: process.env.RUNTIME_DATABASE_URL! });
const prisma = new PrismaClient({ adapter });

export const tenant = betterTenant({
  database: prismaDatabase(prisma),
  tenantResolver: { header: "x-tenant-id" },
});
