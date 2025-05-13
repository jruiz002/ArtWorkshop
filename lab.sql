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
  'ana.lopez@example.com',
  'Ana López',
  '555-1234',
  2,
  NULL
);

-- Aqui validamos que se haya insertado correctamente la reservacion
SELECT * FROM reservations;


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
CALL manage_reservation( 1, 'confirmed', FALSE );

-- 2b) Cancelar una reserva:
CALL manage_reservation( 10, 'cancelled', FALSE );

-- 2c) Eliminar una reserva pendiente:
CALL manage_reservation( 12, NULL, TRUE );
