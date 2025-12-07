# PostgreSQL Tables & Fields Reference - Enterprise Edition

Complete reference of all tables and their fields in the Kitaab database schema (Enterprise Edition).

## Quick Overview

| # | Table Name | Primary Purpose | Total Fields |
|---|-----------|----------------|--------------|
| 1 | `users` | User accounts and authentication | 11 |
| 2 | `deed` | Deed definitions (Hasanaat/Saiyyiaat) | 6 |
| 3 | `deed_items` | Deed items/sub-deeds | 9 |
| 4 | `scale_definitions` | Scale values for scale-based deeds with versioning | 10 |
| 5 | `entries` | Daily logging records for deeds (PARTITIONED) | 9 |
| 6 | `friend_relationships` | Friend and follow relationships between users | 8 |
| 7 | `friend_deed_permissions` | Deed-level permissions for friends/followers | 7 |
| 8 | `daily_reflection_messages` | Daily reflection messages (Hasanaat/Saiyyiaat) | 7 |
| 9 | `merits` | Time-based evaluation rules (positive/negative) | 9 |
| 10 | `merit_items` | Conditions for each merit tied to specific deeds | 6 |
| 11 | `merit_evaluations` | Merit evaluation results and tracking | 8 |
| 12 | `targets` | User-defined, time-bounded goals | 9 |
| 13 | `target_items` | Conditions for each target tied to specific deeds | 6 |
| 14 | `target_progress` | Target progress tracking | 7 |
| 15 | `audit_logs` | Audit trail for compliance (PARTITIONED) | 9 |
| 16 | `user_preferences` | User settings and preferences | 6 |

**Total Tables**: 16

---

## Complete Tables & Fields Matrix

| USERS | DEED | DEED_ITEMS | SCALE_DEFINITIONS | ENTRIES | FRIEND_RELATIONSHIPS | FRIEND_DEED_PERMISSIONS | DAILY_REFLECTION_MESSAGES | MERITS | MERIT_ITEMS | MERIT_EVALUATIONS | TARGETS | TARGET_ITEMS | TARGET_PROGRESS | AUDIT_LOGS | USER_PREFERENCES |
|-------|------|------------|-------------------|---------|----------------------|-------------------------|---------------------------|--------|-------------|------------------|---------|--------------|-----------------|------------|-----------------|
| user_id | deed_id | deed_item_id | scale_id | entry_id | relationship_id | permission_id | reflection_id | merit_id | merit_item_id | evaluation_id | target_id | target_item_id | progress_id | audit_id | preference_id |
| email | user_id | deed_id | deed_id | user_id | requester_user_id | relationship_id | user_id | title | merit_id | user_id | user_id | target_id | target_id | user_id | user_id |
| password_hash | category_type (hasanaat/saiyyiaat) | name | scale_value | deed_item_id | receiver_user_id | deed_id | reflection_date | description | deed_item_id | merit_id | title | deed_item_id | target_item_id | table_name | preference_key |
| username | measure_type (scale/count) | description | numeric_value | entry_date | relationship_type (friend/follow) | permission_type (read/write) | hasanaat_message | merit_duration (in days) | merit_items_count | evaluation_date | description | target_items_count | progress_date | record_id | preference_value |
| full_name | created_at | level | display_order | measure_value | status (pending/accepted/rejected/blocked) | is_active | saiyyiaat_message | merit_type (AND/OR) | scale_id | evaluation_period_start | start_date | scale_id | current_count | action | created_at |
| created_at | updated_at | hide_type | is_active | count_value | accepted_at | created_at | created_at | merit_category (positive/negative) | created_at | evaluation_period_end | end_date | created_at | required_count | old_values | updated_at |
| updated_at | | display_order | created_at | edited_by_user_id | created_at | updated_at | updated_at | is_active | | is_earned | is_active | | is_completed | new_values | |
| last_login | | is_active | deactivated_at | created_at | updated_at | | | created_at | | created_at | created_at | | created_at | ip_address | |
| is_active | | created_at | version | updated_at | | | | updated_at | | | updated_at | | updated_at | user_agent | |
| timezone | | updated_at | | | | | | | | | | | | created_at | |
| email_verified | | | | | | | | | | | | | | | |

---

## Detailed Field Reference

### 1. `users`

