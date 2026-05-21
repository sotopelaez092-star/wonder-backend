CREATE TABLE IF NOT EXISTS events (
  id TEXT PRIMARY KEY,
  type TEXT NOT NULL DEFAULT 'event',
  page TEXT DEFAULT '',
  session_id TEXT DEFAULT '',
  properties TEXT DEFAULT '{}',
  user_agent TEXT DEFAULT '',
  referer TEXT DEFAULT '',
  created_at TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_events_session ON events(session_id);
CREATE INDEX IF NOT EXISTS idx_events_type    ON events(type);
CREATE INDEX IF NOT EXISTS idx_events_created ON events(created_at);

CREATE TABLE IF NOT EXISTS waitlist (
  id TEXT PRIMARY KEY,
  contact TEXT NOT NULL,
  grade TEXT DEFAULT '',
  interest TEXT DEFAULT '',
  source TEXT DEFAULT '',
  preference TEXT DEFAULT '',
  full_url TEXT DEFAULT '',
  query TEXT DEFAULT '',
  utm_source TEXT DEFAULT '',
  utm_medium TEXT DEFAULT '',
  utm_campaign TEXT DEFAULT '',
  utm_content TEXT DEFAULT '',
  utm_term TEXT DEFAULT '',
  pack TEXT DEFAULT '',
  lesson TEXT DEFAULT '',
  session_id TEXT DEFAULT '',
  page TEXT DEFAULT '',
  user_agent TEXT DEFAULT '',
  referer TEXT DEFAULT '',
  created_at TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_waitlist_contact ON waitlist(contact);
CREATE INDEX IF NOT EXISTS idx_waitlist_created ON waitlist(created_at);

CREATE TABLE IF NOT EXISTS admin_sessions (
  token TEXT PRIMARY KEY,
  created_at TEXT NOT NULL,
  expires_at TEXT NOT NULL
);
