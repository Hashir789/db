# activity_logs Table

## Overview
The `activity_logs` table provides an audit trail for all entry modifications. It tracks who made changes (owner or friend), what action was performed (created, updated, deleted), and stores snapshots of old and new values for complete change history.

## Purpose
- Audit trail for entry modifications
- Track who made changes (owner vs. friend)
- Store before/after snapshots for change history
- Support compliance and security monitoring
- Enable rollback capabilities

## Schema

```sql
CREATE TABLE activity_logs (
    log_id UUID PRIMARY KEY,
    entry_id UUID NOT NULL REFERENCES entries(entry_id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(user_id),
    action_type ENUM('created', 'updated', 'deleted') NOT NULL,
    old_values JSONB,
    new_values JSONB,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_activity_logs_entry ON activity_logs(entry_id, created_at DESC);
CREATE INDEX idx_activity_logs_user_date ON activity_logs(user_id, created_at DESC);
```

## Fields

### `log_id` (UUID, Primary Key)
- **Type**: UUID (v4)
- **Purpose**: Unique identifier for each log entry
- **Characteristics**: Globally unique
- **Example**: `cc0e8400-e29b-41d4-a716-446655440001`

### `entry_id` (UUID, Foreign Key, Not Null)
- **Type**: UUID
- **Purpose**: References the entry that was modified
- **Foreign Key**: `entries.entry_id`
- **Constraints**: NOT NULL
- **Cascade**: ON DELETE CASCADE (if entry is deleted, logs are deleted)
- **Indexed**: Yes (for entry-based queries)
- **Usage**: Links log entry to the entry that was changed

### `user_id` (UUID, Foreign Key, Not Null)
- **Type**: UUID
- **Purpose**: Identifies who made the change
- **Foreign Key**: `users.user_id`
- **Constraints**: NOT NULL
- **Indexed**: Yes (for user-based queries)
- **Usage**: 
  - Can be the entry owner (`entries.user_id`)
  - Can be a friend (`entries.created_by_user_id` or `entries.updated_by_user_id`)
  - Used for audit and accountability

### `action_type` (ENUM, Not Null)
- **Type**: ENUM('created', 'updated', 'deleted')
- **Purpose**: Type of action performed
- **Values**:
  - `'created'`: Entry was created
  - `'updated'`: Entry was modified
  - `'deleted'`: Entry was deleted (soft delete)
- **Usage**: 
  - Filter logs by action type
  - Understand change patterns
  - Track creation vs. modification activity

### `old_values` (JSONB, Nullable)
- **Type**: JSONB
- **Purpose**: Snapshot of entry values before the change
- **Nullable**: Yes (null for 'created' actions)
- **Format**: JSON object containing entry fields
- **Usage**: 
  - Store previous state for rollback
  - Compare before/after values
  - Audit what changed
- **Example**: 
  ```json
  {
    "measure_value": "Prayed",
    "entry_date": "2024-01-15",
    "updated_at": "2024-01-15T10:00:00Z"
  }
  ```

### `new_values` (JSONB, Nullable)
- **Type**: JSONB
- **Purpose**: Snapshot of entry values after the change
- **Nullable**: Yes (null for 'deleted' actions)
- **Format**: JSON object containing entry fields
- **Usage**: 
  - Store new state
  - Compare before/after values
  - Audit what changed
- **Example**: 
  ```json
  {
    "measure_value": "Late",
    "entry_date": "2024-01-15",
    "updated_at": "2024-01-15T11:00:00Z"
  }
  ```

### `created_at` (TIMESTAMP, Indexed)
- **Type**: TIMESTAMP
- **Purpose**: Records when the log entry was created
- **Default**: CURRENT_TIMESTAMP
- **Indexed**: Yes (for chronological queries)
- **Usage**: 
  - Track when change occurred
  - Sort logs chronologically
  - Time-based audit queries

## Indexes

```sql
CREATE INDEX idx_activity_logs_entry ON activity_logs(entry_id, created_at DESC);
CREATE INDEX idx_activity_logs_user_date ON activity_logs(user_id, created_at DESC);
```

## Relationships

The `activity_logs` table is referenced by:

1. **entries** (the entry that was modified)
   - `activity_logs.entry_id` → `entries.entry_id`
   - One entry can have many log entries
   - CASCADE DELETE: If entry is deleted, logs are deleted

2. **users** (who made the change)
   - `activity_logs.user_id` → `users.user_id`
   - One user can have many log entries
   - Used for tracking user activity

## Constraints

- **Primary Key**: `log_id` (unique, not null)
- **Foreign Keys**: 
  - `entry_id` → `entries.entry_id` (NOT NULL, CASCADE on delete)
  - `user_id` → `users.user_id` (NOT NULL)

## Important Rules

### Rule 1: Log Creation
- Create log entry immediately after entry modification
- Use database triggers or application-level logging
- Ensure atomicity (log creation should be part of same transaction)