| Field Name | Data Type | Constraints | Description |
|-----------|-----------|-------------|-------------|
| `user_id` | UUID | PRIMARY KEY | Unique identifier for each user |
| `email` | VARCHAR(255) | UNIQUE, NOT NULL, INDEXED | User's email address |
| `password_hash` | VARCHAR(255) | NOT NULL | Encrypted password hash |
| `username` | VARCHAR(100) | UNIQUE, NOT NULL, INDEXED | User's username |
| `full_name` | VARCHAR(255) | NULLABLE | User's full name |
| `created_at` | TIMESTAMPTZ | NOT NULL, INDEXED | Account creation timestamp |
| `updated_at` | TIMESTAMPTZ | NULLABLE | Last update timestamp |
| `last_login` | TIMESTAMPTZ | NULLABLE, INDEXED | Last login timestamp |
| `is_active` | BOOLEAN | NOT NULL, DEFAULT: true | Account active status |
| `timezone` | VARCHAR(50) | NOT NULL, DEFAULT: 'UTC' | User's timezone |
| `email_verified` | BOOLEAN | NOT NULL, DEFAULT: false | Email verification status |

**Relationships**: Referenced by `deed.user_id`, `entries.user_id`, `friend_relationships.requester_user_id`, `friend_relationships.receiver_user_id`, `daily_reflection_messages.user_id`, `targets.user_id`, `entries.edited_by_user_id`, `merit_evaluations.user_id`, `audit_logs.user_id`, `user_preferences.user_id`

**Special Features**: 
- Email format validation at database level (CHECK constraint)
- Partial indexes for active users only

---

### 2. `deed`

| Field Name | Data Type | Constraints | Description |
|-----------|-----------|-------------|-------------|
| `deed_id` | UUID | PRIMARY KEY | Unique identifier for each deed |
| `user_id` | UUID | FOREIGN KEY → users.user_id, NOT NULL, INDEXED | Owner of the deed (the user who created it) |
| `category_type` | ENUM | NOT NULL, INDEXED | 'hasanaat' or 'saiyyiaat' |
| `measure_type` | ENUM | NOT NULL | 'scale' or 'count' |
| `created_at` | TIMESTAMPTZ | NOT NULL, DEFAULT: CURRENT_TIMESTAMP | Creation timestamp |
| `updated_at` | TIMESTAMPTZ | NULLABLE | Last update timestamp |

**Relationships**: 
- Referenced by: `deed_items.deed_id`, `scale_definitions.deed_id`, `friend_deed_permissions.deed_id`

**Special Features**: 
- All deeds owned by users (user_id NOT NULL)
- Category and measure type enforced via ENUM

---

### 3. `deed_items`

| Field Name | Data Type | Constraints | Description |
|-----------|-----------|-------------|-------------|
| `deed_item_id` | UUID | PRIMARY KEY | Unique identifier for each deed item |
| `deed_id` | UUID | FOREIGN KEY → deed.deed_id, ON DELETE CASCADE, NOT NULL, INDEXED | The deed this item belongs to |
| `name` | VARCHAR(255) | NOT NULL | Name of the deed item |
| `description` | TEXT | NULLABLE | Optional description of the deed item |
| `level` | INTEGER | NOT NULL, DEFAULT: 0 | Level/nesting depth of the item |
| `hide_type` | ENUM | NOT NULL, DEFAULT: 'none' | 'none', 'hide_from_all', or 'hide_from_graphs' |
| `display_order` | INTEGER | NOT NULL, DEFAULT: 0 | Display order for UI |
| `is_active` | BOOLEAN | NOT NULL, DEFAULT: true | Deed item active status (soft delete) |
| `created_at` | TIMESTAMPTZ | NOT NULL, DEFAULT: CURRENT_TIMESTAMP | Creation timestamp |
| `updated_at` | TIMESTAMPTZ | NULLABLE | Last update timestamp |

**Relationships**: 
- Referenced by: `entries.deed_item_id`, `merit_items.deed_item_id`, `target_items.deed_item_id`

**Special Features**: 
- Items inherit `category_type` and `measure_type` from parent deed
- `level` field indicates nesting depth (0 for top-level items)
- Check constraints: `level >= 0`, `display_order >= 0`

---

### 4. `scale_definitions`

