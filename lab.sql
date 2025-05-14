-- NOTA:Ejecutar la función de multiples parametros primero para observar resultados en las otras funciones.

-- Funciones:
-- 1. Función que retorna un valor escalar
CREATE OR REPLACE FUNCTION get_user_reservation_count(p_user_id INTEGER)
RETURNS INTEGER
LANGUAGE plpgsql AS
$$
DECLARE
    v_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_count
    FROM reservations
    WHERE user_id = p_user_id;
    
    RETURN v_count;
END;
$$;
-- Uso:
SELECT get_user_reservation_count(42);

-- 2. Función que retorna un conjunto de resultados
CREATE OR REPLACE FUNCTION get_user_workshops(p_user_id INTEGER)
RETURNS TABLE (
    workshop_id    INTEGER,
    title          VARCHAR,
    date           DATE,
    reservation_status VARCHAR
)
LANGUAGE plpgsql AS
$$
BEGIN
    RETURN QUERY
    SELECT
        w.workshop_id,
        w.title,
        w.date,
        r.status
    FROM workshops w
    JOIN reservations r ON r.workshop_id = w.workshop_id
    WHERE r.user_id = p_user_id
    ORDER BY w.date;
END;
$$;
-- Uso:
SELECT * 
FROM get_user_workshops(42);

-- 3. Función con múltiples parámetros y lógica condicional
CREATE OR REPLACE FUNCTION make_reservation(
    p_user_id      INTEGER,
    p_workshop_id  INTEGER,
    OUT result_msg TEXT
)
RETURNS TEXT
LANGUAGE plpgsql AS
$$
DECLARE
    v_current_reservations INTEGER;
    v_capacity             INTEGER;
BEGIN
    -- Verificar que no exista ya la reserva
    IF EXISTS (
        SELECT 1
        FROM reservations
        WHERE user_id = p_user_id
          AND workshop_id = p_workshop_id
    ) THEN
        result_msg := 'Error: ya existe una reserva para este taller.';
        RETURN;
    END IF;

    -- Comprobar capacidad del taller
    SELECT capacity INTO v_capacity
    FROM workshops
    WHERE workshop_id = p_workshop_id;

    SELECT COUNT(*) INTO v_current_reservations
    FROM reservations
    WHERE workshop_id = p_workshop_id
      AND status = 'confirmed';

    IF v_current_reservations >= v_capacity THEN
        result_msg := 'Error: el taller ya está lleno.';
        RETURN;
    END IF;

    -- Insertar la reserva en estado 'pending'
    INSERT INTO reservations (user_id, workshop_id, status)
    VALUES (p_user_id, p_workshop_id, 'pending');

    result_msg := 'Reserva creada con éxito en estado pending.';
    RETURN;
END;
$$;
-- Uso:
SELECT make_reservation(42, 10);

--Procedimientos:
-- 1) Procedimiento para inserciones complejas
CREATE OR REPLACE PROCEDURE create_complex_reservation(
    IN  p_user_email     TEXT,
    IN  p_full_name      TEXT,
    IN  p_phone          TEXT,
    IN  p_workshop_id    INT,
    OUT p_reservation_id INT
)
AS $$
DECLARE
    v_user_id    INT;
    v_capacity   INT;
    v_count_book INT;
BEGIN
    -- 1) Asegurar/crear usuario
    SELECT user_id
      INTO v_user_id
      FROM users
     WHERE email = p_user_email;

    IF NOT FOUND THEN
        INSERT INTO users(full_name, email, phone)
        VALUES (p_full_name, p_user_email, p_phone)
        RETURNING user_id INTO v_user_id;
    END IF;

    -- 2) Comprobar existencia de workshop y capacidad disponible
    SELECT capacity
      INTO v_capacity
      FROM workshops
     WHERE workshop_id = p_workshop_id
       AND date >= CURRENT_DATE;  

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Workshop % no existe o ya pasó la fecha.', p_workshop_id;
    END IF;

    SELECT COUNT(*)
      INTO v_count_book
      FROM reservations
     WHERE workshop_id = p_workshop_id
       AND status = 'confirmed';

    IF v_count_book >= v_capacity THEN
        RAISE EXCEPTION 'Capacidad máxima (% ) alcanzada para workshop %.',
                         v_capacity, p_workshop_id;
    END IF;

    -- 3) Insertar reserva
    INSERT INTO reservations(user_id, workshop_id, status)
    VALUES (v_user_id, p_workshop_id, 'pending')
    RETURNING reservation_id
    INTO p_reservation_id;

