# PostgreSQL Tables & Fields Reference

Complete reference of all tables and their fields in the Kitaab database schema.

## Quick Overview

| # | Table Name | Primary Purpose | Total Fields |
|---|-----------|----------------|--------------|
| 1 | `users` | User accounts and authentication | 9 |
| 2 | `deed` | Deed definitions (Hasanaat/Saiyyiaat) | 4 |
| 3 | `deed_items` | Deed items/sub-deeds | 8 |
| 4 | `scale_definitions` | Scale values for scale-based deeds with versioning | 9 |
| 5 | `entries` | Daily logging records for deeds | 8 |
| 6 | `friend_relationships` | Friend and follow relationships between users | 7 |
| 7 | `friend_deed_permissions` | Deed-level permissions for friends/followers | 6 |
| 8 | `daily_reflection_messages` | Daily reflection messages (Hasanaat/Saiyyiaat) | 6 |
| 9 | `merits` | Time-based evaluation rules (positive/negative) | 8 |
| 10 | `merit_items` | Conditions for each merit tied to specific deeds | 5 |
| 11 | `targets` | User-defined, time-bounded goals | 8 |
| 12 | `target_items` | Conditions for each target tied to specific deeds | 5 |

**Total Tables**: 12

---

## Complete Tables & Fields Matrix

| USERS | DEED | DEED_ITEMS | SCALE_DEFINITIONS | ENTRIES | FRIEND_RELATIONSHIPS | FRIEND_DEED_PERMISSIONS | DAILY_REFLECTION_MESSAGES | MERITS | MERIT_ITEMS | TARGETS | TARGET_ITEMS |
|-------|------|------------|-------------------|---------|----------------------|-------------------------|---------------------------|-------|-------------|---------|--------------|
| user_id | deed_id | deed_item_id | scale_id | entry_id | relationship_id | permission_id | reflection_id | merit_id | merit_item_id | target_id | target_item_id |
| email | user_id | deed_id | deed_id | user_id | requester_user_id | relationship_id | user_id | title | merit_id | user_id | target_id |
| password_hash | category_type (hasanaat/saiyyiaat) | name | scale_value | deed_item_id | receiver_user_id | deed_id | reflection_date | description | deed_item_id | title | deed_item_id |
| username | measure_type (scale/count) | description | numeric_value | entry_date | relationship_type (friend/follow) | permission_type (read/write) | hasanaat_message | merit_duration (in days) | merit_items_count | description | target_items_count |
| full_name | | level | display_order | measure_value | status (pending/accepted/rejected/blocked) | is_active | saiyyiaat_message | merit_type (AND/OR) | scale_id | start_date | scale_id |
| created_at | | hide_type | is_active | count_value | accepted_at | created_at | created_at | merit_category (positive/negative) | created_at | end_date | created_at |
| updated_at | | display_order | created_at | edited_by_user_id | created_at | updated_at | updated_at | is_active | | is_active | |
| last_login | | is_active | deactivated_at | created_at | updated_at | | | created_at | | created_at | |
| is_active | | created_at | version | updated_at | | | | updated_at | | updated_at | |
| timezone | | updated_at | | | | | | | | | |

---

## Detailed Field Reference

### 1. `users`

| Field Name | Data Type | Constraints | Description |
|-----------|-----------|-------------|-------------|
| `user_id` | UUID | PRIMARY KEY | Unique identifier for each user |
| `email` | VARCHAR | UNIQUE, NOT NULL, INDEXED | User's email address |
| `password_hash` | VARCHAR | NOT NULL | Encrypted password hash |
| `username` | VARCHAR | UNIQUE, NOT NULL, INDEXED | User's username |
| `full_name` | VARCHAR | NULLABLE | User's full name |
| `created_at` | TIMESTAMP | NOT NULL, INDEXED | Account creation timestamp |
| `updated_at` | TIMESTAMP | NULLABLE | Last update timestamp |
| `last_login` | TIMESTAMP | NULLABLE | Last login timestamp |
| `is_active` | BOOLEAN | NOT NULL, DEFAULT: true | Account active status |
| `timezone` | VARCHAR | NOT NULL, DEFAULT: 'UTC' | User's timezone |

**Relationships**: Referenced by `deed.user_id`, `entries.user_id`, `friend_relationships.requester_user_id`, `friend_relationships.receiver_user_id`, `daily_reflection_messages.user_id`, `targets.user_id`, `entries.edited_by_user_id`

---

### 2. `deed`

| Field Name | Data Type | Constraints | Description |
|-----------|-----------|-------------|-------------|
| `deed_id` | UUID | PRIMARY KEY | Unique identifier for each deed |
| `user_id` | UUID | FOREIGN KEY → users.user_id, NOT NULL, INDEXED | Owner of the deed (the user who created it) |
| `category_type` | ENUM | NOT NULL, INDEXED | 'hasanaat' or 'saiyyiaat' |
| `measure_type` | ENUM | NOT NULL | 'scale' or 'count' |

