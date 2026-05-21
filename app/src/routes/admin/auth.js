import { Hono } from 'hono';
import { createSession, deleteSession, isValidSession } from '../../lib/auth.js';

export const auth = new Hono();

auth.post('/login', async (c) => {
  let body; try { body = await c.req.json(); } catch { body = {}; }
  const password = String(body?.password || '');
  const expected = process.env.ADMIN_PASSWORD || '';
  if (!expected) return c.json({ error: 'ADMIN_PASSWORD not configured' }, 500);
  if (password !== expected) return c.json({ error: 'wrong password' }, 401);
  return c.json(createSession());
});

auth.post('/logout', (c) => {
  const auth = c.req.header('authorization') || '';
  const token = auth.startsWith('Bearer ') ? auth.slice(7) : '';
  deleteSession(token);
  return c.json({ ok: true });
});

auth.get('/me', (c) => {
  const a = c.req.header('authorization') || '';
  const token = a.startsWith('Bearer ') ? a.slice(7) : '';
  return c.json({ ok: isValidSession(token) });
});
