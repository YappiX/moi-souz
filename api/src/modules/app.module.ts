import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { PrismaService } from '../prisma.service';
import { PostsModule } from './posts/posts.module';
import { UploadsModule } from './uploads/uploads.module';

@Module({
  imports: [ConfigModule.forRoot({ isGlobal: true }), PostsModule, UploadsModule],
  providers: [PrismaService],
})
export class AppModule {}