**Relationships**: 
- Referenced by: `deed_items.deed_id`, `scale_definitions.deed_id`, `friend_deed_permissions.deed_id`

---

### 3. `deed_items`

| Field Name | Data Type | Constraints | Description |
|-----------|-----------|-------------|-------------|
| `deed_item_id` | UUID | PRIMARY KEY | Unique identifier for each deed item |
| `deed_id` | UUID | FOREIGN KEY → deed.deed_id, ON DELETE CASCADE, NOT NULL, INDEXED | The deed this item belongs to |
| `name` | VARCHAR | NOT NULL | Name of the deed item |
| `description` | TEXT | NULLABLE | Optional description of the deed item |
| `level` | INTEGER | NOT NULL, DEFAULT: 0 | Level/nesting depth of the item |
| `hide_type` | ENUM | NOT NULL, DEFAULT: 'none' | 'none', 'hide_from_all', or 'hide_from_graphs' |
| `display_order` | INTEGER | NOT NULL, DEFAULT: 0 | Display order for UI |
| `is_active` | BOOLEAN | NOT NULL, DEFAULT: true | Deed item active status (soft delete) |
| `created_at` | TIMESTAMP | NOT NULL | Creation timestamp |
| `updated_at` | TIMESTAMP | NULLABLE | Last update timestamp |

**Relationships**: 
- Referenced by: `entries.deed_item_id`, `merit_items.deed_item_id`, `target_items.deed_item_id`

**Special Features**: 
- Items inherit `category_type` and `measure_type` from parent deed
- `level` field indicates nesting depth (0 for top-level items)

---

### 4. `scale_definitions`

| Field Name | Data Type | Constraints | Description |
|-----------|-----------|-------------|-------------|
| `scale_id` | UUID | PRIMARY KEY | Unique identifier for each scale value |
| `deed_id` | UUID | FOREIGN KEY → deed.deed_id, ON DELETE CASCADE, INDEXED | The deed this scale belongs to |
| `scale_value` | VARCHAR | NOT NULL | The scale value (e.g., "Yes", "No", "Excellent", "Good") |
| `numeric_value` | INTEGER | NULLABLE | Numeric value for ordering/analytics (e.g., Yes=1, No=0) |
| `display_order` | INTEGER | NOT NULL | Display order for UI |
| `is_active` | BOOLEAN | NOT NULL, DEFAULT: true, INDEXED | Active status (versioning support) |
| `created_at` | TIMESTAMP | NOT NULL, DEFAULT: CURRENT_TIMESTAMP, INDEXED | When this scale value was created |
| `deactivated_at` | TIMESTAMP | NULLABLE | When this scale value was deactivated (versioning support) |
| `version` | INTEGER | NOT NULL, DEFAULT: 1 | Version number for this scale value (versioning support) |

**Special Features**: 
- Soft versioning: old scale values preserved when updated
- Unique constraint on `(deed_id, scale_value)` where `is_active = true`
- Check constraint: `deactivated_at` must be NULL when `is_active = true`

**Relationships**: 
- Referenced by: `entries.measure_value` (via string match), `merit_items.scale_id`, `target_items.scale_id`

---

### 5. `entries`

| Field Name | Data Type | Constraints | Description |
|-----------|-----------|-------------|-------------|
| `entry_id` | UUID | PRIMARY KEY | Unique identifier for each entry |
| `user_id` | UUID | FOREIGN KEY → users.user_id, ON DELETE CASCADE, INDEXED | Owner of the entry (deed owner) |
| `deed_item_id` | UUID | FOREIGN KEY → deed_items.deed_item_id, ON DELETE CASCADE, INDEXED | The deed item being tracked |
| `entry_date` | DATE | NOT NULL, INDEXED | Date of the entry |
| `measure_value` | VARCHAR | NULLABLE | For scale-based deeds: stores the scale_value string |
| `count_value` | INTEGER | NULLABLE | For count-based deeds: stores numeric count |
| `edited_by_user_id` | UUID | FOREIGN KEY → users.user_id, NULLABLE | NULL for owner's entry, set when friend/follower edits |
| `created_at` | TIMESTAMP | NOT NULL, INDEXED | Entry creation timestamp |
| `updated_at` | TIMESTAMP | NULLABLE | Last update timestamp |

**Constraints**:
- Check: `(measure_value IS NOT NULL AND count_value IS NULL) OR (count_value IS NOT NULL AND measure_value IS NULL)`
- Unique: `(user_id, deed_item_id, entry_date, edited_by_user_id)`
- Trigger validation: `measure_value` must exist in `scale_definitions` for the deed

