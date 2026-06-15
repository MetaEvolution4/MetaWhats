import { PrismaClient } from '@prisma/client';
const prisma = new PrismaClient();
prisma.message.findMany({orderBy: {created_at: 'desc'}, take: 5})
  .then(msgs => console.log(msgs.map(m => ({ct: m.ciphertext, ct_type: m.cipher_type}))))
  .finally(() => prisma.$disconnect());
