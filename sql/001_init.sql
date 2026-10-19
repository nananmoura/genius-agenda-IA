CREATE TABLE IF NOT EXISTS processed_messages (
  message_id  TEXT PRIMARY KEY,
  usuario     TEXT NOT NULL,
  texto       TEXT,
  received_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS reminder_settings (
  usuario         TEXT PRIMARY KEY,
  offsets_minutes INTEGER[] NOT NULL DEFAULT '{1440,60,15}',
  timezone        TEXT NOT NULL DEFAULT 'America/Recife'
);

CREATE TABLE IF NOT EXISTS reminders (
  id                BIGSERIAL PRIMARY KEY,
  usuario           TEXT NOT NULL,
  calendar_event_id TEXT NOT NULL,
  event_title       TEXT,
  event_start       TIMESTAMPTZ NOT NULL,
  offset_minutes    INTEGER NOT NULL,
  remind_at         TIMESTAMPTZ NOT NULL,
  status            TEXT NOT NULL DEFAULT 'pending'
                    CHECK (status IN ('pending','sending','sent','cancelled','failed')),
  attempts          INTEGER NOT NULL DEFAULT 0,
  last_error        TEXT,
  sent_at           TIMESTAMPTZ,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (usuario, calendar_event_id, offset_minutes)
);

CREATE INDEX IF NOT EXISTS idx_reminders_due ON reminders (remind_at) WHERE status = 'pending';

CREATE TABLE IF NOT EXISTS outbox (
  id         BIGSERIAL PRIMARY KEY,
  usuario    TEXT NOT NULL,
  texto      TEXT NOT NULL,
  status     TEXT NOT NULL DEFAULT 'logged',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS error_log (
  id         BIGSERIAL PRIMARY KEY,
  workflow   TEXT,
  node       TEXT,
  message    TEXT,
  payload    JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);