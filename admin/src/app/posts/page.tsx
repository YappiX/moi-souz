'use client';
import { useEffect, useState } from 'react';
import { api } from '@/lib/api';

export default function PostsPage() {
  const [items, setItems] = useState<any[]>([]);
  useEffect(() => { api.get('/posts').then(r => setItems(r.data)); }, []);
  return (
    <div>
      <h1>Посты</h1>
      <a href="/posts/new">Создать</a>
      <ul>
        {items.map(p => (
          <li key={p.id}><b>{p.title}</b> — {new Date(p.createdAt).toLocaleString()}</li>
        ))}
      </ul>
    </div>
  );
}