| Field Name | Data Type | Constraints | Description |
|-----------|-----------|-------------|-------------|
| `scale_id` | UUID | PRIMARY KEY | Unique identifier for each scale value |
| `deed_id` | UUID | FOREIGN KEY → deed.deed_id, ON DELETE CASCADE, NOT NULL, INDEXED | The deed this scale belongs to |
| `scale_value` | VARCHAR(100) | NOT NULL | The scale value (e.g., "Yes", "No", "Excellent", "Good") |
| `numeric_value` | INTEGER | NULLABLE | Numeric value for ordering/analytics (e.g., Yes=1, No=0) |
| `display_order` | INTEGER | NOT NULL | Display order for UI |
| `is_active` | BOOLEAN | NOT NULL, DEFAULT: true, INDEXED | Active status (versioning support) |
| `created_at` | TIMESTAMPTZ | NOT NULL, DEFAULT: CURRENT_TIMESTAMP, INDEXED | When this scale value was created |
| `deactivated_at` | TIMESTAMPTZ | NULLABLE | When this scale value was deactivated (versioning support) |
| `version` | INTEGER | NOT NULL, DEFAULT: 1 | Version number for this scale value (versioning support) |

**Special Features**: 
- Soft versioning: old scale values preserved when updated
- Unique constraint on `(deed_id, scale_value)` where `is_active = true` (partial unique index)
- Check constraint: `deactivated_at` must be NULL when `is_active = true`
- Check constraint: `version > 0`

**Relationships**: 
- Referenced by: `entries.measure_value` (via string match), `merit_items.scale_id`, `target_items.scale_id`

---

### 5. `entries` (PARTITIONED TABLE)

| Field Name | Data Type | Constraints | Description |
|-----------|-----------|-------------|-------------|
| `entry_id` | UUID | PRIMARY KEY (with entry_date) | Unique identifier for each entry |
| `user_id` | UUID | FOREIGN KEY → users.user_id, ON DELETE CASCADE, NOT NULL, INDEXED | Owner of the entry (deed owner) |
| `deed_item_id` | UUID | FOREIGN KEY → deed_items.deed_item_id, ON DELETE CASCADE, NOT NULL, INDEXED | The deed item being tracked |
| `entry_date` | DATE | NOT NULL, INDEXED, PARTITION KEY | Date of the entry |
| `measure_value` | VARCHAR(100) | NULLABLE | For scale-based deeds: stores the scale_value string |
| `count_value` | INTEGER | NULLABLE | For count-based deeds: stores numeric count |
| `edited_by_user_id` | UUID | FOREIGN KEY → users.user_id, NULLABLE | NULL for owner's entry, set when friend/follower edits |
| `created_at` | TIMESTAMPTZ | NOT NULL, DEFAULT: CURRENT_TIMESTAMP, INDEXED | Entry creation timestamp |
| `updated_at` | TIMESTAMPTZ | NULLABLE | Last update timestamp |

**Constraints**:
- Check: `(measure_value IS NOT NULL AND count_value IS NULL) OR (count_value IS NOT NULL AND measure_value IS NULL)`
- Check: `entry_date >= '2020-01-01' AND entry_date <= '2100-12-31'`
- Primary Key: `(entry_id, entry_date)` - composite key for partitioning
- Unique: Enforced via application logic due to partitioning

**Special Features**: 
- **Partitioned by entry_date** (monthly partitions) for performance and archival
- Supports friend/follower edits with full history
- Historical entries preserve references to inactive scale values
- Covering indexes for analytics queries

---

### 6. `friend_relationships`

| Field Name | Data Type | Constraints | Description |
|-----------|-----------|-------------|-------------|
| `relationship_id` | UUID | PRIMARY KEY | Unique identifier for each relationship |
| `requester_user_id` | UUID | FOREIGN KEY → users.user_id, ON DELETE CASCADE, NOT NULL, INDEXED | User who initiated the relationship |
| `receiver_user_id` | UUID | FOREIGN KEY → users.user_id, ON DELETE CASCADE, NOT NULL, INDEXED | User who received the request |
| `relationship_type` | ENUM | NOT NULL | 'friend' (mutual) or 'follow' (one-way) |
| `status` | ENUM | NOT NULL, DEFAULT: 'pending', INDEXED | 'pending', 'accepted', 'rejected', or 'blocked' |
| `accepted_at` | TIMESTAMPTZ | NULLABLE | When the relationship was accepted |
| `created_at` | TIMESTAMPTZ | NOT NULL, DEFAULT: CURRENT_TIMESTAMP, INDEXED | Relationship creation timestamp |
| `updated_at` | TIMESTAMPTZ | NULLABLE | Last update timestamp |