**Special Features**: 
- Supports friend/follower edits with full history
- Historical entries preserve references to inactive scale values

---

### 6. `friend_relationships`

| Field Name | Data Type | Constraints | Description |
|-----------|-----------|-------------|-------------|
| `relationship_id` | UUID | PRIMARY KEY | Unique identifier for each relationship |
| `requester_user_id` | UUID | FOREIGN KEY → users.user_id, ON DELETE CASCADE, INDEXED | User who initiated the relationship |
| `receiver_user_id` | UUID | FOREIGN KEY → users.user_id, ON DELETE CASCADE, INDEXED | User who received the request |
| `relationship_type` | ENUM | NOT NULL | 'friend' (mutual) or 'follow' (one-way) |
| `status` | ENUM | NOT NULL, DEFAULT: 'pending', INDEXED | 'pending', 'accepted', 'rejected', or 'blocked' |
| `accepted_at` | TIMESTAMP | NULLABLE | When the relationship was accepted |
| `created_at` | TIMESTAMP | NOT NULL, INDEXED | Relationship creation timestamp |
| `updated_at` | TIMESTAMP | NULLABLE | Last update timestamp |

**Constraints**:
- Unique: `(requester_user_id, receiver_user_id, relationship_type)`
- Check: `requester_user_id != receiver_user_id`

**Relationships**: Referenced by `friend_deed_permissions.relationship_id`

---

### 7. `friend_deed_permissions`

| Field Name | Data Type | Constraints | Description |
|-----------|-----------|-------------|-------------|
| `permission_id` | UUID | PRIMARY KEY | Unique identifier for each permission |
| `relationship_id` | UUID | FOREIGN KEY → friend_relationships.relationship_id, ON DELETE CASCADE, INDEXED | The relationship this permission belongs to |
| `deed_id` | UUID | FOREIGN KEY → deed.deed_id, ON DELETE CASCADE, INDEXED | The deed this permission applies to |
| `permission_type` | ENUM | NOT NULL | 'read' or 'write' |
| `is_active` | BOOLEAN | NOT NULL, DEFAULT: true | Permission active status |
| `created_at` | TIMESTAMP | NOT NULL | Permission creation timestamp |
| `updated_at` | TIMESTAMP | NULLABLE | Last update timestamp |

**Constraints**:
- Unique: `(relationship_id, deed_id, permission_type)`
- Only one write permission allowed per deed (enforced at application level)

**Special Features**: Multiple read permissions allowed per deed, only one write permission per deed

---

### 8. `daily_reflection_messages`

| Field Name | Data Type | Constraints | Description |
|-----------|-----------|-------------|-------------|
| `reflection_id` | UUID | PRIMARY KEY | Unique identifier for each reflection |
| `user_id` | UUID | FOREIGN KEY → users.user_id, ON DELETE CASCADE, INDEXED | User who wrote the reflection |
| `reflection_date` | DATE | NOT NULL, INDEXED | Date of the reflection |
| `hasanaat_message` | TEXT | NULLABLE | Optional message for all hasanaat deeds of the day |
| `saiyyiaat_message` | TEXT | NULLABLE | Optional message for all saiyyiaat deeds of the day |
| `created_at` | TIMESTAMP | NOT NULL | Reflection creation timestamp |
| `updated_at` | TIMESTAMP | NULLABLE | Last update timestamp |

**Constraints**:
- Unique: `(user_id, reflection_date)` - one set of messages per user per day
- At least one of `hasanaat_message` or `saiyyiaat_message` should be provided (enforced at application level)

---

### 9. `merits`

| Field Name | Data Type | Constraints | Description |
|-----------|-----------|-------------|-------------|
| `merit_id` | UUID | PRIMARY KEY | Unique identifier for each merit |
| `title` | VARCHAR | NOT NULL | Short name for display in UI |
| `description` | TEXT | NULLABLE | Explains what it checks and why it matters |
| `merit_duration` | INTEGER | NOT NULL | Number of days the evaluation covers |
| `merit_type` | ENUM | NOT NULL | 'AND' (all linked deeds must satisfy) or 'OR' (any one deed satisfies) |
| `merit_category` | ENUM | NOT NULL | 'positive' (achievement-style) or 'negative' (demerit-style) |
| `is_active` | BOOLEAN | NOT NULL, DEFAULT: true | Merit active status |
| `created_at` | TIMESTAMP | NOT NULL | Merit creation timestamp |
| `updated_at` | TIMESTAMP | NULLABLE | Last update timestamp |

**Special Features**: Time-based evaluation with AND/OR logic

**Relationships**: Referenced by `merit_items.merit_id`

---

### 10. `merit_items`

