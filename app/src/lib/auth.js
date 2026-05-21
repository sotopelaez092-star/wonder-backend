import { db, nowIso } from '../db.js';
import crypto from 'node:crypto';

const SESSION_HOURS = 24 * 7;

export function makeToken() {
  return crypto.randomBytes(24).toString('base64url');
}

export function createSession() {
  const token = makeToken();
  const now = Date.now();
  const created = new Date(now).toISOString();
  const expires = new Date(now + SESSION_HOURS * 3600 * 1000).toISOString();
  db.prepare('INSERT INTO admin_sessions (token, created_at, expires_at) VALUES (?, ?, ?)')
    .run(token, created, expires);
  return { token, expires_at: expires };
}

export function isValidSession(token) {
  if (!token) return false;
  const row = db.prepare('SELECT expires_at FROM admin_sessions WHERE token = ?').get(token);
  if (!row) return false;
  return new Date(row.expires_at).getTime() > Date.now();
}

export function deleteSession(token) {
  if (!token) return;
  db.prepare('DELETE FROM admin_sessions WHERE token = ?').run(token);
}

export function cleanExpiredSessions() {
  db.prepare('DELETE FROM admin_sessions WHERE expires_at < ?').run(nowIso());
}

export function requireAdmin(c, next) {
  const auth = c.req.header('authorization') || '';
  const token = auth.startsWith('Bearer ') ? auth.slice(7) : (c.req.query('token') || '');
  if (!isValidSession(token)) return c.json({ error: 'unauthorized' }, 401);
  return next();
}
