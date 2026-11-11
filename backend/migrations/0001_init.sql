-- Esquema inicial do All Love.
-- Datas são guardadas como texto ISO (AAAA-MM-DD ou AAAA-MM-DD HH:MM:SS).

-- Donos (os usuários do aplicativo).
-- CPF, telefone e endereço são obrigatórios por segurança (pedido do cliente)
-- e só aparecem para administradores.
CREATE TABLE users (
    id            INTEGER PRIMARY KEY AUTOINCREMENT,
    name          TEXT    NOT NULL,
    email         TEXT    NOT NULL UNIQUE,
    password_hash TEXT    NOT NULL,
    phone         TEXT    NOT NULL,
    cpf           TEXT    UNIQUE,
    cep           TEXT    NOT NULL,
    city          TEXT    NOT NULL,
    address       TEXT    NOT NULL,
    lat           REAL,
    lng           REAL,
    is_admin      INTEGER NOT NULL DEFAULT 0,
    is_premium    INTEGER NOT NULL DEFAULT 0,
    banned_at     TEXT,
    ban_reason    TEXT,
    deleted_at    TEXT,
    created_at    TEXT    NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE sessions (
    token      TEXT    PRIMARY KEY,
    user_id    INTEGER NOT NULL REFERENCES users(id),
    created_at TEXT    NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Cães. Quando o dono remove o cão ele não é apagado (removed_at),
-- para manter o histórico de "quais cães esse dono já teve".
CREATE TABLE dogs (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    owner_id    INTEGER NOT NULL REFERENCES users(id),
    name        TEXT    NOT NULL,
    breed       TEXT    NOT NULL,
    birth_date  TEXT    NOT NULL,
    sex         TEXT    NOT NULL CHECK (sex IN ('macho', 'femea')),
    in_heat     INTEGER NOT NULL DEFAULT 0,
    temperament TEXT    NOT NULL CHECK (temperament IN ('calmo', 'brincalhao', 'timido', 'agressivo')),
    bites       INTEGER NOT NULL DEFAULT 0,
    likes       TEXT    NOT NULL DEFAULT '',
    dislikes    TEXT    NOT NULL DEFAULT '',
    photo_url   TEXT,
    removed_at  TEXT,
    created_at  TEXT    NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX idx_dogs_owner ON dogs(owner_id);

-- Carteira de vacinação.
CREATE TABLE vaccines (
    id         INTEGER PRIMARY KEY AUTOINCREMENT,
    dog_id     INTEGER NOT NULL REFERENCES dogs(id),
    name       TEXT    NOT NULL,
    applied_on TEXT    NOT NULL,
    next_due   TEXT,
    created_at TEXT    NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX idx_vaccines_dog ON vaccines(dog_id);

-- Histórico / trajetória do cão (cadastro, vacinas, encontros, incidentes).
CREATE TABLE dog_events (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    dog_id      INTEGER NOT NULL REFERENCES dogs(id),
    kind        TEXT    NOT NULL,
    description TEXT    NOT NULL,
    created_at  TEXT    NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX idx_dog_events_dog ON dog_events(dog_id);

-- Feed de fotos.
CREATE TABLE posts (
    id         INTEGER PRIMARY KEY AUTOINCREMENT,
    dog_id     INTEGER NOT NULL REFERENCES dogs(id),
    image_url  TEXT    NOT NULL,
    caption    TEXT    NOT NULL DEFAULT '',
    created_at TEXT    NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE post_likes (
    post_id INTEGER NOT NULL REFERENCES posts(id),
    user_id INTEGER NOT NULL REFERENCES users(id),
    PRIMARY KEY (post_id, user_id)
);

-- "Arrastar para o lado" do Descobrir.
-- passed   = arrastou para a esquerda
-- pending  = arrastou para a direita, aguardando o outro dono aceitar
-- accepted / rejected = resposta do outro dono
CREATE TABLE match_requests (
    id           INTEGER PRIMARY KEY AUTOINCREMENT,
    from_dog_id  INTEGER NOT NULL REFERENCES dogs(id),
    to_dog_id    INTEGER NOT NULL REFERENCES dogs(id),
    status       TEXT    NOT NULL CHECK (status IN ('passed', 'pending', 'accepted', 'rejected')),
    created_at   TEXT    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    responded_at TEXT,
    UNIQUE (from_dog_id, to_dog_id)
);

-- Parques e pontos de encontro.
CREATE TABLE places (
    id         INTEGER PRIMARY KEY AUTOINCREMENT,
    name       TEXT    NOT NULL,
    kind       TEXT    NOT NULL CHECK (kind IN ('parque', 'praca', 'ponto_encontro')),
    address    TEXT    NOT NULL DEFAULT '',
    lat        REAL    NOT NULL,
    lng        REAL    NOT NULL,
    created_by INTEGER REFERENCES users(id)
);

-- Denúncias feitas pelos donos e analisadas pela moderação.
CREATE TABLE reports (
    id             INTEGER PRIMARY KEY AUTOINCREMENT,
    reporter_id    INTEGER NOT NULL REFERENCES users(id),
    target_user_id INTEGER NOT NULL REFERENCES users(id),
    target_dog_id  INTEGER REFERENCES dogs(id),
    reason         TEXT    NOT NULL,
    details        TEXT    NOT NULL DEFAULT '',
    status         TEXT    NOT NULL DEFAULT 'aberta' CHECK (status IN ('aberta', 'procedente', 'improcedente')),
    created_at     TEXT    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    resolved_at    TEXT,
    resolved_by    INTEGER REFERENCES users(id)
);

-- Anúncios de patrocinadores (pet shops). Não aparecem para usuários premium.
CREATE TABLE ads (
    id      INTEGER PRIMARY KEY AUTOINCREMENT,
    sponsor TEXT NOT NULL,
    message TEXT NOT NULL,
    link    TEXT NOT NULL DEFAULT ''
);
