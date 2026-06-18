-- Isolation : chaque etudiant travaille dans SON schema (espace de noms).
CREATE SCHEMA IF NOT EXISTS aicha28;

CREATE TABLE IF NOT EXISTS aicha28.users (
    id            SERIAL PRIMARY KEY,
    email         VARCHAR(255) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,   -- jamais de mot de passe en clair
    full_name     VARCHAR(255),
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);
