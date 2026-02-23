import { prisma } from "@/lib/prisma";

export async function GET() {
  const config = await prisma.globalConfig.findMany();
  return Response.json(config);
}
