-- Flyway Migration V1: Initial Schema
CREATE TABLE IF NOT EXISTS word_entries (
    id BIGSERIAL PRIMARY KEY,
    word VARCHAR(100) NOT NULL UNIQUE,
    phonetic VARCHAR(100),
    part_of_speech VARCHAR(50),
    definition TEXT NOT NULL,
    example TEXT
);

CREATE TABLE IF NOT EXISTS search_histories (
    id BIGSERIAL PRIMARY KEY,
    word VARCHAR(100) NOT NULL,
    searched_at TIMESTAMP NOT NULL,
    success BOOLEAN NOT NULL
);

CREATE INDEX idx_word_entries_word ON word_entries(LOWER(word));
CREATE INDEX idx_search_histories_searched_at ON search_histories(searched_at DESC);
