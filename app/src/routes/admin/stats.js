import { Hono } from 'hono';
import { db } from '../../db.js';
import { requireAdmin } from '../../lib/auth.js';

export const stats = new Hono();
stats.use('*', requireAdmin);

const FUNNEL = [
  ['visited',           'Any session'],
  ['pack_select',       'Pack selected'],
  ['lesson_tap',        'Lesson tapped'],
  ['register_success',  'Registered'],
  ['waitlist_success',  'Waitlist submitted'],
];

stats.get('/funnel', (c) => {
  // sessions = distinct session_id
  const totalSessions = db.prepare('SELECT COUNT(DISTINCT session_id) as n FROM events').get().n;

  const counts = FUNNEL.map(([type]) => {
    if (type === 'visited') return totalSessions;
    const n = db.prepare('SELECT COUNT(DISTINCT session_id) as n FROM events WHERE type = ?').get(type).n;
    return n;
  });
  const waitlistTotal = db.prepare('SELECT COUNT(*) as n FROM waitlist').get().n;

  return c.json({
    total_sessions: totalSessions,
    waitlist_total: waitlistTotal,
    funnel: FUNNEL.map(([type, label], i) => ({
      type, label,
      count: counts[i],
      conversion: i === 0 ? 1 : (counts[0] ? counts[i] / counts[0] : 0),
    })),
  });
});

stats.get('/timeline', (c) => {
  const days = Math.min(parseInt(c.req.query('days') || '14', 10), 90);
  const rows = db.prepare(`
    SELECT substr(created_at, 1, 10) as day,
           COUNT(*) as events,
           COUNT(DISTINCT session_id) as sessions
    FROM events
    WHERE created_at >= ?
    GROUP BY day ORDER BY day`)
    .all(new Date(Date.now() - days * 86400000).toISOString());
  const leads = db.prepare(`
    SELECT substr(created_at, 1, 10) as day, COUNT(*) as leads
    FROM waitlist WHERE created_at >= ? GROUP BY day`)
    .all(new Date(Date.now() - days * 86400000).toISOString());
  const leadMap = Object.fromEntries(leads.map(r => [r.day, r.leads]));
  return c.json(rows.map(r => ({ ...r, leads: leadMap[r.day] || 0 })));
});

stats.get('/recent-events', (c) => {
  const limit = Math.min(parseInt(c.req.query('limit') || '100', 10), 500);
  const rows = db.prepare('SELECT * FROM events ORDER BY created_at DESC LIMIT ?').all(limit);
  return c.json(rows);
});
