const fs = require('fs');
const envFile = fs.readFileSync('.env', 'utf8');
const dbUrlMatch = envFile.match(/DATABASE_URL="([^"]+)"/);
if (dbUrlMatch) {
  process.env.DATABASE_URL = dbUrlMatch[1];
}

const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function run() {
  const statuses = await prisma.messageStatus.findMany({
    include: { message: { select: { content: true } } }
  });
  console.log('STATUSES:', JSON.stringify(statuses, null, 2));
  process.exit(0);
}

run();
