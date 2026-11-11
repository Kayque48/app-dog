-- Eventos: desfiles, corridas, festas e encontros.
-- Eventos com concurso aceitam inscrição de cães e votação.
CREATE TABLE events (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    title       TEXT    NOT NULL,
    description TEXT    NOT NULL DEFAULT '',
    kind        TEXT    NOT NULL CHECK (kind IN ('desfile', 'corrida', 'festa', 'encontro', 'concurso', 'adocao', 'competicao')),
    place_name  TEXT    NOT NULL,
    address     TEXT    NOT NULL DEFAULT '',
    lat         REAL    NOT NULL,
    lng         REAL    NOT NULL,
    starts_at   TEXT    NOT NULL, -- 'AAAA-MM-DD HH:MM'
    cover_url   TEXT,
    has_contest INTEGER NOT NULL DEFAULT 0,
    -- regras de inscrição do concurso (opcionais)
    entry_sex   TEXT CHECK (entry_sex IN ('macho', 'femea')),
    entry_breed TEXT,
    created_by  INTEGER REFERENCES users(id),
    created_at  TEXT    NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX idx_events_starts ON events(starts_at);

-- "Vou" / "Talvez"
CREATE TABLE event_rsvps (
    event_id INTEGER NOT NULL REFERENCES events(id),
    user_id  INTEGER NOT NULL REFERENCES users(id),
    status   TEXT    NOT NULL CHECK (status IN ('going', 'maybe')),
    PRIMARY KEY (event_id, user_id)
);

-- Cães inscritos no concurso do evento.
CREATE TABLE event_entries (
    id         INTEGER PRIMARY KEY AUTOINCREMENT,
    event_id   INTEGER NOT NULL REFERENCES events(id),
    dog_id     INTEGER NOT NULL REFERENCES dogs(id),
    created_at TEXT    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (event_id, dog_id)
);

-- Um voto por pessoa em cada evento (pode trocar de voto).
CREATE TABLE event_votes (
    event_id INTEGER NOT NULL REFERENCES events(id),
    user_id  INTEGER NOT NULL REFERENCES users(id),
    entry_id INTEGER NOT NULL REFERENCES event_entries(id),
    PRIMARY KEY (event_id, user_id)
);
