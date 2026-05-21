import { Hono } from 'hono';
import { db, nowIso, hashId } from '../db.js';

export const events = new Hono();

events.post('/', async (c) => {
  let body;
  try { body = await c.req.json(); } catch { body = {}; }

  const id = await hashId({ body, at: Date.now(), r: Math.random() });
  const record = {
    id,
    type: String(body?.type || body?.event || 'event').slice(0, 64),
    page: String(body?.page || '').slice(0, 512),
    session_id: String(body?.session_id || '').slice(0, 64),
    properties: JSON.stringify(body?.properties || {}).slice(0, 10000),
    user_agent: (c.req.header('user-agent') || '').slice(0, 512),
    referer: (c.req.header('referer') || '').slice(0, 512),
    created_at: nowIso(),
  };

  db.prepare(`INSERT INTO events
    (id, type, page, session_id, properties, user_agent, referer, created_at)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?)`)
    .run(record.id, record.type, record.page, record.session_id,
         record.properties, record.user_agent, record.referer, record.created_at);

  return c.json({ ok: true, event_id: id }, 202);
});
