BEGIN;

INSERT INTO processed_messages (message_id, usuario, texto)
VALUES ('tg:teste-1', 'usuario-teste', 'oi')
ON CONFLICT (message_id) DO NOTHING;

INSERT INTO processed_messages (message_id, usuario, texto)
VALUES ('tg:teste-1', 'usuario-teste', 'oi')
ON CONFLICT (message_id) DO NOTHING;

DO $$
BEGIN
  IF (SELECT count(*) FROM processed_messages WHERE message_id = 'tg:teste-1') <> 1 THEN
    RAISE EXCEPTION 'FALHA: mensagem duplicada foi registrada duas vezes';
  END IF;
  RAISE NOTICE 'OK: mensagem duplicada e ignorada';
END $$;

PREPARE sync(text, text, text) AS
WITH ev AS (
  SELECT e->>'id' AS event_id, e->>'title' AS title, (e->>'start')::timestamptz AS start_at
  FROM jsonb_array_elements($2::jsonb) AS e
), off AS (
  SELECT unnest($3::int[]) AS offset_minutes
), wanted AS (
  SELECT ev.event_id, ev.title, ev.start_at, off.offset_minutes,
         ev.start_at - make_interval(mins => off.offset_minutes) AS remind_at
  FROM ev CROSS JOIN off
  WHERE ev.start_at - make_interval(mins => off.offset_minutes) > now() - interval '1 minute'
), up AS (
  INSERT INTO reminders (usuario, calendar_event_id, event_title, event_start, offset_minutes, remind_at)
  SELECT $1::text, event_id, title, start_at, offset_minutes, remind_at FROM wanted
  ON CONFLICT (usuario, calendar_event_id, offset_minutes) DO UPDATE
  SET event_title = EXCLUDED.event_title,
      remind_at = EXCLUDED.remind_at,
      status = CASE WHEN reminders.event_start <> EXCLUDED.event_start THEN 'pending' ELSE reminders.status END,
      event_start = EXCLUDED.event_start,
      updated_at = now()
  RETURNING 1
), canc AS (
  UPDATE reminders SET status = 'cancelled', updated_at = now()
  WHERE usuario = $1::text AND status = 'pending'
    AND event_start > now() AND event_start < now() + interval '25 hours'
    AND calendar_event_id NOT IN (SELECT event_id FROM ev)
  RETURNING 1
)
SELECT 1 AS ok;

SELECT (now() + interval '2 hours')::text AS inicio_a \gset
SELECT (now() + interval '3 hours')::text AS inicio_b \gset
SELECT jsonb_build_array(jsonb_build_object('id', 'evento-1', 'title', 'Reuniao', 'start', :'inicio_a'))::text AS eventos_a \gset
SELECT jsonb_build_array(jsonb_build_object('id', 'evento-1', 'title', 'Reuniao', 'start', :'inicio_b'))::text AS eventos_b \gset

EXECUTE sync('usuario-teste', :'eventos_a', '{1440,60,15}');

DO $$
BEGIN
  IF (SELECT count(*) FROM reminders WHERE usuario = 'usuario-teste' AND status = 'pending') <> 2 THEN
    RAISE EXCEPTION 'FALHA: deveriam existir 2 lembretes pendentes (1h e 15min)';
  END IF;
  IF EXISTS (SELECT 1 FROM reminders WHERE usuario = 'usuario-teste' AND offset_minutes = 1440) THEN
    RAISE EXCEPTION 'FALHA: lembrete de 24h nao deveria existir para evento a 2h';
  END IF;
  RAISE NOTICE 'OK: lembretes criados sem horarios no passado';
END $$;

EXECUTE sync('usuario-teste', :'eventos_a', '{1440,60,15}');

DO $$
BEGIN
  IF (SELECT count(*) FROM reminders WHERE usuario = 'usuario-teste') <> 2 THEN
    RAISE EXCEPTION 'FALHA: sincronizar de novo nao pode duplicar lembretes';
  END IF;
  RAISE NOTICE 'OK: sincronizacao repetida nao duplica';
END $$;

UPDATE reminders SET status = 'sent', sent_at = now()
WHERE usuario = 'usuario-teste' AND offset_minutes = 60;

EXECUTE sync('usuario-teste', :'eventos_a', '{1440,60,15}');

DO $$
BEGIN
  IF (SELECT status FROM reminders WHERE usuario = 'usuario-teste' AND offset_minutes = 60) <> 'sent' THEN
    RAISE EXCEPTION 'FALHA: lembrete ja enviado nao pode voltar a pendente';
  END IF;
  RAISE NOTICE 'OK: lembrete enviado nao e reenviado';
END $$;

EXECUTE sync('usuario-teste', :'eventos_b', '{1440,60,15}');

DO $$
BEGIN
  IF (SELECT count(*) FROM reminders WHERE usuario = 'usuario-teste') <> 2 THEN
    RAISE EXCEPTION 'FALHA: mudar o horario nao pode criar lembretes extras';
  END IF;
  IF (SELECT count(*) FROM reminders WHERE usuario = 'usuario-teste' AND status = 'pending') <> 2 THEN
    RAISE EXCEPTION 'FALHA: apos mudar o horario os dois lembretes devem voltar a pendente';
  END IF;
  IF (SELECT min(remind_at) FROM reminders WHERE usuario = 'usuario-teste') < now() + interval '1 hour 30 minutes' THEN
    RAISE EXCEPTION 'FALHA: lembrete continua no horario antigo';
  END IF;
  RAISE NOTICE 'OK: mudanca de horario atualiza os lembretes';
END $$;

EXECUTE sync('usuario-teste', '[]', '{1440,60,15}');

DO $$
BEGIN
  IF (SELECT count(*) FROM reminders WHERE usuario = 'usuario-teste' AND status = 'pending') <> 0 THEN
    RAISE EXCEPTION 'FALHA: evento excluido deixou lembretes pendentes';
  END IF;
  IF (SELECT count(*) FROM reminders WHERE usuario = 'usuario-teste' AND status = 'cancelled') <> 2 THEN
    RAISE EXCEPTION 'FALHA: lembretes do evento excluido deveriam estar cancelados';
  END IF;
  RAISE NOTICE 'OK: exclusao cancela lembretes pendentes';
END $$;

ROLLBACK;