**Constraints**:
- Unique: `(requester_user_id, receiver_user_id, relationship_type)`
- Check: `requester_user_id != receiver_user_id` (no self-reference)
- Check: `(status = 'accepted' AND accepted_at IS NOT NULL) OR (status != 'accepted' AND accepted_at IS NULL)`

**Relationships**: Referenced by `friend_deed_permissions.relationship_id`

---

### 7. `friend_deed_permissions`

| Field Name | Data Type | Constraints | Description |
|-----------|-----------|-------------|-------------|
| `permission_id` | UUID | PRIMARY KEY | Unique identifier for each permission |
| `relationship_id` | UUID | FOREIGN KEY → friend_relationships.relationship_id, ON DELETE CASCADE, NOT NULL, INDEXED | The relationship this permission belongs to |
| `deed_id` | UUID | FOREIGN KEY → deed.deed_id, ON DELETE CASCADE, NOT NULL, INDEXED | The deed this permission applies to |
| `permission_type` | ENUM | NOT NULL | 'read' or 'write' |
| `is_active` | BOOLEAN | NOT NULL, DEFAULT: true | Permission active status |
| `created_at` | TIMESTAMPTZ | NOT NULL, DEFAULT: CURRENT_TIMESTAMP | Permission creation timestamp |
| `updated_at` | TIMESTAMPTZ | NULLABLE | Last update timestamp |

**Constraints**:
- Unique: `(relationship_id, deed_id, permission_type)`
- Partial unique index: Only one write permission allowed per deed (where `permission_type = 'write' AND is_active = true`)

**Special Features**: Multiple read permissions allowed per deed, only one write permission per deed

---

### 8. `daily_reflection_messages`

| Field Name | Data Type | Constraints | Description |
|-----------|-----------|-------------|-------------|
| `reflection_id` | UUID | PRIMARY KEY | Unique identifier for each reflection |
| `user_id` | UUID | FOREIGN KEY → users.user_id, ON DELETE CASCADE, NOT NULL, INDEXED | User who wrote the reflection |
| `reflection_date` | DATE | NOT NULL, INDEXED | Date of the reflection |
| `hasanaat_message` | TEXT | NULLABLE | Optional message for all hasanaat deeds of the day |
| `saiyyiaat_message` | TEXT | NULLABLE | Optional message for all saiyyiaat deeds of the day |
| `created_at` | TIMESTAMPTZ | NOT NULL, DEFAULT: CURRENT_TIMESTAMP | Reflection creation timestamp |
| `updated_at` | TIMESTAMPTZ | NULLABLE | Last update timestamp |

**Constraints**:
- Unique: `(user_id, reflection_date)` - one set of messages per user per day
- Check: `hasanaat_message IS NOT NULL OR saiyyiaat_message IS NOT NULL` (at least one message required)

**Special Features**: 
- Full-text search indexes on both message fields (GIN indexes)

---

### 9. `merits`

| Field Name | Data Type | Constraints | Description |
|-----------|-----------|-------------|-------------|
| `merit_id` | UUID | PRIMARY KEY | Unique identifier for each merit |
| `title` | VARCHAR(255) | NOT NULL | Short name for display in UI |
| `description` | TEXT | NULLABLE | Explains what it checks and why it matters |
| `merit_duration` | INTEGER | NOT NULL | Number of days the evaluation covers |
| `merit_type` | ENUM | NOT NULL | 'AND' (all linked deeds must satisfy) or 'OR' (any one deed satisfies) |
| `merit_category` | ENUM | NOT NULL | 'positive' (achievement-style) or 'negative' (demerit-style) |
| `is_active` | BOOLEAN | NOT NULL, DEFAULT: true | Merit active status |
| `created_at` | TIMESTAMPTZ | NOT NULL, DEFAULT: CURRENT_TIMESTAMP | Merit creation timestamp |
| `updated_at` | TIMESTAMPTZ | NULLABLE | Last update timestamp |

**Constraints**:
- Check: `merit_duration > 0 AND merit_duration <= 365`

**Special Features**: Time-based evaluation with AND/OR logic

