-- Reactific Database Schema
-- Run this against your Render PostgreSQL instance

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Users
CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  email VARCHAR(255) UNIQUE NOT NULL,
  username VARCHAR(30) UNIQUE NOT NULL,
  password_hash VARCHAR(255) NOT NULL,
  stripe_customer_id VARCHAR(255),
  subscription_status VARCHAR(20) DEFAULT 'free',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_username ON users(username);
CREATE INDEX idx_users_stripe ON users(stripe_customer_id);

-- Scores — every completed round
CREATE TABLE scores (
  id BIGSERIAL PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  court VARCHAR(10) NOT NULL DEFAULT 'full',
  speed VARCHAR(10) NOT NULL,
  level INTEGER NOT NULL,
  score INTEGER NOT NULL,
  streak INTEGER NOT NULL DEFAULT 0,
  tier INTEGER NOT NULL DEFAULT 1,
  targets_found INTEGER NOT NULL DEFAULT 0,
  time_remaining_ms INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_scores_user ON scores(user_id);
CREATE INDEX idx_scores_created ON scores(created_at DESC);
CREATE INDEX idx_scores_leaderboard ON scores(court, speed, score DESC);
CREATE INDEX idx_scores_daily ON scores(created_at, score DESC);

-- Best score per user per speed (materialized for fast leaderboard queries)
CREATE OR REPLACE VIEW leaderboard_alltime AS
SELECT DISTINCT ON (s.user_id, s.speed)
  s.user_id,
  u.username,
  s.speed,
  s.score,
  s.level,
  s.tier,
  s.streak,
  s.created_at
FROM scores s
JOIN users u ON u.id = s.user_id
WHERE s.court = 'full'
ORDER BY s.user_id, s.speed, s.score DESC;

-- Daily high scores
CREATE OR REPLACE VIEW leaderboard_daily AS
SELECT DISTINCT ON (s.user_id, s.speed)
  s.user_id,
  u.username,
  s.speed,
  s.score,
  s.level,
  s.tier,
  s.streak,
  s.created_at
FROM scores s
JOIN users u ON u.id = s.user_id
WHERE s.court = 'full'
  AND s.created_at >= CURRENT_DATE
ORDER BY s.user_id, s.speed, s.score DESC;
