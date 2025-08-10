import { PrismaClient } from '@prisma/client';
const prisma = new PrismaClient();

async function main() {
  const u = await prisma.user.upsert({
    where: { email: 'admin@example.com' },
    update: {},
    create: {
      email: 'admin@example.com',
      fullName: 'Администратор',
      passwordHash: '$2b$10$9E2C3wS7kqSlZCwYyA3mA.uZI1pQe6J.0pQX0Gx7Nn1c4v1v2o5r6' // bcrypt('admin')
    }
  });

  await prisma.post.create({
    data: {
      authorId: u.id,
      title: 'Первый пост',
      content: { type: 'doc', content: [{ type: 'paragraph', content: [{ type: 'text', text: 'Здравствуйте!' }]}]},
      targetOrgIds: []
    }
  });
}

main().finally(() => prisma.$disconnect());