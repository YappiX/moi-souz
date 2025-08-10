import { Injectable } from '@nestjs/common';
import { PrismaClient } from '@prisma/client';
const prisma = new PrismaClient();

@Injectable()
export class PostsService {
  list() { return prisma.post.findMany({ orderBy: { createdAt: 'desc' }}); }
  create(data: any) { return prisma.post.create({ data }); }
}