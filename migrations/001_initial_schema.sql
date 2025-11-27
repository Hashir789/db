-- Kitaab Database Initial Schema Migration
-- Version: 1.0.0
-- Description: Creates all tables, constraints, indexes, and triggers for Kitaab platform

-- ============================================================================
-- EXTENSIONS
-- ============================================================================

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Enable full-text search (for reflection messages)
CREATE EXTENSION IF NOT EXISTS "pg_trgm";

-- ============================================================================
-- ENUMS
-- ============================================================================

-- Deed category
CREATE TYPE deed_category AS ENUM ('hasanaat', 'saiyyiaat');

-- Measure type
CREATE TYPE measure_type AS ENUM ('scale_based', 'count_based');

-- Hide type
CREATE TYPE hide_type AS ENUM ('none', 'hide_from_all', 'hide_from_graphs');

-- Relationship type
CREATE TYPE relationship_type AS ENUM ('friend', 'follow');

-- Relationship status
CREATE TYPE relationship_status AS ENUM ('pending', 'accepted', 'rejected', 'blocked');

-- Permission type
CREATE TYPE permission_type AS ENUM ('read', 'write');

-- Achievement condition type
CREATE TYPE condition_type AS ENUM ('all_sub_deeds', 'specific_sub_deeds', 'custom');

-- ============================================================================
-- SYSTEM USER
-- ============================================================================

-- Create SYSTEM_USER_ID constant (UUID v4)
-- This user owns all default deeds
DO $$
DECLARE
    system_user_id UUID := '00000000-0000-0000-0000-000000000000'::UUID;
BEGIN
    -- Insert system user if it doesn't exist
    INSERT INTO users (user_id, email, username, full_name, is_active, created_at)
    VALUES (
        system_user_id,
        'system@kitaab.app',
        'SYSTEM',
        'System User',
        true,
        CURRENT_TIMESTAMP
    )
    ON CONFLICT (user_id) DO NOTHING;
END $$;

-- ============================================================================
-- TABLES
-- ============================================================================

-- Users table
CREATE TABLE IF NOT EXISTS users (
    user_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email VARCHAR(255) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    username VARCHAR(100) NOT NULL UNIQUE,
    full_name VARCHAR(255),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP,
    last_login TIMESTAMP,
    is_active BOOLEAN NOT NULL DEFAULT true,
    timezone VARCHAR(50) NOT NULL DEFAULT 'UTC'
);