END;
$$
LANGUAGE plpgsql;

CALL create_complex_reservation(
  'geadrwerwwdo@example.com',
  'Ana López',
  '555-1234',
  25,
  NULL
);

-- Aqui validamos que se haya insertado correctamente la reservacion
SELECT * FROM reservations;
SELECT * FROM workshops;

-- 2) Procedimiento para UPDATE o DELETE con validaciones
CREATE OR REPLACE PROCEDURE manage_reservation(
    IN  p_reservation_id INT,
    IN  p_new_status     TEXT    DEFAULT NULL,  -- 'pending', 'confirmed', 'cancelled'
    IN  p_do_delete      BOOLEAN DEFAULT FALSE
)
AS $$
DECLARE
    v_old_status TEXT;
BEGIN
    -- Leer estado actual
    SELECT status
      INTO v_old_status
      FROM reservations
     WHERE reservation_id = p_reservation_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Reserva % no existe.', p_reservation_id;
    END IF;

    -- DELETE?
    IF p_do_delete THEN
        IF v_old_status = 'confirmed' THEN
            RAISE EXCEPTION 'No se puede eliminar una reserva ya confirmada.';
        END IF;
        DELETE FROM reservations
         WHERE reservation_id = p_reservation_id;
        RETURN;
    END IF;

    -- UPDATE?
    IF p_new_status IS NOT NULL THEN
        -- Validar nuevo estado
        IF p_new_status NOT IN ('pending','confirmed','cancelled') THEN
            RAISE EXCEPTION 'Estado % no válido.', p_new_status;
        END IF;

        -- Validar transiciones lógicas
        IF v_old_status = p_new_status THEN
            RAISE NOTICE 'El estado ya es %; no se realiza cambio.', v_old_status;
            RETURN;
        END IF;
        IF v_old_status = 'cancelled' THEN
            RAISE EXCEPTION 'No se puede reactivar una reserva cancelada.';
        END IF;

        -- Finalmente actualizar
        UPDATE reservations
           SET status = p_new_status,
               attended = CASE WHEN p_new_status <> 'confirmed' THEN FALSE
                              ELSE attended END
         WHERE reservation_id = p_reservation_id;
        RETURN;
    END IF;

    -- Si llega aquí, no se solicitó ni delete ni update
    RAISE EXCEPTION 'Debe indicar p_new_status o p_do_delete = TRUE.';
END;
$$
LANGUAGE plpgsql;

SELECT * FROM reservations;

-- 2a) Confirmar una reserva:
CALL manage_reservation( 58, 'confirmed', FALSE );

-- 2b) Cancelar una reserva:
CALL manage_reservation( 10, 'cancelled', FALSE );

-- 2c) Eliminar una reserva pendiente:
CALL manage_reservation( 12, NULL, TRUE );

-- Vistas:
-- 1. Vista simple
CREATE OR REPLACE VIEW vw_users_basic AS
SELECT
    user_id,
    full_name,
    email,
    phone
FROM users;
-- Uso:
SELECT * FROM vw_users_basic;

-- 2. Vista con JOIN y GROUP BY
CREATE OR REPLACE VIEW vw_workshop_reservation_counts AS
SELECT
    w.workshop_id,
    w.title,
    COUNT(r.reservation_id) AS confirmed_reservations