**Relationships**: Referenced by `merit_items.merit_id`, `merit_evaluations.merit_id`

---

### 10. `merit_items`

| Field Name | Data Type | Constraints | Description |
|-----------|-----------|-------------|-------------|
| `merit_item_id` | UUID | PRIMARY KEY | Unique identifier for each merit item |
| `merit_id` | UUID | FOREIGN KEY → merits.merit_id, ON DELETE CASCADE, NOT NULL, INDEXED | The merit this item belongs to |
| `deed_item_id` | UUID | FOREIGN KEY → deed_items.deed_item_id, ON DELETE CASCADE, NOT NULL, INDEXED | The deed item this condition applies to |
| `merit_items_count` | INTEGER | NULLABLE | Required number of times (only for count-type deeds) |
| `scale_id` | UUID | FOREIGN KEY → scale_definitions.scale_id, NULLABLE | Required scale value (only for scale-type deeds) |
| `created_at` | TIMESTAMPTZ | NOT NULL, DEFAULT: CURRENT_TIMESTAMP | Item creation timestamp |

**Constraints**:
- Check: Only one of `merit_items_count` or `scale_id` can be set (not both, not neither)
- Check: `merit_items_count IS NULL OR merit_items_count > 0`

**Special Features**: Only one condition type per item (count OR scale)

---

### 11. `merit_evaluations` ⭐ NEW TABLE

| Field Name | Data Type | Constraints | Description |
|-----------|-----------|-------------|-------------|
| `evaluation_id` | UUID | PRIMARY KEY | Unique identifier for each evaluation |
| `user_id` | UUID | FOREIGN KEY → users.user_id, ON DELETE CASCADE, NOT NULL, INDEXED | User being evaluated |
| `merit_id` | UUID | FOREIGN KEY → merits.merit_id, ON DELETE CASCADE, NOT NULL, INDEXED | The merit being evaluated |
| `evaluation_date` | DATE | NOT NULL, INDEXED | Date when the evaluation was performed |
| `evaluation_period_start` | DATE | NOT NULL | Start date of the evaluation period |
| `evaluation_period_end` | DATE | NOT NULL | End date of the evaluation period |
| `is_earned` | BOOLEAN | NOT NULL | Whether the merit was earned (true) or not (false) |
| `created_at` | TIMESTAMPTZ | NOT NULL, DEFAULT: CURRENT_TIMESTAMP | Evaluation creation timestamp |

**Constraints**:
- Unique: `(user_id, merit_id, evaluation_date)` - one evaluation per user per merit per date
- Check: `evaluation_period_end >= evaluation_period_start`

**Special Features**: Tracks when users earn merits/demerits, enabling analytics and notifications

**Relationships**: 
- References: `users.user_id`, `merits.merit_id`

---

### 12. `targets`

| Field Name | Data Type | Constraints | Description |
|-----------|-----------|-------------|-------------|
| `target_id` | UUID | PRIMARY KEY | Unique identifier for each target |
| `user_id` | UUID | FOREIGN KEY → users.user_id, ON DELETE CASCADE, NOT NULL, INDEXED | User who created the target |
| `title` | VARCHAR(255) | NOT NULL | Name of the target |
| `description` | TEXT | NULLABLE | Explanation of the goal |
| `start_date` | DATE | NOT NULL, INDEXED | When the target starts |
| `end_date` | DATE | NOT NULL, INDEXED | When the target ends |
| `is_active` | BOOLEAN | NOT NULL, DEFAULT: true | Target active status |
| `created_at` | TIMESTAMPTZ | NOT NULL, DEFAULT: CURRENT_TIMESTAMP | Target creation timestamp |
| `updated_at` | TIMESTAMPTZ | NULLABLE | Last update timestamp |

**Constraints**:
- Check: `end_date >= start_date`
- Check: `end_date >= CURRENT_DATE` (future dates only)
- Unique: `(user_id, title, start_date)`

**Special Features**: Time-bounded goals with date ranges

**Relationships**: Referenced by `target_items.target_id`, `target_progress.target_id`

---

### 13. `target_items`

