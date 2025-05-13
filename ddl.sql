-- Crear tabla de usuarios
CREATE TABLE users (
    user_id SERIAL PRIMARY KEY,
    full_name VARCHAR(100) NOT NULL,
    email VARCHAR(100) NOT NULL UNIQUE,
    phone VARCHAR(15),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Crear tabla de instructores
CREATE TABLE instructors (
    instructor_id SERIAL PRIMARY KEY,
    full_name VARCHAR(100) NOT NULL,
    bio TEXT,
    email VARCHAR(100) UNIQUE,
    phone VARCHAR(15)
);

-- Crear tabla de talleres de arte
CREATE TABLE workshops (
    workshop_id SERIAL PRIMARY KEY,
    title VARCHAR(100) NOT NULL,
    description TEXT,
    date DATE NOT NULL,
    duration_minutes INTEGER NOT NULL CHECK (duration_minutes > 0),
    capacity INTEGER NOT NULL CHECK (capacity > 0),
    instructor_id INTEGER REFERENCES instructors(instructor_id) ON DELETE SET NULL
);

-- Crear tabla de reservas
CREATE TABLE reservations (
    reservation_id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    workshop_id INTEGER NOT NULL REFERENCES workshops(workshop_id) ON DELETE CASCADE,
    reservation_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    status VARCHAR(20) NOT NULL CHECK (status IN ('pending', 'confirmed', 'cancelled')),
	attended BOOLEAN DEFAULT FALSE,
    
    -- Asegura que un usuario no reserve dos veces el mismo taller
    UNIQUE(user_id, workshop_id)
);
