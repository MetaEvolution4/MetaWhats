const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function main() {
  console.log("USERS:");
  const users = await prisma.user.findMany();
  console.log(users.map(u => ({ id: u.id, phone: u.phone, name: u.name })));

  console.log("\nCONVERSATIONS:");
  const convs = await prisma.conversation.findMany({
    include: { participants: true }
  });
  console.log(JSON.stringify(convs, null, 2));
  
  console.log("\nMESSAGES:");
  const msgs = await prisma.message.findMany({
    select: { id: true, content: true, sender_id: true, conversation_id: true, created_at: true }
  });
  console.log(msgs.map(m => ({ content: m.content, sender: m.sender_id, conv: m.conversation_id })));
}

main().finally(() => prisma.$disconnect());
