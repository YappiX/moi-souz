'use client';
import { useState } from 'react';
import { api } from '@/lib/api';
import { EditorContent, useEditor } from '@tiptap/react';
import StarterKit from '@tiptap/starter-kit';

export default function NewPost() {
  const [title, setTitle] = useState('');
  const editor = useEditor({ extensions: [StarterKit], content: '<p>Текст…</p>' });
  async function submit() {
    const content = editor?.getJSON();
    await api.post('/posts', { title, content, targetOrgIds: [] });
    window.location.href = '/posts';
  }
  return (
    <div>
      <h1>Новый пост</h1>
      <input placeholder="Заголовок" value={title} onChange={e=>setTitle(e.target.value)} />
      <div style={{ border: '1px solid #ccc', padding: 8, marginTop: 8 }}>
        <EditorContent editor={editor} />
      </div>
      <button onClick={submit} style={{ marginTop: 12 }}>Опубликовать</button>
    </div>
  );
}