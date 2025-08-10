import { Body, Controller, Get, Post } from '@nestjs/common';
import { PostsService } from './posts.service';

@Controller('posts')
export class PostsController {
  constructor(private readonly svc: PostsService) {}
  @Get() list() { return this.svc.list(); }
  @Post() create(@Body() body: any) { return this.svc.create(body); }
}