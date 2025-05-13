-- 1) Usuarios
INSERT INTO users (user_id, full_name, email, phone, created_at)
SELECT
  i,
  'User ' || i,
  'user' || i || '@example.com',
  '555-' || LPAD((1000 + (random()*9000)::int)::text, 4, '0'),
  now() - (random() * interval '365 days')
FROM generate_series(1,50) AS s(i);

SELECT setval(pg_get_serial_sequence('users','user_id'), 50, true);


-- 2) Instructores
INSERT INTO instructors (instructor_id, full_name, bio, email, phone)
SELECT
  i,
  'Instructor ' || i,
  'Experienced art instructor in multiple techniques.',
  'instr' || i || '@example.com',
  '555-' || LPAD((1000 + (random()*9000)::int)::text, 4, '0')
FROM generate_series(1,50) AS s(i);

SELECT setval(pg_get_serial_sequence('instructors','instructor_id'), 50, true);


-- 3) Talleres de arte
INSERT INTO workshops (workshop_id, title, description, date, duration_minutes, capacity, instructor_id)
SELECT
  i,
  'Workshop ' || i,
  'Learn exciting art techniques in session ' || i || '.',
  date '2025-01-01' + (random()*364)::int,
  (ARRAY[60, 90, 120, 180])[floor(random()*4+1)],
  (5 + (random()*25)::int),
  floor(random()*50 + 1)
FROM generate_series(1,50) AS s(i);

SELECT setval(pg_get_serial_sequence('workshops','workshop_id'), 50, true);


-- 4) Reservas (50 parejas únicas user–workshop)
DO $$
DECLARE
    rec_count INTEGER := 0;
    u INTEGER;
    w INTEGER;
    stat TEXT;
BEGIN
  WHILE rec_count < 50 LOOP
    u := floor(random()*50 + 1);
    w := floor(random()*50 + 1);
    stat := (ARRAY['pending','confirmed','cancelled'])[floor(random()*3+1)];
    BEGIN
      INSERT INTO reservations (user_id, workshop_id, reservation_date, status, attended)
      VALUES (
        u,
        w,
        now() - (random() * interval '120 days'),
        stat,
        (CASE WHEN stat = 'confirmed' AND random() < 0.5 THEN TRUE ELSE FALSE END)
      );
      rec_count := rec_count + 1;
    EXCEPTION WHEN unique_violation THEN
      NULL;
    END;
  END LOOP;
END;
$$;

SELECT setval(pg_get_serial_sequence('reservations','reservation_id'),
              (SELECT MAX(reservation_id) FROM reservations), true);
