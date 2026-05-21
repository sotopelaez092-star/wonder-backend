import { Hono } from 'hono';
import fs from 'node:fs';
import path from 'node:path';

export const courses = new Hono();

const COURSES_JSON = process.env.COURSES_JSON
  || path.resolve(process.cwd(), '../www/courses.json');

function readCoursesJson() {
  try {
    if (!fs.existsSync(COURSES_JSON)) return { packs: [] };
    return JSON.parse(fs.readFileSync(COURSES_JSON, 'utf8'));
  } catch (err) {
    console.warn('[courses] failed to read', COURSES_JSON, err.message);
    return { packs: [] };
  }
}

courses.get('/', (c) => c.json(readCoursesJson()));