FROM workshops w
LEFT JOIN reservations r
  ON r.workshop_id = w.workshop_id
  AND r.status = 'confirmed'
GROUP BY
    w.workshop_id,
    w.title
ORDER BY
    confirmed_reservations DESC;
-- Uso:
SELECT * 
FROM vw_workshop_reservation_counts;

-- 3. Vista con expresiones (CASE, COALESCE)
CREATE OR REPLACE VIEW vw_workshop_capacity_status AS
SELECT
    w.workshop_id,
    w.title,
    w.capacity,
    COALESCE(cnt.confirmed, 0) AS confirmed_reservations,
    -- Ratio de ocupación
    ROUND(
      COALESCE(cnt.confirmed, 0)::NUMERIC
      / NULLIF(w.capacity, 0)
      * 100
    , 2) AS occupancy_pct,
    -- Clasificación según ocupación
    CASE
      WHEN COALESCE(cnt.confirmed, 0) >= w.capacity THEN 'Full'
      WHEN COALESCE(cnt.confirmed, 0)::NUMERIC / w.capacity > 0.8 THEN 'Almost Full'
      ELSE 'Available'
    END AS status
FROM workshops w
LEFT JOIN (
    SELECT
      workshop_id,
      COUNT(*) AS confirmed
    FROM reservations
    WHERE status = 'confirmed'
    GROUP BY workshop_id
) AS cnt USING (workshop_id);
-- Uso:
SELECT * 
FROM vw_workshop_capacity_status
WHERE status <> 'Available';

-- 4.Vista combinada de varias tablas
CREATE OR REPLACE VIEW vw_reservation_details AS
SELECT
    r.reservation_id,
    r.reservation_date,
    r.status,
    u.user_id,
    u.full_name   AS user_name,
    u.email       AS user_email,
    w.workshop_id,
    w.title       AS workshop_title,
    w.date        AS workshop_date,
    i.instructor_id,
    i.full_name   AS instructor_name,
    i.email       AS instructor_email
FROM reservations r
JOIN users u ON u.user_id = r.user_id
JOIN workshops w ON w.workshop_id = r.workshop_id
LEFT JOIN instructors i ON i.instructor_id = w.instructor_id;
-- Uso:
SELECT *
FROM vw_reservation_details
WHERE status = 'confirmed'
ORDER BY reservation_date DESC;

-- Triggers:
-- Función del trigger BEFORE
CREATE OR REPLACE FUNCTION check_workshop_capacity()
RETURNS TRIGGER AS $$
DECLARE
    current_count INT;
    max_capacity INT;
BEGIN
    -- Solo validar si se va a insertar como 'confirmed'
    IF NEW.status = 'confirmed' THEN
        SELECT COUNT(*) INTO current_count
        FROM reservations
        WHERE workshop_id = NEW.workshop_id AND status = 'confirmed';

        SELECT capacity INTO max_capacity
        FROM workshops
        WHERE workshop_id = NEW.workshop_id;

        IF current_count >= max_capacity THEN
            RAISE EXCEPTION 'No se puede reservar: el taller ya está lleno.';
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Crear el trigger BEFORE INSERT
CREATE OR REPLACE TRIGGER trg_check_capacity
BEFORE UPDATE ON reservations
FOR EACH ROW
EXECUTE FUNCTION check_workshop_capacity();


-- Función del trigger AFTER 
CREATE OR REPLACE FUNCTION notify_reservation_created()
RETURNS TRIGGER AS $$
BEGIN
    RAISE NOTICE 'Se ha creado una reserva con ID: % para el taller %', NEW.reservation_id, NEW.workshop_id;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Crear el trigger AFTER INSERT
CREATE TRIGGER trg_notify_reservation_created
AFTER INSERT ON reservations
FOR EACH ROW
EXECUTE FUNCTION notify_reservation_created();

INSERT INTO reservations(user_id, workshop_id, reservation_date, status, attended)
VALUES (2, 2, '2025-05-13 10:00:00', 'confirmed', TRUE);

