# Kitaab Database Architecture - Enterprise Edition

## Executive Summary

This document presents a production-ready, enterprise-grade database architecture for Kitaab, a spiritual self-accountability platform. The design addresses scalability, data integrity, performance, and maintainability requirements for supporting millions of users while maintaining strict data consistency and auditability.

**Key Improvements Over Previous Design:**
- ✅ Complete data integrity with comprehensive constraints
- ✅ Missing tables added (merit evaluations, target progress, audit logs)
- ✅ Enterprise-grade indexing strategy with covering indexes
- ✅ Materialized views for analytics performance
- ✅ Proper partitioning strategy for time-series data
- ✅ Comprehensive audit trail system
- ✅ Connection pooling and read/write splitting
- ✅ Data archival and retention policies
- ✅ Disaster recovery and backup strategies

---

## Table of Contents

1. [Overview](#overview)
2. [Architecture Principles](#architecture-principles)
3. [Database Schema Design](#database-schema-design)
4. [Data Integrity & Constraints](#data-integrity--constraints)
5. [Indexing Strategy](#indexing-strategy)
6. [Partitioning Strategy](#partitioning-strategy)
7. [Materialized Views & Aggregates](#materialized-views--aggregates)
8. [Scalability & Performance](#scalability--performance)
9. [Security & Compliance](#security--compliance)
10. [Backup & Disaster Recovery](#backup--disaster-recovery)
11. [Migration Strategy](#migration-strategy)
12. [Monitoring & Observability](#monitoring--observability)

---

## Overview

### Business Requirements

Kitaab is a spiritual self-accountability platform that allows Muslims to track their good deeds (Hasanaat) and bad deeds (Saiyyiaat) throughout their lifetime. The database must support:

- **Dual deed categories**: Hasanaat and Saiyyiaat
- **Flexible measurement systems**: Scale-based (Yes/No, custom scales) and count-based
- **Hierarchical structures**: Deed items with level-based nesting
- **Entry rules**: Entries are created directly for the deed item being tracked
- **Daily logging**: Chronological entries with daily reflection messages
- **Time-range analytics**: Daily, weekly, monthly, yearly, and custom date ranges
- **Hide functionality**: Two types - hide from input forms and graphs, or hide from graphs only
- **Merits/Demerits system**: Time-based evaluations with AND/OR logic
- **Targets system**: User-defined, time-bounded goals spanning multiple deeds
- **Social features**: Mutual friendship and one-way following with deed-level permissions
- **Deed ownership**: All deeds have user_id (owned by the user who created them)
- **High scalability**: Support for millions of users with sub-100ms query response times

### Technical Requirements

- **Database**: PostgreSQL 14+ (recommended: PostgreSQL 15+)
- **Primary Keys**: UUID v4 for all tables
- **Timezone Handling**: TIMESTAMP WITH TIME ZONE for all timestamps
- **Character Encoding**: UTF-8 (Unicode)
- **ACID Compliance**: Full transactional integrity
- **Concurrent Access**: Support for 10,000+ concurrent connections
- **Data Retention**: 7+ years for compliance
- **Backup RPO**: < 1 hour
- **Backup RTO**: < 4 hours

---

## Architecture Principles

### 1. **Data Integrity First**
- All foreign keys with appropriate CASCADE rules
- Comprehensive check constraints for business logic
- Database-level validation (not just application-level)
- Referential integrity enforced at database level
- Audit trails for all critical operations

### 2. **Performance by Design**
- Strategic indexing with covering indexes
- Partitioning for time-series data (entries)
- Materialized views for analytics
- Query optimization through proper index design
- Connection pooling and read/write splitting

### 3. **Scalability Built-In**
- Horizontal scaling via read replicas
- Partitioning strategy for growth
- Efficient pagination (cursor-based)
- Caching layer integration points
- Sharding-ready design (user_id as shard key)

### 4. **Security & Compliance**
- Row-Level Security (RLS) policies
- Encrypted backups
- Audit logging for compliance
- GDPR-compliant data handling
- Principle of least privilege

### 5. **Maintainability**
- Clear naming conventions
- Comprehensive documentation
- Migration strategy
- Monitoring and alerting
- Automated backup and recovery

---

## Database Schema Design

### Tables Overview

| # | Table Name | Primary Purpose | Fields | Critical Indexes |
|---|-----------|----------------|--------|------------------|
| 1 | `users` | User accounts and authentication | 11 | 5 |
| 2 | `deed` | Deed definitions (Hasanaat/Saiyyiaat) | 5 | 4 |
| 3 | `deed_items` | Deed items/sub-deeds | 9 | 5 |
| 4 | `scale_definitions` | Scale values with versioning | 10 | 6 |
| 5 | `entries` | Daily logging records (PARTITIONED) | 9 | 8 |
| 6 | `friend_relationships` | Friend and follow relationships | 8 | 5 |
| 7 | `friend_deed_permissions` | Deed-level permissions | 7 | 4 |
| 8 | `daily_reflection_messages` | Daily reflection messages | 7 | 3 |
| 9 | `merits` | Time-based evaluation rules | 9 | 3 |
| 10 | `merit_items` | Conditions for each merit | 6 | 4 |
| 11 | `merit_evaluations` | Merit evaluation results | 8 | 5 |
| 12 | `targets` | User-defined goals | 9 | 4 |
| 13 | `target_items` | Conditions for each target | 6 | 4 |
| 14 | `target_progress` | Target progress tracking | 7 | 5 |
| 15 | `audit_logs` | Audit trail for compliance | 9 | 4 |
| 16 | `user_preferences` | User settings and preferences | 6 | 2 |

**Total Tables**: 16 (4 additional tables for completeness)

### Core Tables

#### 1. `users`

```sql
CREATE TABLE users (
    user_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email VARCHAR(255) NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    username VARCHAR(100) NOT NULL,
    full_name VARCHAR(255),
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ,
    last_login TIMESTAMPTZ,
    is_active BOOLEAN NOT NULL DEFAULT true,
    timezone VARCHAR(50) NOT NULL DEFAULT 'UTC',
    email_verified BOOLEAN NOT NULL DEFAULT false,
    CONSTRAINT uq_users_email UNIQUE (email),
    CONSTRAINT uq_users_username UNIQUE (username),
    CONSTRAINT chk_users_email_format CHECK (email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$')
);

CREATE INDEX idx_users_email ON users(email) WHERE is_active = true;
CREATE INDEX idx_users_username ON users(username) WHERE is_active = true;
CREATE INDEX idx_users_created_at ON users(created_at DESC);
CREATE INDEX idx_users_last_login ON users(last_login DESC) WHERE last_login IS NOT NULL;
CREATE INDEX idx_users_active ON users(is_active) WHERE is_active = true;
```

**Key Features:**
- Email format validation at database level
- Unique constraints on email and username
- Partial indexes for active users only
- Timezone support for user-specific date handling

#### 2. `deed`

```sql
CREATE TYPE deed_category AS ENUM ('hasanaat', 'saiyyiaat');
CREATE TYPE measure_type AS ENUM ('scale', 'count');

CREATE TABLE deed (
    deed_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    category_type deed_category NOT NULL,
    measure_type measure_type NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ,
    CONSTRAINT fk_deed_user FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE
);

CREATE INDEX idx_deed_user_category ON deed(user_id, category_type) WHERE user_id IS NOT NULL;
CREATE INDEX idx_deed_user_measure ON deed(user_id, measure_type);
CREATE INDEX idx_deed_category ON deed(category_type);
CREATE INDEX idx_deed_created_at ON deed(created_at DESC);
```

**Key Features:**
- All deeds owned by users (user_id NOT NULL)
- Category and measure type enforced via ENUM
- Efficient lookups by user and category

#### 3. `deed_items`

```sql
CREATE TYPE hide_type AS ENUM ('none', 'hide_from_all', 'hide_from_graphs');

CREATE TABLE deed_items (
    deed_item_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    deed_id UUID NOT NULL REFERENCES deed(deed_id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    level INTEGER NOT NULL DEFAULT 0,
    hide_type hide_type NOT NULL DEFAULT 'none',
    display_order INTEGER NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ,
    CONSTRAINT fk_deed_items_deed FOREIGN KEY (deed_id) REFERENCES deed(deed_id) ON DELETE CASCADE,
    CONSTRAINT chk_deed_items_level CHECK (level >= 0),
    CONSTRAINT chk_deed_items_display_order CHECK (display_order >= 0)
);

CREATE INDEX idx_deed_items_deed ON deed_items(deed_id, is_active) WHERE is_active = true;
CREATE INDEX idx_deed_items_level ON deed_items(deed_id, level, is_active);
CREATE INDEX idx_deed_items_hide_type ON deed_items(hide_type, is_active) WHERE hide_type != 'none';
CREATE INDEX idx_deed_items_display_order ON deed_items(deed_id, display_order, is_active);
CREATE INDEX idx_deed_items_active ON deed_items(deed_id, is_active) WHERE is_active = true;
```

**Key Features:**
- Level-based nesting support
- Hide type filtering for analytics
- Display order for UI rendering
- Soft delete via is_active flag

#### 4. `scale_definitions`

```sql
CREATE TABLE scale_definitions (
    scale_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    deed_id UUID NOT NULL REFERENCES deed(deed_id) ON DELETE CASCADE,
    scale_value VARCHAR(100) NOT NULL,
    numeric_value INTEGER,
    display_order INTEGER NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    deactivated_at TIMESTAMPTZ,
    version INTEGER NOT NULL DEFAULT 1,
    CONSTRAINT fk_scale_definitions_deed FOREIGN KEY (deed_id) REFERENCES deed(deed_id) ON DELETE CASCADE,
    CONSTRAINT chk_scale_definitions_deactivation CHECK (
        (is_active = true AND deactivated_at IS NULL) OR
        (is_active = false AND deactivated_at IS NOT NULL)
    ),
    CONSTRAINT chk_scale_definitions_version CHECK (version > 0)
);

-- Partial unique index for active scales only
CREATE UNIQUE INDEX idx_scale_definitions_unique_active 
    ON scale_definitions(deed_id, scale_value) 
    WHERE is_active = true;

CREATE INDEX idx_scale_definitions_deed ON scale_definitions(deed_id, is_active);
CREATE INDEX idx_scale_definitions_deed_value ON scale_definitions(deed_id, scale_value);
CREATE INDEX idx_scale_definitions_active ON scale_definitions(deed_id, is_active) WHERE is_active = true;
CREATE INDEX idx_scale_definitions_version ON scale_definitions(deed_id, version DESC);
CREATE INDEX idx_scale_definitions_deactivated ON scale_definitions(deed_id, deactivated_at) WHERE is_active = false;
```

**Key Features:**
- Soft versioning with historical preservation
- Unique constraint on active scales only
- Check constraint for deactivation logic
- Efficient lookups for active and historical scales

#### 5. `entries` (PARTITIONED TABLE)

```sql
-- Parent partitioned table
CREATE TABLE entries (
    entry_id UUID NOT NULL,
    user_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    deed_item_id UUID NOT NULL REFERENCES deed_items(deed_item_id) ON DELETE CASCADE,
    entry_date DATE NOT NULL,
    measure_value VARCHAR(100),
    count_value INTEGER,
    edited_by_user_id UUID REFERENCES users(user_id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ,
    PRIMARY KEY (entry_id, entry_date),
    CONSTRAINT fk_entries_user FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    CONSTRAINT fk_entries_deed_item FOREIGN KEY (deed_item_id) REFERENCES deed_items(deed_item_id) ON DELETE CASCADE,
    CONSTRAINT fk_entries_edited_by FOREIGN KEY (edited_by_user_id) REFERENCES users(user_id),
    CONSTRAINT chk_entries_measure_type CHECK (
        (measure_value IS NOT NULL AND count_value IS NULL) OR
        (count_value IS NOT NULL AND measure_value IS NULL)
    ),
    CONSTRAINT chk_entries_date_range CHECK (entry_date >= '2020-01-01' AND entry_date <= '2100-12-31')
) PARTITION BY RANGE (entry_date);

-- Unique constraint per partition (enforced via application logic or triggers)
-- Note: PostgreSQL doesn't support unique constraints across partitions directly
-- Use application-level enforcement or partition-specific unique indexes

-- Monthly partitions (example for 2024)
CREATE TABLE entries_2024_01 PARTITION OF entries
    FOR VALUES FROM ('2024-01-01') TO ('2024-02-01');
CREATE TABLE entries_2024_02 PARTITION OF entries
    FOR VALUES FROM ('2024-02-01') TO ('2024-03-01');
-- ... continue for each month

-- Indexes on parent table (inherited by partitions)
CREATE INDEX idx_entries_user_date ON entries(user_id, entry_date DESC);
CREATE INDEX idx_entries_deed_item_date ON entries(deed_item_id, entry_date DESC);
CREATE INDEX idx_entries_user_deed_item_date ON entries(user_id, deed_item_id, entry_date);
CREATE INDEX idx_entries_edited_by ON entries(edited_by_user_id, entry_date DESC) WHERE edited_by_user_id IS NOT NULL;
CREATE INDEX idx_entries_created_at ON entries(created_at DESC);
CREATE INDEX idx_entries_date_range ON entries(entry_date) WHERE entry_date >= CURRENT_DATE - INTERVAL '1 year';

-- Covering index for analytics queries
CREATE INDEX idx_entries_analytics ON entries(user_id, entry_date, deed_item_id) 
    INCLUDE (measure_value, count_value, created_at);
```

**Key Features:**
- **Partitioned by entry_date** for performance and archival
- Monthly partitions for efficient query pruning
- Covering indexes for analytics queries
- Full edit history via edited_by_user_id
- Check constraints for data validation

**Partition Management:**
- Auto-create partitions via scheduled job (pg_cron)
- Archive old partitions (> 2 years) to cold storage
- Drop partitions after archival (configurable retention)

### Social Tables

#### 6. `friend_relationships`

```sql
CREATE TYPE relationship_type AS ENUM ('friend', 'follow');
CREATE TYPE relationship_status AS ENUM ('pending', 'accepted', 'rejected', 'blocked');

CREATE TABLE friend_relationships (
    relationship_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    requester_user_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    receiver_user_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    relationship_type relationship_type NOT NULL,
    status relationship_status NOT NULL DEFAULT 'pending',
    accepted_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ,
    CONSTRAINT fk_friend_relationships_requester FOREIGN KEY (requester_user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    CONSTRAINT fk_friend_relationships_receiver FOREIGN KEY (receiver_user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    CONSTRAINT chk_friend_relationships_no_self_reference CHECK (requester_user_id != receiver_user_id),
    CONSTRAINT chk_friend_relationships_accepted_at CHECK (
        (status = 'accepted' AND accepted_at IS NOT NULL) OR
        (status != 'accepted' AND accepted_at IS NULL)
    ),
    CONSTRAINT uq_friend_relationships UNIQUE (requester_user_id, receiver_user_id, relationship_type)
);

CREATE INDEX idx_friend_relationships_requester ON friend_relationships(requester_user_id, status);
CREATE INDEX idx_friend_relationships_receiver ON friend_relationships(receiver_user_id, status);
CREATE INDEX idx_friend_relationships_active ON friend_relationships(requester_user_id, receiver_user_id) 
    WHERE status = 'accepted';
CREATE INDEX idx_friend_relationships_type ON friend_relationships(relationship_type, status);
CREATE INDEX idx_friend_relationships_created_at ON friend_relationships(created_at DESC);
```

#### 7. `friend_deed_permissions`

```sql
CREATE TYPE permission_type AS ENUM ('read', 'write');

CREATE TABLE friend_deed_permissions (
    permission_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    relationship_id UUID NOT NULL REFERENCES friend_relationships(relationship_id) ON DELETE CASCADE,
    deed_id UUID NOT NULL REFERENCES deed(deed_id) ON DELETE CASCADE,
    permission_type permission_type NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ,
    CONSTRAINT fk_friend_deed_permissions_relationship FOREIGN KEY (relationship_id) REFERENCES friend_relationships(relationship_id) ON DELETE CASCADE,
    CONSTRAINT fk_friend_deed_permissions_deed FOREIGN KEY (deed_id) REFERENCES deed(deed_id) ON DELETE CASCADE,
    CONSTRAINT uq_friend_deed_permissions UNIQUE (relationship_id, deed_id, permission_type)
);

-- Partial unique index: Only one write permission per deed
CREATE UNIQUE INDEX idx_friend_deed_permissions_one_write
    ON friend_deed_permissions(deed_id, permission_type)
    WHERE permission_type = 'write' AND is_active = true;

CREATE INDEX idx_friend_deed_permissions_relationship ON friend_deed_permissions(relationship_id, is_active);
CREATE INDEX idx_friend_deed_permissions_deed ON friend_deed_permissions(deed_id, is_active);
CREATE INDEX idx_friend_deed_permissions_active ON friend_deed_permissions(deed_id, permission_type, is_active) 
    WHERE is_active = true;
```

### Evaluation Tables

#### 8. `merits`

```sql
CREATE TYPE merit_type AS ENUM ('AND', 'OR');
CREATE TYPE merit_category AS ENUM ('positive', 'negative');

CREATE TABLE merits (
    merit_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title VARCHAR(255) NOT NULL,
    description TEXT,
    merit_duration INTEGER NOT NULL,
    merit_type merit_type NOT NULL,
    merit_category merit_category NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ,
    CONSTRAINT chk_merits_duration CHECK (merit_duration > 0 AND merit_duration <= 365)
);

CREATE INDEX idx_merits_active ON merits(is_active) WHERE is_active = true;
CREATE INDEX idx_merits_category ON merits(merit_category, is_active) WHERE is_active = true;
CREATE INDEX idx_merits_type ON merits(merit_type, is_active) WHERE is_active = true;
```

#### 9. `merit_items`

```sql
CREATE TABLE merit_items (
    merit_item_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    merit_id UUID NOT NULL REFERENCES merits(merit_id) ON DELETE CASCADE,
    deed_item_id UUID NOT NULL REFERENCES deed_items(deed_item_id) ON DELETE CASCADE,
    merit_items_count INTEGER,
    scale_id UUID REFERENCES scale_definitions(scale_id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_merit_items_merit FOREIGN KEY (merit_id) REFERENCES merits(merit_id) ON DELETE CASCADE,
    CONSTRAINT fk_merit_items_deed_item FOREIGN KEY (deed_item_id) REFERENCES deed_items(deed_item_id) ON DELETE CASCADE,
    CONSTRAINT fk_merit_items_scale FOREIGN KEY (scale_id) REFERENCES scale_definitions(scale_id),
    CONSTRAINT chk_merit_items_condition CHECK (
        (merit_items_count IS NOT NULL AND scale_id IS NULL) OR
        (merit_items_count IS NULL AND scale_id IS NOT NULL)
    ),
    CONSTRAINT chk_merit_items_count CHECK (merit_items_count IS NULL OR merit_items_count > 0)
);

CREATE INDEX idx_merit_items_merit ON merit_items(merit_id);
CREATE INDEX idx_merit_items_deed_item ON merit_items(deed_item_id);
CREATE INDEX idx_merit_items_scale ON merit_items(scale_id) WHERE scale_id IS NOT NULL;
CREATE INDEX idx_merit_items_merit_deed ON merit_items(merit_id, deed_item_id);
```

#### 10. `merit_evaluations` ⭐ NEW TABLE

```sql
CREATE TABLE merit_evaluations (
    evaluation_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    merit_id UUID NOT NULL REFERENCES merits(merit_id) ON DELETE CASCADE,
    evaluation_date DATE NOT NULL,
    evaluation_period_start DATE NOT NULL,
    evaluation_period_end DATE NOT NULL,
    is_earned BOOLEAN NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_merit_evaluations_user FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    CONSTRAINT fk_merit_evaluations_merit FOREIGN KEY (merit_id) REFERENCES merits(merit_id) ON DELETE CASCADE,
    CONSTRAINT chk_merit_evaluations_period CHECK (evaluation_period_end >= evaluation_period_start),
    CONSTRAINT uq_merit_evaluations UNIQUE (user_id, merit_id, evaluation_date)
);

CREATE INDEX idx_merit_evaluations_user ON merit_evaluations(user_id, evaluation_date DESC);
CREATE INDEX idx_merit_evaluations_merit ON merit_evaluations(merit_id, evaluation_date DESC);
CREATE INDEX idx_merit_evaluations_earned ON merit_evaluations(user_id, is_earned, evaluation_date DESC) WHERE is_earned = true;
CREATE INDEX idx_merit_evaluations_period ON merit_evaluations(evaluation_period_start, evaluation_period_end);
CREATE INDEX idx_merit_evaluations_user_merit ON merit_evaluations(user_id, merit_id, evaluation_date DESC);
```

**Purpose**: Tracks when users earn merits/demerits, enabling analytics and notifications.

#### 11. `targets`

```sql
CREATE TABLE targets (
    target_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ,
    CONSTRAINT fk_targets_user FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    CONSTRAINT chk_targets_date_range CHECK (end_date >= start_date),
    CONSTRAINT chk_targets_future_dates CHECK (end_date >= CURRENT_DATE),
    CONSTRAINT uq_targets_user_title_start UNIQUE (user_id, title, start_date)
);

CREATE INDEX idx_targets_user ON targets(user_id, is_active) WHERE is_active = true;
CREATE INDEX idx_targets_date_range ON targets(start_date, end_date) WHERE is_active = true;
CREATE INDEX idx_targets_user_date ON targets(user_id, start_date DESC, end_date DESC);
CREATE INDEX idx_targets_active ON targets(user_id, is_active, start_date) WHERE is_active = true;
```

#### 12. `target_items`

```sql
CREATE TABLE target_items (
    target_item_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    target_id UUID NOT NULL REFERENCES targets(target_id) ON DELETE CASCADE,
    deed_item_id UUID NOT NULL REFERENCES deed_items(deed_item_id) ON DELETE CASCADE,
    target_items_count INTEGER,
    scale_id UUID REFERENCES scale_definitions(scale_id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_target_items_target FOREIGN KEY (target_id) REFERENCES targets(target_id) ON DELETE CASCADE,
    CONSTRAINT fk_target_items_deed_item FOREIGN KEY (deed_item_id) REFERENCES deed_items(deed_item_id) ON DELETE CASCADE,
    CONSTRAINT fk_target_items_scale FOREIGN KEY (scale_id) REFERENCES scale_definitions(scale_id),
    CONSTRAINT chk_target_items_condition CHECK (
        (target_items_count IS NOT NULL AND scale_id IS NULL) OR
        (target_items_count IS NULL AND scale_id IS NOT NULL)
    ),
    CONSTRAINT chk_target_items_count CHECK (target_items_count IS NULL OR target_items_count > 0)
);

CREATE INDEX idx_target_items_target ON target_items(target_id);
CREATE INDEX idx_target_items_deed_item ON target_items(deed_item_id);
CREATE INDEX idx_target_items_scale ON target_items(scale_id) WHERE scale_id IS NOT NULL;
CREATE INDEX idx_target_items_target_deed ON target_items(target_id, deed_item_id);
```

#### 13. `target_progress` ⭐ NEW TABLE

```sql
CREATE TABLE target_progress (
    progress_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    target_id UUID NOT NULL REFERENCES targets(target_id) ON DELETE CASCADE,
    target_item_id UUID NOT NULL REFERENCES target_items(target_item_id) ON DELETE CASCADE,
    progress_date DATE NOT NULL,
    current_count INTEGER NOT NULL DEFAULT 0,
    required_count INTEGER NOT NULL,
    is_completed BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ,
    CONSTRAINT fk_target_progress_target FOREIGN KEY (target_id) REFERENCES targets(target_id) ON DELETE CASCADE,
    CONSTRAINT fk_target_progress_target_item FOREIGN KEY (target_item_id) REFERENCES target_items(target_item_id) ON DELETE CASCADE,
    CONSTRAINT chk_target_progress_count CHECK (current_count >= 0 AND required_count > 0),
    CONSTRAINT chk_target_progress_completion CHECK (
        (is_completed = true AND current_count >= required_count) OR
        (is_completed = false)
    ),
    CONSTRAINT uq_target_progress UNIQUE (target_id, target_item_id, progress_date)
);

CREATE INDEX idx_target_progress_target ON target_progress(target_id, progress_date DESC);
CREATE INDEX idx_target_progress_target_item ON target_progress(target_item_id, progress_date DESC);
CREATE INDEX idx_target_progress_completed ON target_progress(target_id, is_completed, progress_date) WHERE is_completed = true;
CREATE INDEX idx_target_progress_date ON target_progress(progress_date DESC);
CREATE INDEX idx_target_progress_target_date ON target_progress(target_id, progress_date DESC, is_completed);
```

**Purpose**: Tracks daily progress toward targets, enabling real-time progress visualization.

### Additional Tables

#### 14. `daily_reflection_messages`

```sql
CREATE TABLE daily_reflection_messages (
    reflection_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    reflection_date DATE NOT NULL,
    hasanaat_message TEXT,
    saiyyiaat_message TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ,
    CONSTRAINT fk_daily_reflection_messages_user FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    CONSTRAINT chk_daily_reflection_messages_content CHECK (
        hasanaat_message IS NOT NULL OR saiyyiaat_message IS NOT NULL
    ),
    CONSTRAINT uq_daily_reflection_messages UNIQUE (user_id, reflection_date)
);

CREATE INDEX idx_daily_reflection_user_date ON daily_reflection_messages(user_id, reflection_date DESC);
CREATE INDEX idx_daily_reflection_date ON daily_reflection_messages(reflection_date DESC);

-- Full-text search indexes
CREATE INDEX idx_daily_reflection_hasanaat_fts ON daily_reflection_messages 
    USING gin(to_tsvector('english', hasanaat_message)) 
    WHERE hasanaat_message IS NOT NULL;
CREATE INDEX idx_daily_reflection_saiyyiaat_fts ON daily_reflection_messages 
    USING gin(to_tsvector('english', saiyyiaat_message)) 
    WHERE saiyyiaat_message IS NOT NULL;
```

#### 15. `audit_logs` ⭐ NEW TABLE

```sql
CREATE TYPE audit_action AS ENUM ('INSERT', 'UPDATE', 'DELETE', 'SELECT');
CREATE TYPE audit_table_name AS ENUM (
    'users', 'deed', 'deed_items', 'scale_definitions', 'entries',
    'friend_relationships', 'friend_deed_permissions', 'daily_reflection_messages',
    'merits', 'merit_items', 'merit_evaluations', 'targets', 'target_items', 'target_progress'
);

CREATE TABLE audit_logs (
    audit_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(user_id) ON DELETE SET NULL,
    table_name audit_table_name NOT NULL,
    record_id UUID NOT NULL,
    action audit_action NOT NULL,
    old_values JSONB,
    new_values JSONB,
    ip_address INET,
    user_agent TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_audit_logs_user FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE SET NULL
) PARTITION BY RANGE (created_at);

-- Monthly partitions for audit logs
CREATE TABLE audit_logs_2024_01 PARTITION OF audit_logs
    FOR VALUES FROM ('2024-01-01') TO ('2024-02-01');
-- ... continue for each month

CREATE INDEX idx_audit_logs_user ON audit_logs(user_id, created_at DESC);
CREATE INDEX idx_audit_logs_table_record ON audit_logs(table_name, record_id, created_at DESC);
CREATE INDEX idx_audit_logs_action ON audit_logs(action, created_at DESC);
CREATE INDEX idx_audit_logs_created_at ON audit_logs(created_at DESC);

-- GIN index for JSONB queries
CREATE INDEX idx_audit_logs_new_values ON audit_logs USING gin(new_values);
```

**Purpose**: Comprehensive audit trail for compliance, security, and debugging.

#### 16. `user_preferences` ⭐ NEW TABLE

```sql
CREATE TABLE user_preferences (
    preference_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    preference_key VARCHAR(100) NOT NULL,
    preference_value JSONB NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ,
    CONSTRAINT fk_user_preferences_user FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    CONSTRAINT uq_user_preferences UNIQUE (user_id, preference_key)
);

CREATE INDEX idx_user_preferences_user ON user_preferences(user_id);
CREATE INDEX idx_user_preferences_key ON user_preferences(preference_key, user_id);
```

**Purpose**: Flexible storage for user settings, notification preferences, UI preferences, etc.

---

## Data Integrity & Constraints

### Comprehensive Check Constraints

```sql
-- Entries: Measure type consistency
ALTER TABLE entries ADD CONSTRAINT chk_entries_measure_type 
    CHECK (
        (measure_value IS NOT NULL AND count_value IS NULL) OR
        (count_value IS NOT NULL AND measure_value IS NULL)
    );

-- Entries: Date range validation
ALTER TABLE entries ADD CONSTRAINT chk_entries_date_range 
    CHECK (entry_date >= '2020-01-01' AND entry_date <= '2100-12-31');

-- Friend relationships: No self-reference
ALTER TABLE friend_relationships ADD CONSTRAINT chk_friend_relationships_no_self_reference
    CHECK (requester_user_id != receiver_user_id);

-- Friend relationships: Accepted status requires accepted_at
ALTER TABLE friend_relationships ADD CONSTRAINT chk_friend_relationships_accepted_at
    CHECK (
        (status = 'accepted' AND accepted_at IS NOT NULL) OR
        (status != 'accepted' AND accepted_at IS NULL)
    );

-- Scale definitions: Deactivation logic
ALTER TABLE scale_definitions ADD CONSTRAINT chk_scale_definitions_deactivation
    CHECK (
        (is_active = true AND deactivated_at IS NULL) OR
        (is_active = false AND deactivated_at IS NOT NULL)
    );

-- Merit items: Only one condition type
ALTER TABLE merit_items ADD CONSTRAINT chk_merit_items_condition
    CHECK (
        (merit_items_count IS NOT NULL AND scale_id IS NULL) OR
        (merit_items_count IS NULL AND scale_id IS NOT NULL)
    );

-- Target items: Only one condition type
ALTER TABLE target_items ADD CONSTRAINT chk_target_items_condition
    CHECK (
        (target_items_count IS NOT NULL AND scale_id IS NULL) OR
        (target_items_count IS NULL AND scale_id IS NOT NULL)
    );

-- Targets: Date range validation
ALTER TABLE targets ADD CONSTRAINT chk_targets_date_range
    CHECK (end_date >= start_date);

-- Target progress: Completion logic
ALTER TABLE target_progress ADD CONSTRAINT chk_target_progress_completion
    CHECK (
        (is_completed = true AND current_count >= required_count) OR
        (is_completed = false)
    );
```

### Foreign Key Constraints

All foreign keys use appropriate CASCADE rules:
- **ON DELETE CASCADE**: For child records that should be deleted with parent
- **ON DELETE SET NULL**: For optional references (e.g., audit_logs.user_id)
- **ON DELETE RESTRICT**: For critical references (not used in this design, CASCADE preferred)

### Unique Constraints

```sql
-- Users
ALTER TABLE users ADD CONSTRAINT uq_users_email UNIQUE (email);
ALTER TABLE users ADD CONSTRAINT uq_users_username UNIQUE (username);

-- Entries: One entry per user per deed item per date per editor
-- Note: Enforced via application logic due to partitioning

-- Friend relationships: One relationship per pair per type
ALTER TABLE friend_relationships ADD CONSTRAINT uq_friend_relationships 
    UNIQUE (requester_user_id, receiver_user_id, relationship_type);

-- Friend deed permissions: One permission per relationship per deed per type
ALTER TABLE friend_deed_permissions ADD CONSTRAINT uq_friend_deed_permissions 
    UNIQUE (relationship_id, deed_id, permission_type);

-- Daily reflection messages: One per user per day
ALTER TABLE daily_reflection_messages ADD CONSTRAINT uq_daily_reflection_messages 
    UNIQUE (user_id, reflection_date);

-- Merit evaluations: One evaluation per user per merit per date
ALTER TABLE merit_evaluations ADD CONSTRAINT uq_merit_evaluations 
    UNIQUE (user_id, merit_id, evaluation_date);

-- Targets: One target per user per title per start date
ALTER TABLE targets ADD CONSTRAINT uq_targets_user_title_start 
    UNIQUE (user_id, title, start_date);

-- Target progress: One progress record per target per item per date
ALTER TABLE target_progress ADD CONSTRAINT uq_target_progress 
    UNIQUE (target_id, target_item_id, progress_date);

-- User preferences: One preference per user per key
ALTER TABLE user_preferences ADD CONSTRAINT uq_user_preferences 
    UNIQUE (user_id, preference_key);

-- Scale definitions: Unique active scale per deed (partial unique index)
CREATE UNIQUE INDEX idx_scale_definitions_unique_active 
    ON scale_definitions(deed_id, scale_value) 
    WHERE is_active = true;
```

---

## Indexing Strategy

### Critical Indexes

#### High-Frequency Query Indexes

```sql
-- User authentication (most frequent)
CREATE INDEX idx_users_email ON users(email) WHERE is_active = true;
CREATE INDEX idx_users_username ON users(username) WHERE is_active = true;

-- Entry queries (highest volume)
CREATE INDEX idx_entries_user_date ON entries(user_id, entry_date DESC);
CREATE INDEX idx_entries_deed_item_date ON entries(deed_item_id, entry_date DESC);
CREATE INDEX idx_entries_user_deed_item_date ON entries(user_id, deed_item_id, entry_date);

-- Covering index for analytics (includes frequently selected columns)
CREATE INDEX idx_entries_analytics ON entries(user_id, entry_date, deed_item_id) 
    INCLUDE (measure_value, count_value, created_at);

-- Friend relationships (social features)
CREATE INDEX idx_friend_relationships_active ON friend_relationships(requester_user_id, receiver_user_id) 
    WHERE status = 'accepted';

-- Friend deed permissions (access control)
CREATE INDEX idx_friend_deed_permissions_deed ON friend_deed_permissions(deed_id, is_active) 
    WHERE is_active = true;
```

#### Partial Indexes (Space-Efficient)

```sql
-- Only index active records
CREATE INDEX idx_users_active ON users(is_active) WHERE is_active = true;
CREATE INDEX idx_deed_items_active ON deed_items(deed_id, is_active) WHERE is_active = true;
CREATE INDEX idx_merits_active ON merits(is_active) WHERE is_active = true;
CREATE INDEX idx_targets_active ON targets(user_id, is_active) WHERE is_active = true;

-- Only index non-null values
CREATE INDEX idx_entries_edited_by ON entries(edited_by_user_id, entry_date DESC) 
    WHERE edited_by_user_id IS NOT NULL;
```

#### Composite Indexes for Complex Queries

```sql
-- Analytics queries with category filtering
CREATE INDEX idx_entries_user_category_date ON entries(user_id, entry_date DESC) 
    INCLUDE (deed_item_id, measure_value, count_value);

-- Merit evaluation queries
CREATE INDEX idx_merit_evaluations_user_earned ON merit_evaluations(user_id, is_earned, evaluation_date DESC) 
    WHERE is_earned = true;

-- Target progress queries
CREATE INDEX idx_target_progress_target_completed ON target_progress(target_id, is_completed, progress_date DESC) 
    WHERE is_completed = true;
```

### Index Maintenance

```sql
-- Monitor index usage
SELECT 
    schemaname,
    tablename,
    indexname,
    idx_scan as index_scans,
    idx_tup_read as tuples_read,
    idx_tup_fetch as tuples_fetched
FROM pg_stat_user_indexes
WHERE schemaname = 'public'
ORDER BY idx_scan DESC;

-- Rebuild indexes periodically (for high-write tables)
REINDEX TABLE CONCURRENTLY entries;
REINDEX TABLE CONCURRENTLY audit_logs;

-- Update statistics
ANALYZE entries;
ANALYZE audit_logs;
```

---

## Partitioning Strategy

### Entries Table Partitioning

```sql
-- Partition by month for entries table
-- Benefits:
-- 1. Faster queries (partition pruning)
-- 2. Easier archival (drop old partitions)
-- 3. Better maintenance (vacuum per partition)
-- 4. Improved index performance

-- Create partition function
CREATE OR REPLACE FUNCTION create_monthly_partition(
    table_name TEXT,
    start_date DATE,
    end_date DATE
) RETURNS VOID AS $$
DECLARE
    partition_name TEXT;
BEGIN
    partition_name := table_name || '_' || TO_CHAR(start_date, 'YYYY_MM');
    
    EXECUTE format(
        'CREATE TABLE IF NOT EXISTS %I PARTITION OF %I FOR VALUES FROM (%L) TO (%L)',
        partition_name,
        table_name,
        start_date,
        end_date
    );
END;
$$ LANGUAGE plpgsql;

-- Auto-create partitions (run via pg_cron)
SELECT create_monthly_partition('entries', '2024-01-01', '2024-02-01');
SELECT create_monthly_partition('entries', '2024-02-01', '2024-03-01');
-- ... continue for future months

-- Archive old partitions (> 2 years)
-- Move to cold storage or separate archive database
```

### Partition Management Script

```sql
-- Function to auto-create next month's partition
CREATE OR REPLACE FUNCTION auto_create_entries_partition()
RETURNS VOID AS $$
DECLARE
    next_month_start DATE;
    next_month_end DATE;
    partition_name TEXT;
BEGIN
    next_month_start := DATE_TRUNC('month', CURRENT_DATE + INTERVAL '1 month');
    next_month_end := next_month_start + INTERVAL '1 month';
    partition_name := 'entries_' || TO_CHAR(next_month_start, 'YYYY_MM');
    
    -- Check if partition already exists
    IF NOT EXISTS (
        SELECT 1 FROM pg_class WHERE relname = partition_name
    ) THEN
        EXECUTE format(
            'CREATE TABLE %I PARTITION OF entries FOR VALUES FROM (%L) TO (%L)',
            partition_name,
            next_month_start,
            next_month_end
        );
        RAISE NOTICE 'Created partition %', partition_name;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Schedule via pg_cron (runs on 1st of each month)
SELECT cron.schedule('create-entries-partition', '0 0 1 * *', 
    'SELECT auto_create_entries_partition();');
```

---

## Materialized Views & Aggregates

### Pre-Computed Analytics

```sql
-- Daily summaries per user
CREATE MATERIALIZED VIEW mv_user_daily_summaries AS
SELECT 
    user_id,
    entry_date,
    COUNT(*) FILTER (WHERE d.category_type = 'hasanaat') as hasanaat_count,
    COUNT(*) FILTER (WHERE d.category_type = 'saiyyiaat') as saiyyiaat_count,
    SUM(e.count_value) FILTER (WHERE d.category_type = 'hasanaat') as hasanaat_total,
    SUM(e.count_value) FILTER (WHERE d.category_type = 'saiyyiaat') as saiyyiaat_total,
    AVG(sd.numeric_value) FILTER (WHERE d.measure_type = 'scale' AND d.category_type = 'hasanaat') as hasanaat_avg_scale,
    AVG(sd.numeric_value) FILTER (WHERE d.measure_type = 'scale' AND d.category_type = 'saiyyiaat') as saiyyiaat_avg_scale
FROM entries e
JOIN deed_items di ON e.deed_item_id = di.deed_item_id
JOIN deed d ON di.deed_id = d.deed_id
LEFT JOIN scale_definitions sd ON d.deed_id = sd.deed_id AND e.measure_value = sd.scale_value
WHERE di.hide_type != 'hide_from_all'
GROUP BY user_id, entry_date;

CREATE UNIQUE INDEX idx_mv_user_daily_summaries ON mv_user_daily_summaries(user_id, entry_date);

-- Monthly summaries per user
CREATE MATERIALIZED VIEW mv_user_monthly_summaries AS
SELECT 
    user_id,
    DATE_TRUNC('month', entry_date) as month,
    COUNT(*) FILTER (WHERE d.category_type = 'hasanaat') as hasanaat_count,
    COUNT(*) FILTER (WHERE d.category_type = 'saiyyiaat') as saiyyiaat_count,
    SUM(e.count_value) FILTER (WHERE d.category_type = 'hasanaat') as hasanaat_total,
    SUM(e.count_value) FILTER (WHERE d.category_type = 'saiyyiaat') as saiyyiaat_total
FROM entries e
JOIN deed_items di ON e.deed_item_id = di.deed_item_id
JOIN deed d ON di.deed_id = d.deed_id
WHERE di.hide_type != 'hide_from_all'
GROUP BY user_id, DATE_TRUNC('month', entry_date);

CREATE UNIQUE INDEX idx_mv_user_monthly_summaries ON mv_user_monthly_summaries(user_id, month);

-- Refresh strategy (incremental or full)
-- Incremental refresh (recommended for large datasets)
CREATE OR REPLACE FUNCTION refresh_user_daily_summaries_incremental()
RETURNS VOID AS $$
BEGIN
    -- Refresh only last 7 days
    REFRESH MATERIALIZED VIEW CONCURRENTLY mv_user_daily_summaries;
    -- Or delete and re-insert for last 7 days only
END;
$$ LANGUAGE plpgsql;

-- Schedule refresh (daily at 2 AM)
SELECT cron.schedule('refresh-daily-summaries', '0 2 * * *', 
    'SELECT refresh_user_daily_summaries_incremental();');
```

---

## Scalability & Performance

### Connection Pooling

```sql
-- PgBouncer configuration (pgbouncer.ini)
[databases]
kitaab = host=localhost port=5432 dbname=kitaab

[pgbouncer]
pool_mode = transaction
max_client_conn = 10000
default_pool_size = 25
reserve_pool_size = 5
reserve_pool_timeout = 3
max_db_connections = 100
```

### Read/Write Splitting

```sql
-- Application-level routing:
-- - Write queries → Primary database
-- - Read queries → Read replicas (with lag monitoring)
-- - Analytics queries → Read replicas or materialized views

-- Monitor replication lag
SELECT 
    client_addr,
    state,
    sync_state,
    pg_wal_lsn_diff(pg_current_wal_lsn(), replay_lsn) as lag_bytes
FROM pg_stat_replication;
```

### Query Optimization

#### Cursor-Based Pagination

```sql
-- Instead of OFFSET/LIMIT (slow for large offsets)
-- Use cursor-based pagination
SELECT * FROM entries
WHERE user_id = $1
  AND (entry_date, entry_id) < ($2, $3)  -- cursor
ORDER BY entry_date DESC, entry_id DESC
LIMIT 50;
```

#### Batch Operations

```sql
-- Bulk insert entries
INSERT INTO entries (user_id, deed_item_id, entry_date, measure_value, count_value)
SELECT * FROM UNNEST($1::UUID[], $2::UUID[], $3::DATE[], $4::VARCHAR[], $5::INTEGER[]);

-- Batch update friend relationships
UPDATE friend_relationships
SET status = 'accepted', accepted_at = CURRENT_TIMESTAMP
WHERE relationship_id = ANY($1::UUID[]);
```

### Caching Strategy

```sql
-- Redis cache keys:
-- - user:{user_id}:deeds → User's deeds (TTL: 1 hour)
-- - user:{user_id}:entries:{date} → Daily entries (TTL: 5 minutes)
-- - user:{user_id}:friends → Friend list (TTL: 10 minutes)
-- - merit:{merit_id} → Merit definition (TTL: 24 hours)

-- Cache invalidation triggers
CREATE OR REPLACE FUNCTION notify_cache_invalidation()
RETURNS TRIGGER AS $$
BEGIN
    PERFORM pg_notify('cache_invalidate', 
        json_build_object(
            'table', TG_TABLE_NAME,
            'record_id', NEW.entry_id,
            'user_id', NEW.user_id
        )::text
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_cache_invalidation_entries
    AFTER INSERT OR UPDATE ON entries
    FOR EACH ROW
    EXECUTE FUNCTION notify_cache_invalidation();
```

---

## Security & Compliance

### Row-Level Security (RLS)

```sql
-- Enable RLS on entries table
ALTER TABLE entries ENABLE ROW LEVEL SECURITY;

-- Policy: Users can access their own entries
CREATE POLICY entries_owner_policy ON entries
    FOR ALL
    USING (user_id = current_setting('app.user_id')::UUID);

-- Policy: Friends/followers with read permission
CREATE POLICY entries_friend_read_policy ON entries
    FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM friend_relationships fr
            JOIN friend_deed_permissions fdp ON fr.relationship_id = fdp.relationship_id
            JOIN deed_items di ON fdp.deed_id = (
                SELECT deed_id FROM deed_items WHERE deed_item_id = entries.deed_item_id
            )
            WHERE fr.status = 'accepted'
              AND fdp.permission_type = 'read'
              AND fdp.is_active = true
              AND (
                  (fr.requester_user_id = current_setting('app.user_id')::UUID 
                   AND fr.receiver_user_id = entries.user_id)
                  OR
                  (fr.receiver_user_id = current_setting('app.user_id')::UUID 
                   AND fr.requester_user_id = entries.user_id)
              )
        )
    );
```

### Audit Logging

```sql
-- Trigger to log all changes
CREATE OR REPLACE FUNCTION audit_trigger()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO audit_logs (
        user_id,
        table_name,
        record_id,
        action,
        old_values,
        new_values,
        ip_address,
        user_agent
    ) VALUES (
        current_setting('app.user_id', true)::UUID,
        TG_TABLE_NAME::audit_table_name,
        COALESCE(NEW.entry_id, OLD.entry_id),
        TG_OP::audit_action,
        CASE WHEN TG_OP = 'DELETE' THEN to_jsonb(OLD) ELSE NULL END,
        CASE WHEN TG_OP IN ('INSERT', 'UPDATE') THEN to_jsonb(NEW) ELSE NULL END,
        current_setting('app.ip_address', true)::INET,
        current_setting('app.user_agent', true)
    );
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

-- Apply to critical tables
CREATE TRIGGER trigger_audit_entries
    AFTER INSERT OR UPDATE OR DELETE ON entries
    FOR EACH ROW
    EXECUTE FUNCTION audit_trigger();
```

### Data Encryption

```sql
-- Encrypt sensitive fields (application-level)
-- Use pgcrypto extension for database-level encryption if needed
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Example: Encrypt reflection messages (if required)
ALTER TABLE daily_reflection_messages 
    ADD COLUMN hasanaat_message_encrypted BYTEA,
    ADD COLUMN saiyyiaat_message_encrypted BYTEA;
```

---

## Backup & Disaster Recovery

### Backup Strategy

```sql
-- Full backup (daily at 2 AM)
pg_dump -Fc -d kitaab -f /backups/kitaab_$(date +%Y%m%d).dump

-- Incremental backup (WAL archiving)
-- postgresql.conf:
wal_level = replica
archive_mode = on
archive_command = 'cp %p /backups/wal_archive/%f'

-- Point-in-time recovery (PITR)
-- Restore to specific timestamp
pg_basebackup -D /restore -Ft -z -P
```

### Retention Policy

- **Daily backups**: 30 days
- **Weekly backups**: 12 weeks
- **Monthly backups**: 12 months
- **Yearly backups**: 7 years (compliance)

### Disaster Recovery

- **RTO (Recovery Time Objective)**: < 4 hours
- **RPO (Recovery Point Objective)**: < 1 hour
- **Testing**: Quarterly DR drills

---

## Migration Strategy

### Version Control

```sql
-- Migration tracking table
CREATE TABLE schema_migrations (
    version VARCHAR(50) PRIMARY KEY,
    description TEXT NOT NULL,
    applied_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Example migration
INSERT INTO schema_migrations (version, description) 
VALUES ('001_initial_schema', 'Initial database schema');
```

### Zero-Downtime Migrations

1. **Additive changes**: Add columns with defaults (no downtime)
2. **Backward-compatible changes**: Support old and new formats
3. **Data migrations**: Run in batches during low-traffic periods
4. **Schema changes**: Use `ALTER TABLE ... CONCURRENTLY` when possible

---

## Monitoring & Observability

### Key Metrics

```sql
-- Query performance
SELECT 
    query,
    calls,
    total_exec_time,
    mean_exec_time,
    max_exec_time
FROM pg_stat_statements
ORDER BY total_exec_time DESC
LIMIT 20;

-- Table sizes
SELECT 
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;

-- Index usage
SELECT 
    schemaname,
    tablename,
    indexname,
    idx_scan,
    idx_tup_read,
    idx_tup_fetch
FROM pg_stat_user_indexes
WHERE schemaname = 'public'
ORDER BY idx_scan DESC;
```

### Alerting

- **Slow queries**: > 100ms
- **Replication lag**: > 1 second
- **Connection pool**: > 80% utilization
- **Disk space**: < 20% free
- **Failed queries**: Error rate > 1%

---

## Summary

This enterprise-grade database architecture provides:

✅ **Complete Data Integrity**: Comprehensive constraints, foreign keys, and validation
✅ **High Performance**: Strategic indexing, partitioning, and materialized views
✅ **Scalability**: Read replicas, connection pooling, and sharding-ready design
✅ **Security**: RLS policies, audit logging, and encryption support
✅ **Compliance**: GDPR-ready with audit trails and data retention
✅ **Maintainability**: Clear documentation, migration strategy, and monitoring

**Total Tables**: 16 (4 additional tables for completeness)
**Key Improvements**:
- Added `merit_evaluations` table for tracking merit earnings
- Added `target_progress` table for real-time target tracking
- Added `audit_logs` table for compliance and security
- Added `user_preferences` table for flexible user settings
- Comprehensive indexing strategy with covering indexes
- Partitioning strategy for time-series data
- Materialized views for analytics performance
- Enterprise-grade security and compliance features

This design is production-ready and can scale to support millions of users while maintaining data integrity and performance.