-- Deeds table (self-referencing for hierarchical structure)
CREATE TABLE IF NOT EXISTS deeds (
    deed_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    parent_deed_id UUID REFERENCES deeds(deed_id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    category deed_category NOT NULL,
    measure_type measure_type NOT NULL,
    is_default BOOLEAN NOT NULL DEFAULT false,
    is_active BOOLEAN NOT NULL DEFAULT true,
    hide_type hide_type NOT NULL DEFAULT 'none',
    display_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP
);

-- Scale definitions table
CREATE TABLE IF NOT EXISTS scale_definitions (
    scale_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    deed_id UUID NOT NULL REFERENCES deeds(deed_id) ON DELETE CASCADE,
    scale_value VARCHAR(100) NOT NULL,
    numeric_value INTEGER,
    display_order INTEGER NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT true
);

-- Entries table
CREATE TABLE IF NOT EXISTS entries (
    entry_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    deed_id UUID NOT NULL REFERENCES deeds(deed_id) ON DELETE CASCADE,
    entry_date DATE NOT NULL,
    measure_value VARCHAR(100),
    count_value INTEGER,
    edited_by_user_id UUID REFERENCES users(user_id),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP
);

-- Friend relationships table
CREATE TABLE IF NOT EXISTS friend_relationships (
    relationship_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    requester_user_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    receiver_user_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    relationship_type relationship_type NOT NULL,
    status relationship_status NOT NULL DEFAULT 'pending',
    accepted_at TIMESTAMP,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP
);

-- Friend deed permissions table
CREATE TABLE IF NOT EXISTS friend_deed_permissions (
    permission_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    relationship_id UUID NOT NULL REFERENCES friend_relationships(relationship_id) ON DELETE CASCADE,
    deed_id UUID NOT NULL REFERENCES deeds(deed_id) ON DELETE CASCADE,
    permission_type permission_type NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP
);

-- Daily reflection messages table
CREATE TABLE IF NOT EXISTS daily_reflection_messages (
    reflection_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    reflection_date DATE NOT NULL,
    hasanaat_message TEXT,
    saiyyiaat_message TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP
);

-- Achievements table
CREATE TABLE IF NOT EXISTS achievements (
    achievement_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(user_id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    condition_type condition_type NOT NULL,
    condition_config JSONB NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP
);

-- User achievements table
CREATE TABLE IF NOT EXISTS user_achievements (
    user_achievement_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    achievement_id UUID NOT NULL REFERENCES achievements(achievement_id) ON DELETE CASCADE,
    achieved_date DATE NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Demerits table
CREATE TABLE IF NOT EXISTS demerits (
    demerit_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(user_id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    condition_type condition_type NOT NULL,
    condition_config JSONB NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP
);

-- User demerits table
CREATE TABLE IF NOT EXISTS user_demerits (
    user_demerit_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    demerit_id UUID NOT NULL REFERENCES demerits(demerit_id) ON DELETE CASCADE,
    demerit_date DATE NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- User default deeds table
CREATE TABLE IF NOT EXISTS user_default_deeds (
    user_default_deed_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    default_deed_id UUID NOT NULL REFERENCES deeds(deed_id) ON DELETE CASCADE,
    is_active BOOLEAN NOT NULL DEFAULT true,
    assigned_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================================
-- CONSTRAINTS
-- ============================================================================

-- Entries: Measure type consistency
ALTER TABLE entries ADD CONSTRAINT check_measure_type 
  CHECK (
    (measure_value IS NOT NULL AND count_value IS NULL) OR
    (count_value IS NOT NULL AND measure_value IS NULL)
  );

-- Entries: Unique entry per user per deed per date per editor
ALTER TABLE entries ADD CONSTRAINT unique_entry_per_editor
  UNIQUE (user_id, deed_id, entry_date, edited_by_user_id);

-- Friend relationships: Prevent self-reference
ALTER TABLE friend_relationships ADD CONSTRAINT check_no_self_reference
  CHECK (requester_user_id != receiver_user_id);

-- Friend relationships: Unique relationship per pair per type
ALTER TABLE friend_relationships ADD CONSTRAINT unique_relationship
  UNIQUE (requester_user_id, receiver_user_id, relationship_type);

-- Friend deed permissions: Unique permission per relationship per deed per type
ALTER TABLE friend_deed_permissions ADD CONSTRAINT unique_permission
  UNIQUE (relationship_id, deed_id, permission_type);

-- Daily reflection messages: One per user per day
ALTER TABLE daily_reflection_messages ADD CONSTRAINT unique_reflection_per_day
  UNIQUE (user_id, reflection_date);

-- User achievements: One achievement per user per achievement per day
ALTER TABLE user_achievements ADD CONSTRAINT unique_user_achievement_per_day
  UNIQUE (user_id, achievement_id, achieved_date);

-- User demerits: One demerit per user per demerit per day
ALTER TABLE user_demerits ADD CONSTRAINT unique_user_demerit_per_day
  UNIQUE (user_id, demerit_id, demerit_date);

-- Friend deed permissions: Only one write permission per deed (partial unique index)
CREATE UNIQUE INDEX IF NOT EXISTS idx_friend_deed_permissions_one_write
  ON friend_deed_permissions(deed_id, permission_type)
  WHERE permission_type = 'write' AND is_active = true;

-- ============================================================================
-- INDEXES
-- ============================================================================

-- Users indexes
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_users_username ON users(username);
CREATE INDEX IF NOT EXISTS idx_users_is_active ON users(is_active) WHERE is_active = true;

-- Deeds indexes
CREATE INDEX IF NOT EXISTS idx_deeds_user_category ON deeds(user_id, category, is_active);
CREATE INDEX IF NOT EXISTS idx_deeds_default ON deeds(is_default) WHERE is_default = true;
CREATE INDEX IF NOT EXISTS idx_deeds_user_active ON deeds(user_id, is_active) WHERE is_active = true;
CREATE INDEX IF NOT EXISTS idx_deeds_hide_type ON deeds(hide_type, is_active);
CREATE INDEX IF NOT EXISTS idx_deeds_parent ON deeds(parent_deed_id, is_active);
CREATE INDEX IF NOT EXISTS idx_deeds_user_parent ON deeds(user_id, parent_deed_id, is_active);
CREATE INDEX IF NOT EXISTS idx_deeds_parent_active ON deeds(parent_deed_id, is_active) 
  WHERE parent_deed_id IS NOT NULL AND is_active = true;

-- Entries indexes
CREATE INDEX IF NOT EXISTS idx_entries_user_date ON entries(user_id, entry_date DESC);
CREATE INDEX IF NOT EXISTS idx_entries_deed_date ON entries(deed_id, entry_date DESC);
CREATE INDEX IF NOT EXISTS idx_entries_user_deed_date ON entries(user_id, deed_id, entry_date);
CREATE INDEX IF NOT EXISTS idx_entries_date_range ON entries(entry_date) 
  WHERE entry_date >= CURRENT_DATE - INTERVAL '1 year';
CREATE INDEX IF NOT EXISTS idx_entries_edited_by ON entries(edited_by_user_id, entry_date DESC) 
  WHERE edited_by_user_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_entries_user_date_edited ON entries(user_id, entry_date, edited_by_user_id);

-- Friend relationships indexes
CREATE INDEX IF NOT EXISTS idx_friend_relationships_requester ON friend_relationships(requester_user_id, status);
CREATE INDEX IF NOT EXISTS idx_friend_relationships_receiver ON friend_relationships(receiver_user_id, status);
CREATE INDEX IF NOT EXISTS idx_friend_relationships_active ON friend_relationships(requester_user_id, receiver_user_id) 
  WHERE status = 'accepted';

-- Friend deed permissions indexes
CREATE INDEX IF NOT EXISTS idx_friend_deed_permissions_relationship ON friend_deed_permissions(relationship_id, is_active);
CREATE INDEX IF NOT EXISTS idx_friend_deed_permissions_deed ON friend_deed_permissions(deed_id, is_active);
CREATE INDEX IF NOT EXISTS idx_friend_deed_permissions_write ON friend_deed_permissions(deed_id, permission_type) 
  WHERE permission_type = 'write';

-- Scale definitions indexes
CREATE INDEX IF NOT EXISTS idx_scale_definitions_deed ON scale_definitions(deed_id, is_active);

-- Daily reflection messages indexes
CREATE INDEX IF NOT EXISTS idx_daily_reflection_user_date ON daily_reflection_messages(user_id, reflection_date DESC);
CREATE INDEX IF NOT EXISTS idx_daily_reflection_date ON daily_reflection_messages(reflection_date);
-- Full-text search indexes for reflection messages
CREATE INDEX IF NOT EXISTS idx_daily_reflection_hasanaat_fts ON daily_reflection_messages 
  USING gin(to_tsvector('english', hasanaat_message)) WHERE hasanaat_message IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_daily_reflection_saiyyiaat_fts ON daily_reflection_messages 
  USING gin(to_tsvector('english', saiyyiaat_message)) WHERE saiyyiaat_message IS NOT NULL;

-- Achievements indexes
CREATE INDEX IF NOT EXISTS idx_achievements_user ON achievements(user_id, is_active) WHERE user_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_achievements_system ON achievements(is_active) WHERE user_id IS NULL;
CREATE INDEX IF NOT EXISTS idx_demerits_user ON demerits(user_id, is_active) WHERE user_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_demerits_system ON demerits(is_active) WHERE user_id IS NULL;

-- User achievements and demerits indexes
CREATE INDEX IF NOT EXISTS idx_user_achievements_user_date ON user_achievements(user_id, achieved_date DESC);
CREATE INDEX IF NOT EXISTS idx_user_achievements_achievement ON user_achievements(achievement_id, achieved_date DESC);
CREATE INDEX IF NOT EXISTS idx_user_demerits_user_date ON user_demerits(user_id, demerit_date DESC);
CREATE INDEX IF NOT EXISTS idx_user_demerits_demerit ON user_demerits(demerit_id, demerit_date DESC);

-- User default deeds indexes
CREATE INDEX IF NOT EXISTS idx_user_default_deeds_user ON user_default_deeds(user_id, is_active);
CREATE INDEX IF NOT EXISTS idx_user_default_deeds_deed ON user_default_deeds(default_deed_id, is_active);

-- ============================================================================
-- TRIGGERS
-- ============================================================================

-- Function: Validate measure_value exists in scale_definitions
CREATE OR REPLACE FUNCTION validate_measure_value()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.measure_value IS NOT NULL THEN
    IF NOT EXISTS (
      SELECT 1 FROM scale_definitions sd
      JOIN deeds d ON sd.deed_id = d.deed_id
      WHERE d.deed_id = NEW.deed_id
        AND sd.scale_value = NEW.measure_value
        AND sd.is_active = true
    ) THEN
      RAISE EXCEPTION 'measure_value % does not exist in scale_definitions for deed %', 
        NEW.measure_value, NEW.deed_id;
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_validate_measure_value
  BEFORE INSERT OR UPDATE ON entries
  FOR EACH ROW
  WHEN (NEW.measure_value IS NOT NULL)
  EXECUTE FUNCTION validate_measure_value();

-- Function: Validate child deeds inherit measure_type from parent
CREATE OR REPLACE FUNCTION validate_child_measure_type()
RETURNS TRIGGER AS $$
DECLARE
  parent_measure_type measure_type;
BEGIN
  IF NEW.parent_deed_id IS NOT NULL THEN
    SELECT measure_type INTO parent_measure_type
    FROM deeds
    WHERE deed_id = NEW.parent_deed_id;
    
    IF NEW.measure_type != parent_measure_type THEN
      RAISE EXCEPTION 'Child deed measure_type (%) must match parent measure_type (%)', 
        NEW.measure_type, parent_measure_type;
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_validate_child_measure_type
  BEFORE INSERT OR UPDATE ON deeds
  FOR EACH ROW
  WHEN (NEW.parent_deed_id IS NOT NULL)
  EXECUTE FUNCTION validate_child_measure_type();

-- Function: Auto-update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = CURRENT_TIMESTAMP;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply auto-update trigger to all tables with updated_at
CREATE TRIGGER trigger_update_deeds_updated_at
  BEFORE UPDATE ON deeds
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER trigger_update_entries_updated_at
  BEFORE UPDATE ON entries
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER trigger_update_friend_relationships_updated_at
  BEFORE UPDATE ON friend_relationships
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER trigger_update_friend_deed_permissions_updated_at
  BEFORE UPDATE ON friend_deed_permissions
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER trigger_update_daily_reflection_messages_updated_at
  BEFORE UPDATE ON daily_reflection_messages
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER trigger_update_achievements_updated_at
  BEFORE UPDATE ON achievements
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER trigger_update_demerits_updated_at
  BEFORE UPDATE ON demerits
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at();

-- Function: Enforce 30-day revert window for friend/follower edits
CREATE OR REPLACE FUNCTION check_revert_window()
RETURNS TRIGGER AS $$
BEGIN
  -- This trigger prevents reverts after 30 days
  -- Called when owner tries to delete friend/follower entry
  IF OLD.edited_by_user_id IS NOT NULL THEN
    IF OLD.created_at < CURRENT_TIMESTAMP - INTERVAL '30 days' THEN
      RAISE EXCEPTION 'Cannot revert entry after 30 days. Entry created at %', OLD.created_at;
    END IF;
  END IF;
  RETURN OLD;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_check_revert_window
  BEFORE DELETE ON entries
  FOR EACH ROW
  WHEN (OLD.edited_by_user_id IS NOT NULL)
  EXECUTE FUNCTION check_revert_window();

-- Function: Validate default deeds are owned by SYSTEM_USER_ID
CREATE OR REPLACE FUNCTION validate_default_deed_ownership()
RETURNS TRIGGER AS $$
DECLARE
  system_user_id UUID := '00000000-0000-0000-0000-000000000000'::UUID;
BEGIN
  IF NEW.is_default = true AND NEW.user_id != system_user_id THEN
    RAISE EXCEPTION 'Default deeds must be owned by SYSTEM_USER_ID';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_validate_default_deed_ownership
  BEFORE INSERT OR UPDATE ON deeds
  FOR EACH ROW
  WHEN (NEW.is_default = true)
  EXECUTE FUNCTION validate_default_deed_ownership();

-- ============================================================================
-- COMMENTS
-- ============================================================================

COMMENT ON TABLE users IS 'User accounts and profiles';
COMMENT ON TABLE deeds IS 'Deed definitions (default and custom) with self-referencing structure for hierarchical organization';
COMMENT ON TABLE scale_definitions IS 'Scale values for scale-based deeds';
COMMENT ON TABLE entries IS 'Daily deed entries with friend/follower edit tracking';
COMMENT ON TABLE friend_relationships IS 'Friend and follow connections between users';
COMMENT ON TABLE friend_deed_permissions IS 'Deed-level permissions for friends/followers';
COMMENT ON TABLE daily_reflection_messages IS 'Daily reflection messages (one Hasanaat, one Saiyyiaat per day)';
COMMENT ON TABLE achievements IS 'Achievement definitions (system-wide and custom)';
COMMENT ON TABLE user_achievements IS 'User achievement earnings';
COMMENT ON TABLE demerits IS 'Demerit definitions (system-wide and custom)';
COMMENT ON TABLE user_demerits IS 'User demerit earnings';
COMMENT ON TABLE user_default_deeds IS 'Tracks which default deeds user opted-in to';

-- ============================================================================
-- MIGRATION COMPLETE
-- ============================================================================

-- Log migration completion
DO $$
BEGIN
  RAISE NOTICE 'Kitaab database schema migration completed successfully';
  RAISE NOTICE 'Total tables created: 12';
  RAISE NOTICE 'Total indexes created: 30+';
  RAISE NOTICE 'Total triggers created: 10';
END $$;