| Field Name | Data Type | Constraints | Description |
|-----------|-----------|-------------|-------------|
| `target_item_id` | UUID | PRIMARY KEY | Unique identifier for each target item |
| `target_id` | UUID | FOREIGN KEY → targets.target_id, ON DELETE CASCADE, NOT NULL, INDEXED | The target this item belongs to |
| `deed_item_id` | UUID | FOREIGN KEY → deed_items.deed_item_id, ON DELETE CASCADE, NOT NULL, INDEXED | The deed item this condition applies to |
| `target_items_count` | INTEGER | NULLABLE | Required count (if count-based) |
| `scale_id` | UUID | FOREIGN KEY → scale_definitions.scale_id, NULLABLE | Required scale (if scale-based) |
| `created_at` | TIMESTAMPTZ | NOT NULL, DEFAULT: CURRENT_TIMESTAMP | Item creation timestamp |

**Constraints**:
- Check: Only one of `target_items_count` or `scale_id` can be set (not both, not neither)
- Check: `target_items_count IS NULL OR target_items_count > 0`

**Special Features**: Only one condition type per item (count OR scale)

---

### 14. `target_progress` ⭐ NEW TABLE

| Field Name | Data Type | Constraints | Description |
|-----------|-----------|-------------|-------------|
| `progress_id` | UUID | PRIMARY KEY | Unique identifier for each progress record |
| `target_id` | UUID | FOREIGN KEY → targets.target_id, ON DELETE CASCADE, NOT NULL, INDEXED | The target being tracked |
| `target_item_id` | UUID | FOREIGN KEY → target_items.target_item_id, ON DELETE CASCADE, NOT NULL, INDEXED | The target item being tracked |
| `progress_date` | DATE | NOT NULL, INDEXED | Date of the progress record |
| `current_count` | INTEGER | NOT NULL, DEFAULT: 0 | Current progress count |
| `required_count` | INTEGER | NOT NULL | Required count to complete |
| `is_completed` | BOOLEAN | NOT NULL, DEFAULT: false | Whether the target item is completed |
| `created_at` | TIMESTAMPTZ | NOT NULL, DEFAULT: CURRENT_TIMESTAMP | Progress record creation timestamp |
| `updated_at` | TIMESTAMPTZ | NULLABLE | Last update timestamp |

**Constraints**:
- Unique: `(target_id, target_item_id, progress_date)` - one progress record per target per item per date
- Check: `current_count >= 0 AND required_count > 0`
- Check: `(is_completed = true AND current_count >= required_count) OR (is_completed = false)`

**Special Features**: Tracks daily progress toward targets, enabling real-time progress visualization

**Relationships**: 
- References: `targets.target_id`, `target_items.target_item_id`

---

### 15. `audit_logs` ⭐ NEW TABLE (PARTITIONED)

| Field Name | Data Type | Constraints | Description |
|-----------|-----------|-------------|-------------|
| `audit_id` | UUID | PRIMARY KEY | Unique identifier for each audit log entry |
| `user_id` | UUID | FOREIGN KEY → users.user_id, ON DELETE SET NULL, NULLABLE | User who performed the action |
| `table_name` | ENUM | NOT NULL, INDEXED | Name of the table that was modified |
| `record_id` | UUID | NOT NULL, INDEXED | ID of the record that was modified |
| `action` | ENUM | NOT NULL, INDEXED | 'INSERT', 'UPDATE', 'DELETE', or 'SELECT' |
| `old_values` | JSONB | NULLABLE | Previous values (for UPDATE/DELETE) |
| `new_values` | JSONB | NULLABLE, INDEXED (GIN) | New values (for INSERT/UPDATE) |
| `ip_address` | INET | NULLABLE | IP address of the user |
| `user_agent` | TEXT | NULLABLE | User agent string |
| `created_at` | TIMESTAMPTZ | NOT NULL, DEFAULT: CURRENT_TIMESTAMP, INDEXED, PARTITION KEY | When the audit log was created |

**Special Features**: 
- **Partitioned by created_at** (monthly partitions) for performance and archival
- Comprehensive audit trail for compliance, security, and debugging
- GIN index on `new_values` for JSONB queries
- Supports all CRUD operations

**Relationships**: 
- References: `users.user_id` (ON DELETE SET NULL)

---

### 16. `user_preferences` ⭐ NEW TABLE

