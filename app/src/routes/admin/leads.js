import { Hono } from 'hono';
import { db } from '../../db.js';
import { requireAdmin } from '../../lib/auth.js';

export const leads = new Hono();

leads.use('*', requireAdmin);

leads.get('/', (c) => {
  const limit = Math.min(parseInt(c.req.query('limit') || '100', 10), 1000);
  const offset = parseInt(c.req.query('offset') || '0', 10);
  const q = (c.req.query('q') || '').trim();

  let rows;
  let total;
  if (q) {
    const like = `%${q}%`;
    rows = db.prepare(`SELECT * FROM waitlist
       WHERE contact LIKE ? OR utm_source LIKE ? OR utm_campaign LIKE ?
       ORDER BY created_at DESC LIMIT ? OFFSET ?`)
       .all(like, like, like, limit, offset);
    total = db.prepare('SELECT COUNT(*) as n FROM waitlist WHERE contact LIKE ? OR utm_source LIKE ? OR utm_campaign LIKE ?')
       .get(like, like, like).n;
  } else {
    rows = db.prepare('SELECT * FROM waitlist ORDER BY created_at DESC LIMIT ? OFFSET ?').all(limit, offset);
    total = db.prepare('SELECT COUNT(*) as n FROM waitlist').get().n;
  }

  return c.json({ rows, total, limit, offset });
});

leads.get('/export.csv', (c) => {
  const rows = db.prepare('SELECT * FROM waitlist ORDER BY created_at DESC').all();
  if (rows.length === 0) return c.text('contact,grade,interest,utm_source,utm_campaign,pack,lesson,created_at\n', 200, {
    'content-type': 'text/csv; charset=utf-8',
    'content-disposition': 'attachment; filename="waitlist.csv"',
  });
  const cols = ['contact','grade','interest','source','utm_source','utm_medium','utm_campaign','utm_content','utm_term','pack','lesson','referer','user_agent','created_at'];
  const esc = (v) => {
    const s = String(v ?? '');
    return /[",\n]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s;
  };
  const header = cols.join(',');
  const body = rows.map(r => cols.map(k => esc(r[k])).join(',')).join('\n');
  return c.text(header + '\n' + body + '\n', 200, {
    'content-type': 'text/csv; charset=utf-8',
    'content-disposition': 'attachment; filename="waitlist.csv"',
  });
});
