import 'dotenv/config';
import { Hono } from 'hono';
import { cors } from 'hono/cors';
import { logger } from 'hono/logger';
import { serve } from '@hono/node-server';

import { events } from './routes/events.js';
import { waitlist } from './routes/waitlist.js';
import { courses } from './routes/courses.js';
import { auth } from './routes/admin/auth.js';
import { leads } from './routes/admin/leads.js';
import { stats } from './routes/admin/stats.js';
import { adminCourses } from './routes/admin/courses.js';
import { cleanExpiredSessions } from './lib/auth.js';

const app = new Hono();
app.use('*', logger());
app.use('*', cors({ origin: '*', allowMethods: ['GET','POST','PUT','DELETE','OPTIONS','PATCH'] }));

app.get('/api/health', (c) => c.json({ ok: true, app: 'wonder-backend', ts: new Date().toISOString() }));

app.route('/api/events', events);
app.route('/api/waitlist', waitlist);
app.route('/api/courses', courses);

app.route('/api/admin/auth', auth);
app.route('/api/admin/leads', leads);
app.route('/api/admin/stats', stats);
app.route('/api/admin/courses', adminCourses);

// hourly cleanup
setInterval(cleanExpiredSessions, 3600 * 1000);

const port = Number(process.env.PORT || 3001);
const host = process.env.HOST || '127.0.0.1';

serve({ fetch: app.fetch, port, hostname: host }, (info) => {
  console.log(`[wonder-backend] listening on http://${info.address}:${info.port}`);
});