| Field Name | Data Type | Constraints | Description |
|-----------|-----------|-------------|-------------|
| `preference_id` | UUID | PRIMARY KEY | Unique identifier for each preference |
| `user_id` | UUID | FOREIGN KEY → users.user_id, ON DELETE CASCADE, NOT NULL, INDEXED | User who owns the preference |
| `preference_key` | VARCHAR(100) | NOT NULL, INDEXED | Key/name of the preference |
| `preference_value` | JSONB | NOT NULL | Value of the preference (flexible JSON structure) |
| `created_at` | TIMESTAMPTZ | NOT NULL, DEFAULT: CURRENT_TIMESTAMP | Preference creation timestamp |
| `updated_at` | TIMESTAMPTZ | NULLABLE | Last update timestamp |

**Constraints**:
- Unique: `(user_id, preference_key)` - one preference per user per key

**Special Features**: Flexible storage for user settings, notification preferences, UI preferences, etc.

**Relationships**: 
- References: `users.user_id`

---

## Summary Statistics

- **Total Tables**: 16
- **Total Fields**: 130 (across all tables)
- **Core Tables**: 5 (users, deed, deed_items, entries, scale_definitions)
- **Social Tables**: 2 (friend_relationships, friend_deed_permissions)
- **Evaluation Tables**: 5 (merits, merit_items, merit_evaluations, targets, target_items, target_progress)
- **Message Tables**: 1 (daily_reflection_messages)
- **System Tables**: 2 (audit_logs, user_preferences)
- **Partitioned Tables**: 2 (entries, audit_logs)

## Key Design Patterns

1. **UUID Primary Keys**: All tables use UUID (v4) for primary keys
2. **Soft Deletes**: Most tables use `is_active` flag instead of hard deletes
3. **Versioning**: `scale_definitions` supports soft versioning with historical preservation
4. **Deed Structure**: `deed` table defines category and measure type; `deed_items` contains the actual items with level-based nesting
5. **Audit Trails**: All tables include `created_at` and most include `updated_at` timestamps
6. **Foreign Key Cascades**: Most foreign keys use `ON DELETE CASCADE` for data integrity
7. **ENUM Types**: Used for categorical data (category_type, measure_type, relationship_type, status, etc.)
8. **Indexed Fields**: Critical fields are indexed for query performance
9. **Partitioning**: Time-series tables (`entries`, `audit_logs`) are partitioned by date for scalability
10. **Covering Indexes**: Analytics queries use covering indexes with INCLUDE clause
11. **Partial Indexes**: Space-efficient indexes on active records only
12. **JSONB Storage**: Flexible data storage in `user_preferences` and `audit_logs`

## Field Type Distribution

- **UUID**: 30 fields (primary keys and foreign keys)
- **VARCHAR**: 10 fields (names, emails, usernames, scale values, preference keys)
- **TEXT**: 6 fields (descriptions, messages, user agent)
- **TIMESTAMPTZ**: 24 fields (created_at, updated_at, dates with timezone)
- **DATE**: 6 fields (entry_date, reflection_date, start_date, end_date, evaluation_date, progress_date)
- **INTEGER**: 10 fields (counts, durations, orders, versions, levels)
- **BOOLEAN**: 8 fields (is_active flags, email_verified, is_earned, is_completed)
- **ENUM**: 8 fields (categories, types, statuses, actions)
- **JSONB**: 3 fields (preference_value, old_values, new_values)
- **INET**: 1 field (ip_address)

## Enterprise Features

### Partitioning
- **entries**: Partitioned by `entry_date` (monthly partitions)
- **audit_logs**: Partitioned by `created_at` (monthly partitions)
- Benefits: Faster queries, easier archival, better maintenance

### Advanced Indexing
- **Covering Indexes**: Include frequently selected columns to avoid table lookups
- **Partial Indexes**: Index only active records to save space
- **GIN Indexes**: Full-text search and JSONB queries
- **Composite Indexes**: Optimized for complex query patterns

### Data Integrity
- **Comprehensive Check Constraints**: Business logic enforced at database level
- **Foreign Key Cascades**: Automatic cleanup of related records
- **Unique Constraints**: Prevent duplicate data
- **Email Validation**: Format validation at database level

### Audit & Compliance
- **audit_logs Table**: Complete audit trail for all operations
- **Partitioned Audit Logs**: Scalable audit logging
- **JSONB Storage**: Flexible storage of old/new values

### User Preferences
- **Flexible JSONB Storage**: Store any user preference structure
- **Key-Value Pattern**: Simple and extensible preference system