### Rule 2: Value Snapshots
- **For 'created'**: `old_values = NULL`, `new_values` contains all entry fields
- **For 'updated'**: `old_values` contains previous state, `new_values` contains new state
- **For 'deleted'**: `old_values` contains deleted entry, `new_values = NULL`

### Rule 3: JSONB Structure
- Store relevant entry fields in JSONB
- Include: `measure_value`, `count_value`, `entry_date`, `updated_at`, etc.
- Can include metadata: `reason`, `notes`, etc.

## Example Data

### Entry Created Log
```sql
INSERT INTO activity_logs (
    log_id,
    entry_id,
    user_id,
    action_type,
    old_values,
    new_values
) VALUES (
    'cc0e8400-e29b-41d4-a716-446655440001',
    '990e8400-e29b-41d4-a716-446655440001',  -- Entry ID
    '550e8400-e29b-41d4-a716-446655440000',  -- User who created
    'created',
    NULL,  -- No old values for creation
    '{
        "measure_value": "Prayed",
        "entry_date": "2024-01-15",
        "deed_id": "660e8400-e29b-41d4-a716-446655440002",
        "created_at": "2024-01-15T10:00:00Z"
    }'::jsonb
);
```

### Entry Updated Log
```sql
INSERT INTO activity_logs (
    log_id,
    entry_id,
    user_id,
    action_type,
    old_values,
    new_values
) VALUES (
    'cc0e8400-e29b-41d4-a716-446655440002',
    '990e8400-e29b-41d4-a716-446655440001',  -- Entry ID
    '550e8400-e29b-41d4-a716-446655440000',  -- User who updated
    'updated',
    '{
        "measure_value": "Prayed",
        "updated_at": "2024-01-15T10:00:00Z"
    }'::jsonb,  -- Old values
    '{
        "measure_value": "Late",
        "updated_at": "2024-01-15T11:00:00Z"
    }'::jsonb   -- New values
);
```

### Entry Deleted Log
```sql
INSERT INTO activity_logs (
    log_id,
    entry_id,
    user_id,
    action_type,
    old_values,
    new_values
) VALUES (
    'cc0e8400-e29b-41d4-a716-446655440003',
    '990e8400-e29b-41d4-a716-446655440001',  -- Entry ID
    '550e8400-e29b-41d4-a716-446655440000',  -- User who deleted
    'deleted',
    '{
        "measure_value": "Late",
        "entry_date": "2024-01-15",
        "deed_id": "660e8400-e29b-41d4-a716-446655440002",
        "updated_at": "2024-01-15T11:00:00Z"
    }'::jsonb,  -- Old values (deleted entry)
    NULL        -- No new values for deletion
);
```

### Friend Action Log
```sql
INSERT INTO activity_logs (
    log_id,
    entry_id,
    user_id,  -- Friend's user_id
    action_type,
    old_values,
    new_values
) VALUES (
    'cc0e8400-e29b-41d4-a716-446655440004',
    '990e8400-e29b-41d4-a716-446655440001',  -- Entry ID
    '550e8400-e29b-41d4-a716-446655440999',  -- Friend's user_id
    'updated',
    '{
        "measure_value": "Prayed",
        "updated_at": "2024-01-15T10:00:00Z"
    }'::jsonb,
    '{
        "measure_value": "Prayed in Mosque",
        "updated_at": "2024-01-15T12:00:00Z"
    }'::jsonb
);
```

## Usage Notes

1. **Automatic Logging**: Use database triggers or application-level hooks to automatically create logs
2. **Transaction Safety**: Ensure log creation is part of the same transaction as entry modification
3. **JSONB Queries**: Use PostgreSQL JSONB operators for querying log data
4. **Retention Policy**: Consider archiving old logs for performance
5. **Privacy**: Ensure logs comply with data privacy regulations
6. **Performance**: Indexes are critical for query performance on large log tables

## Business Rules

1. **Mandatory Logging**: Every entry modification should create a log entry
2. **Immutable Logs**: Logs should never be modified or deleted (append-only)
3. **Complete Snapshots**: Store all relevant fields in old_values/new_values
4. **User Tracking**: Always record who made the change (owner or friend)
5. **Cascade Delete**: Deleting an entry automatically deletes its logs

## Query Examples

### Get Change History for Entry
```sql
SELECT 
    action_type,
    old_values,
    new_values,
    created_at,
    u.username
FROM activity_logs al
JOIN users u ON al.user_id = u.user_id
WHERE entry_id = '990e8400-e29b-41d4-a716-446655440001'
ORDER BY created_at DESC;
```

### Get All Changes by User
```sql
SELECT 
    action_type,
    COUNT(*) as change_count
FROM activity_logs
WHERE user_id = '550e8400-e29b-41d4-a716-446655440000'
GROUP BY action_type;
```

### Find Entries Modified by Friends
```sql
SELECT DISTINCT entry_id
FROM activity_logs
WHERE user_id != (
    SELECT user_id FROM entries WHERE entry_id = activity_logs.entry_id
);
```


