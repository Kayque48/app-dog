-- Perfil completo do cão e carteira digital.
ALTER TABLE dogs ADD COLUMN weight_kg REAL;
ALTER TABLE dogs ADD COLUMN color TEXT NOT NULL DEFAULT '';
ALTER TABLE dogs ADD COLUMN bio TEXT NOT NULL DEFAULT '';
ALTER TABLE dogs ADD COLUMN activity_level TEXT NOT NULL DEFAULT 'medio';  -- baixo | medio | alto
ALTER TABLE dogs ADD COLUMN looking_for TEXT NOT NULL DEFAULT 'amizade';   -- amizade | cruzamento | ambos
ALTER TABLE dogs ADD COLUMN microchip TEXT NOT NULL DEFAULT '';
ALTER TABLE dogs ADD COLUMN neutered INTEGER NOT NULL DEFAULT 0;
ALTER TABLE dogs ADD COLUMN allergies TEXT NOT NULL DEFAULT '';
ALTER TABLE dogs ADD COLUMN health_notes TEXT NOT NULL DEFAULT '';

-- Documentos da carteira digital (pedigree, exames, RG animal...).
-- O pedigree passa pela verificação da moderação.
CREATE TABLE dog_documents (
    id         INTEGER PRIMARY KEY AUTOINCREMENT,
    dog_id     INTEGER NOT NULL REFERENCES dogs(id),
    kind       TEXT    NOT NULL CHECK (kind IN ('pedigree', 'exame', 'rg', 'receita', 'outro')),
    title      TEXT    NOT NULL,
    file_url   TEXT    NOT NULL,
    status     TEXT    NOT NULL DEFAULT 'enviado' CHECK (status IN ('enviado', 'verificado', 'recusado')),
    created_at TEXT    NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX idx_dog_documents_dog ON dog_documents(dog_id);

-- Feed: vídeos e comentários.
ALTER TABLE posts ADD COLUMN media_type TEXT NOT NULL DEFAULT 'image'; -- image | video

CREATE TABLE post_comments (
    id         INTEGER PRIMARY KEY AUTOINCREMENT,
    post_id    INTEGER NOT NULL REFERENCES posts(id),
    user_id    INTEGER NOT NULL REFERENCES users(id),
    text       TEXT    NOT NULL,
    created_at TEXT    NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX idx_post_comments_post ON post_comments(post_id);

-- Profissionais e estabelecimentos: veterinários, criadores, adestradores, passeadores,
-- hotéis, banho e tosa e ONGs de adoção. Ficam com selo de verificado após a moderação.
CREATE TABLE providers (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    owner_id    INTEGER REFERENCES users(id),
    name        TEXT    NOT NULL,
    kind        TEXT    NOT NULL CHECK (kind IN ('veterinario', 'criador', 'adestrador', 'passeador', 'hotel', 'banho_tosa', 'adocao', 'pet_shop')),
    description TEXT    NOT NULL DEFAULT '',
    services    TEXT    NOT NULL DEFAULT '', -- lista separada por vírgula
    phone       TEXT    NOT NULL DEFAULT '',
    address     TEXT    NOT NULL DEFAULT '',
    lat         REAL    NOT NULL,
    lng         REAL    NOT NULL,
    photo_url   TEXT,
    verified    INTEGER NOT NULL DEFAULT 0,
    created_at  TEXT    NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Agendamentos (consultas, banho, adestramento...). O estabelecimento confirma por telefone.
CREATE TABLE appointments (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    provider_id INTEGER NOT NULL REFERENCES providers(id),
    user_id     INTEGER NOT NULL REFERENCES users(id),
    dog_id      INTEGER NOT NULL REFERENCES dogs(id),
    service     TEXT    NOT NULL,
    date_time   TEXT    NOT NULL, -- 'AAAA-MM-DD HH:MM'
    notes       TEXT    NOT NULL DEFAULT '',
    status      TEXT    NOT NULL DEFAULT 'solicitado' CHECK (status IN ('solicitado', 'confirmado', 'cancelado')),
    created_at  TEXT    NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Loja: catálogo dos pet shops parceiros (a compra é feita com o próprio pet shop).
CREATE TABLE products (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    provider_id INTEGER REFERENCES providers(id),
    name        TEXT    NOT NULL,
    category    TEXT    NOT NULL CHECK (category IN ('roupas', 'alimentos', 'brinquedos', 'acessorios', 'higiene')),
    description TEXT    NOT NULL DEFAULT '',
    price_cents INTEGER NOT NULL,
    photo_url   TEXT,
    link        TEXT    NOT NULL DEFAULT ''
);