| Field Name | Data Type | Constraints | Description |
|-----------|-----------|-------------|-------------|
| `merit_item_id` | UUID | PRIMARY KEY | Unique identifier for each merit item |
| `merit_id` | UUID | FOREIGN KEY → merits.merit_id, ON DELETE CASCADE, INDEXED | The merit this item belongs to |
| `deed_item_id` | UUID | FOREIGN KEY → deed_items.deed_item_id, ON DELETE CASCADE, INDEXED | The deed item this condition applies to |
| `merit_items_count` | INTEGER | NULLABLE | Required number of times (only for count-type deeds) |
| `scale_id` | UUID | FOREIGN KEY → scale_definitions.scale_id, NULLABLE | Required scale value (only for scale-type deeds) |
| `created_at` | TIMESTAMP | NOT NULL | Item creation timestamp |

**Constraints**:
- Check: Only one of `merit_items_count` or `scale_id` can be set (not both, not neither)

**Special Features**: Only one condition type per item (count OR scale)

---

### 11. `targets`

| Field Name | Data Type | Constraints | Description |
|-----------|-----------|-------------|-------------|
| `target_id` | UUID | PRIMARY KEY | Unique identifier for each target |
| `user_id` | UUID | FOREIGN KEY → users.user_id, ON DELETE CASCADE, INDEXED | User who created the target |
| `title` | VARCHAR | NOT NULL | Name of the target |
| `description` | TEXT | NULLABLE | Explanation of the goal |
| `start_date` | DATE | NOT NULL, INDEXED | When the target starts |
| `end_date` | DATE | NOT NULL, INDEXED | When the target ends |
| `is_active` | BOOLEAN | NOT NULL, DEFAULT: true | Target active status |
| `created_at` | TIMESTAMP | NOT NULL | Target creation timestamp |
| `updated_at` | TIMESTAMP | NULLABLE | Last update timestamp |

**Constraints**:
- Check: `end_date >= start_date`
- Unique: `(user_id, title, start_date)`

**Special Features**: Time-bounded goals with date ranges

**Relationships**: Referenced by `target_items.target_id`

---

### 12. `target_items`

| Field Name | Data Type | Constraints | Description |
|-----------|-----------|-------------|-------------|
| `target_item_id` | UUID | PRIMARY KEY | Unique identifier for each target item |
| `target_id` | UUID | FOREIGN KEY → targets.target_id, ON DELETE CASCADE, INDEXED | The target this item belongs to |
| `deed_item_id` | UUID | FOREIGN KEY → deed_items.deed_item_id, ON DELETE CASCADE, INDEXED | The deed item this condition applies to |
| `target_items_count` | INTEGER | NULLABLE | Required count (if count-based) |
| `scale_id` | UUID | FOREIGN KEY → scale_definitions.scale_id, NULLABLE | Required scale (if scale-based) |
| `created_at` | TIMESTAMP | NOT NULL | Item creation timestamp |

**Constraints**:
- Check: Only one of `target_items_count` or `scale_id` can be set (not both, not neither)

**Special Features**: Only one condition type per item (count OR scale)

---

## Summary Statistics

- **Total Tables**: 12
- **Total Fields**: 84 (across all tables)
- **Core Tables**: 5 (users, deed, deed_items, entries, scale_definitions)
- **Social Tables**: 2 (friend_relationships, friend_deed_permissions)
- **Evaluation Tables**: 4 (merits, merit_items, targets, target_items)
- **Message Tables**: 1 (daily_reflection_messages)

## Key Design Patterns

1. **UUID Primary Keys**: All tables use UUID (v4) for primary keys
2. **Soft Deletes**: Most tables use `is_active` flag instead of hard deletes
3. **Versioning**: `scale_definitions` supports soft versioning with historical preservation
4. **Deed Structure**: `deed` table defines category and measure type; `deed_items` contains the actual items with level-based nesting
5. **Audit Trails**: All tables include `created_at` and most include `updated_at` timestamps
6. **Foreign Key Cascades**: Most foreign keys use `ON DELETE CASCADE` for data integrity
7. **ENUM Types**: Used for categorical data (category_type, measure_type, relationship_type, status, etc.)
8. **Indexed Fields**: Critical fields are indexed for query performance

## Field Type Distribution

- **UUID**: 24 fields (primary keys and foreign keys)
- **VARCHAR**: 9 fields (names, emails, usernames, scale values)
- **TEXT**: 5 fields (descriptions, messages)
- **TIMESTAMP**: 18 fields (created_at, updated_at, dates)
- **DATE**: 3 fields (entry_date, reflection_date, start_date, end_date)
- **INTEGER**: 7 fields (counts, durations, orders, versions, levels)
- **BOOLEAN**: 6 fields (is_active flags)
- **ENUM**: 6 fields (categories, types, statuses)
