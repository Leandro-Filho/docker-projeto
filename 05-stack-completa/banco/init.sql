-- ============================================================
-- Script de inicialização do banco
-- Montar em /docker-entrypoint-initdb.d/init.sql
--
-- ATENÇÃO: roda APENAS quando o volume de dados está VAZIO.
-- Para reaplicar: docker compose down -v && docker compose up -d
-- ============================================================

CREATE TABLE IF NOT EXISTS tarefas (
    id          SERIAL PRIMARY KEY,
    titulo      VARCHAR(200) NOT NULL,
    concluida   BOOLEAN      NOT NULL DEFAULT FALSE,
    criada_em   TIMESTAMP    NOT NULL DEFAULT NOW()
);

-- Índice para a consulta mais comum (listar por data)
CREATE INDEX IF NOT EXISTS idx_tarefas_criada_em ON tarefas (criada_em DESC);

-- Dados de exemplo (seed), úteis para testar o front sem cadastrar nada
INSERT INTO tarefas (titulo, concluida) VALUES
    ('Escrever o Dockerfile do backend',  TRUE),
    ('Escrever o Dockerfile do frontend', TRUE),
    ('Amarrar tudo no docker-compose',    FALSE),
    ('Escrever o README com minhas palavras', FALSE)
ON CONFLICT DO NOTHING;
