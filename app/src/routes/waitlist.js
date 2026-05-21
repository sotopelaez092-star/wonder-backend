import { Hono } from 'hono';
import { db, nowIso, hashId } from '../db.js';

export const waitlist = new Hono();

waitlist.post('/', async (c) => {
  let body;
  try { body = await c.req.json(); } catch { body = {}; }

  const contact = String(body?.contact || '').trim();
  if (!contact) return c.json({ ok: false, error: 'contact is required' }, 400);

  const id = await hashId({ contact, at: Date.now() });
  const rec = {
    id,
    contact: contact.slice(0, 200),
    grade: String(body?.grade || '').slice(0, 64),
    interest: String(body?.interest || '').slice(0, 200),
    source: String(body?.source || '').slice(0, 200),
    preference: String(body?.preference || '').slice(0, 200),
    full_url: String(body?.full_url || '').slice(0, 1000),
    query: String(body?.query || '').slice(0, 500),
    utm_source: String(body?.utm_source || '').slice(0, 100),
    utm_medium: String(body?.utm_medium || '').slice(0, 100),
    utm_campaign: String(body?.utm_campaign || '').slice(0, 100),
    utm_content: String(body?.utm_content || '').slice(0, 100),
    utm_term: String(body?.utm_term || '').slice(0, 100),
    pack: String(body?.pack || '').slice(0, 100),
    lesson: String(body?.lesson || '').slice(0, 100),
    session_id: String(body?.session_id || '').slice(0, 64),
    page: String(body?.page || '').slice(0, 512),
    user_agent: (c.req.header('user-agent') || '').slice(0, 512),
    referer: (c.req.header('referer') || '').slice(0, 512),
    created_at: nowIso(),
  };

  db.prepare(`INSERT INTO waitlist
    (id, contact, grade, interest, source, preference, full_url, query,
     utm_source, utm_medium, utm_campaign, utm_content, utm_term,
     pack, lesson, session_id, page, user_agent, referer, created_at)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`)
    .run(rec.id, rec.contact, rec.grade, rec.interest, rec.source, rec.preference,
         rec.full_url, rec.query,
         rec.utm_source, rec.utm_medium, rec.utm_campaign, rec.utm_content, rec.utm_term,
         rec.pack, rec.lesson, rec.session_id, rec.page, rec.user_agent, rec.referer,
         rec.created_at);

  return c.json({ ok: true, lead_id: id }, 202);
});
