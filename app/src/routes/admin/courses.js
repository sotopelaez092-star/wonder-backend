import { Hono } from 'hono';
import fs from 'node:fs';
import path from 'node:path';
import AdmZip from 'adm-zip';
import { requireAdmin } from '../../lib/auth.js';

export const adminCourses = new Hono();
adminCourses.use('*', requireAdmin);

const COURSES_JSON = process.env.COURSES_JSON
  || path.resolve(process.cwd(), '../www/courses.json');
const COURSES_DIR = process.env.COURSES_DIR
  || path.resolve(process.cwd(), '../www/courses');

function readJson() {
  if (!fs.existsSync(COURSES_JSON)) return { packs: [] };
  return JSON.parse(fs.readFileSync(COURSES_JSON, 'utf8'));
}

function writeJson(data) {
  fs.mkdirSync(path.dirname(COURSES_JSON), { recursive: true });
  fs.writeFileSync(COURSES_JSON, JSON.stringify(data, null, 2) + '\n', 'utf8');
}

adminCourses.get('/', (c) => c.json(readJson()));

adminCourses.put('/', async (c) => {
  let body; try { body = await c.req.json(); } catch { return c.json({ error: 'bad json' }, 400); }
  if (!body || !Array.isArray(body.packs)) return c.json({ error: 'invalid shape' }, 400);
  writeJson(body);
  return c.json({ ok: true });
});

// List actual folders under www/courses/ so admin sees what exists
adminCourses.get('/folders', (c) => {
  if (!fs.existsSync(COURSES_DIR)) return c.json([]);
  const dirs = fs.readdirSync(COURSES_DIR, { withFileTypes: true })
    .filter(d => d.isDirectory() && !d.name.startsWith('_') && !d.name.startsWith('.'))
    .map(d => {
      const hasIndex = fs.existsSync(path.join(COURSES_DIR, d.name, 'index.html'));
      let size = 0;
      try {
        const walk = (dir) => {
          for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
            const p = path.join(dir, e.name);
            if (e.isFile()) size += fs.statSync(p).size;
            else if (e.isDirectory()) walk(p);
          }
        };
        walk(path.join(COURSES_DIR, d.name));
      } catch {}
      return { id: d.name, hasIndex, sizeBytes: size };
    });
  return c.json(dirs.sort((a, b) => a.id.localeCompare(b.id)));
});

// Upload a zip; unzip into www/courses/<id>/
adminCourses.post('/upload', async (c) => {
  const form = await c.req.parseBody();
  const file = form.file;
  const id = String(form.id || '').trim();

  if (!file || typeof file === 'string') return c.json({ error: 'file required' }, 400);
  if (!id || !/^[a-z0-9][a-z0-9_-]{1,63}$/i.test(id)) {
    return c.json({ error: 'id must be a-z 0-9 _ - (2-64 chars), no leading dash' }, 400);
  }

  const target = path.join(COURSES_DIR, id);
  if (fs.existsSync(target)) return c.json({ error: 'id already exists' }, 409);

  fs.mkdirSync(target, { recursive: true });
  const buf = Buffer.from(await file.arrayBuffer());
  let entries;
  try {
    const zip = new AdmZip(buf);
    entries = zip.getEntries();
    // basic safety: prevent path traversal
    for (const e of entries) {
      const p = path.resolve(target, e.entryName);
      if (!p.startsWith(target + path.sep) && p !== target) {
        fs.rmSync(target, { recursive: true, force: true });
        return c.json({ error: 'unsafe zip entry: ' + e.entryName }, 400);
      }
    }
    zip.extractAllTo(target, true);
  } catch (err) {
    fs.rmSync(target, { recursive: true, force: true });
    return c.json({ error: 'bad zip: ' + err.message }, 400);
  }

  // If zip wrapped everything in a single top-level folder, hoist contents up
  const items = fs.readdirSync(target);
  if (items.length === 1) {
    const sub = path.join(target, items[0]);
    if (fs.statSync(sub).isDirectory() && !fs.existsSync(path.join(target, 'index.html'))) {
      for (const f of fs.readdirSync(sub)) {
        fs.renameSync(path.join(sub, f), path.join(target, f));
      }
      fs.rmdirSync(sub);
    }
  }

  const hasIndex = fs.existsSync(path.join(target, 'index.html'));
  return c.json({ ok: true, id, path: `/courses/${id}/`, hasIndex, entries: entries.length });
});

adminCourses.delete('/folder/:id', (c) => {
  const id = c.req.param('id');
  if (!id || !/^[a-z0-9][a-z0-9_-]{1,63}$/i.test(id)) return c.json({ error: 'bad id' }, 400);
  const target = path.join(COURSES_DIR, id);
  if (!fs.existsSync(target)) return c.json({ error: 'not found' }, 404);
  fs.rmSync(target, { recursive: true, force: true });
  return c.json({ ok: true });
});
