# entries Table

## Overview
The `entries` table stores daily deed entries logged by users. It is the core table for tracking user activities, storing either scale-based values (from predefined scales) or count-based values (numeric counts) depending on the deed's measurement type.

## Purpose
- Store daily deed entries for users
- Support both scale-based and count-based measurements
- Track who created/updated entries (owner or friend)
- Maintain one entry per user per deed per date
- Enable time-range analytics and reporting

## Schema

```sql
CREATE TABLE entries (
    entry_id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    deed_id UUID NOT NULL REFERENCES deeds(deed_id) ON DELETE CASCADE,
    entry_date DATE NOT NULL,
    measure_value VARCHAR,  -- For scale-based deeds
    count_value INTEGER,    -- For count-based deeds
    created_by_user_id UUID NOT NULL REFERENCES users(user_id),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP,
    updated_by_user_id UUID REFERENCES users(user_id)
);

CREATE INDEX idx_entries_user_date ON entries(user_id, entry_date DESC);
CREATE INDEX idx_entries_deed_date ON entries(deed_id, entry_date DESC);
CREATE INDEX idx_entries_user_deed_date ON entries(user_id, deed_id, entry_date);
CREATE INDEX idx_entries_date_range ON entries(entry_date) WHERE entry_date >= CURRENT_DATE - INTERVAL '1 year';
```

## Fields

### `entry_id` (UUID, Primary Key)
- **Type**: UUID (v4)
- **Purpose**: Unique identifier for each entry
- **Characteristics**: Globally unique
- **Example**: `990e8400-e29b-41d4-a716-446655440001`

### `user_id` (UUID, Foreign Key, Not Null)
- **Type**: UUID
- **Purpose**: The user who owns this entry
- **Foreign Key**: `users.user_id`
- **Constraints**: NOT NULL
- **Cascade**: ON DELETE CASCADE (if user is deleted, entries are deleted)
- **Indexed**: Yes (for user-based queries)
- **Usage**: Links entry to the user who owns it

### `deed_id` (UUID, Foreign Key, Not Null)
- **Type**: UUID
- **Purpose**: The deed this entry is for
- **Foreign Key**: `deeds.deed_id`
- **Constraints**: NOT NULL
- **Cascade**: ON DELETE CASCADE (if deed is deleted, entries are deleted)
- **Indexed**: Yes (for deed-based queries)
- **Usage**: Links entry to the deed being tracked
- **Note**: Only used for deeds WITHOUT sub-deeds (see Entry Rules below)

### `entry_date` (DATE, Not Null, Indexed)
- **Type**: DATE
- **Purpose**: The date for which this entry is logged
- **Constraints**: Required (NOT NULL)
- **Indexed**: Yes (for date-range queries)
- **Usage**: 
  - Used for daily tracking
  - Enables time-range analytics (daily, weekly, monthly, yearly)
  - Part of unique constraint (one entry per user per deed per date)
- **Example**: `'2024-01-15'`

### `measure_value` (VARCHAR, Nullable)
- **Type**: VARCHAR
- **Purpose**: Stores scale value for scale-based deeds
- **Nullable**: Yes (only used for scale-based deeds)
- **Usage**: 
  - Contains the `scale_value` from `scale_definitions` table
  - Only set when `deed.measure_type = 'scale_based'`
  - Must match a valid `scale_value` for the deed
- **Examples**: 
  - `'Prayed'`, `'Late'`, `'Not Prayed'` (for Namaz)
  - `'Yes'`, `'No'` (for Yes/No deeds)
  - `'Excellent'`, `'Good'`, `'Average'`, `'Poor'` (for quality ratings)
- **Constraint**: Must be NULL for count-based deeds

### `count_value` (INTEGER, Nullable)
- **Type**: INTEGER
- **Purpose**: Stores numeric count for count-based deeds
- **Nullable**: Yes (only used for count-based deeds)
- **Usage**: 
  - Contains the numeric count entered by user
  - Only set when `deed.measure_type = 'count_based'`
  - Used for aggregations and analytics
- **Examples**: 
  - `5` (5 times charity given)
  - `10` (10 pages of Quran read)
  - `3` (3 times backbiting)
- **Constraint**: Must be NULL for scale-based deeds

### `created_by_user_id` (UUID, Foreign Key, Not Null)
- **Type**: UUID
- **Purpose**: Tracks who created the entry (owner or friend)
- **Foreign Key**: `users.user_id`
- **Constraints**: NOT NULL
- **Usage**: 
  - If entry owner created it: `created_by_user_id = user_id`
  - If friend created it: `created_by_user_id = friend's user_id`
  - Used for audit trail and permission tracking

### `created_at` (TIMESTAMP, Indexed)
- **Type**: TIMESTAMP
- **Purpose**: Records when the entry was created
- **Default**: CURRENT_TIMESTAMP
- **Indexed**: Yes (for chronological queries)
- **Usage**: Track creation time for audit and sorting

### `updated_at` (TIMESTAMP)
- **Type**: TIMESTAMP
- **Purpose**: Tracks when the entry was last modified
- **Nullable**: Yes (null if never updated)
- **Usage**: Track modification time

### `updated_by_user_id` (UUID, Foreign Key, Nullable)
- **Type**: UUID
- **Purpose**: Tracks who last updated the entry
- **Foreign Key**: `users.user_id`
- **Nullable**: Yes (null if never updated)
- **Usage**: 
  - If entry owner updated it: `updated_by_user_id = user_id`
  - If friend updated it: `updated_by_user_id = friend's user_id`
  - Used for audit trail

## Indexes

```sql
CREATE INDEX idx_entries_user_date ON entries(user_id, entry_date DESC);
CREATE INDEX idx_entries_deed_date ON entries(deed_id, entry_date DESC);
CREATE INDEX idx_entries_user_deed_date ON entries(user_id, deed_id, entry_date);
CREATE INDEX idx_entries_date_range ON entries(entry_date) WHERE entry_date >= CURRENT_DATE - INTERVAL '1 year';
```

## Relationships

The `entries` table is referenced by:

1. **users** (entry owner)
   - `entries.user_id` → `users.user_id`
   - One user can have many entries
   - CASCADE DELETE: If user is deleted, entries are deleted

2. **deeds** (the deed being tracked)
   - `entries.deed_id` → `deeds.deed_id`
   - One deed can have many entries
   - CASCADE DELETE: If deed is deleted, entries are deleted

3. **users** (who created/updated)
   - `entries.created_by_user_id` → `users.user_id`
   - `entries.updated_by_user_id` → `users.user_id`
   - Tracks friend actions

4. **sub_entry_values** (sub-deed entry values)
   - `sub_entry_values.entry_id` → `entries.entry_id`
   - One entry can have many sub-entry values
   - CASCADE DELETE: If entry is deleted, sub-entry values are deleted

5. **activity_logs** (audit trail)
   - `activity_logs.entry_id` → `entries.entry_id`
   - One entry can have many activity log entries

## Constraints

- **Primary Key**: `entry_id` (unique, not null)
- **Foreign Keys**: 
  - `user_id` → `users.user_id` (NOT NULL, CASCADE on delete)
  - `deed_id` → `deeds.deed_id` (NOT NULL, CASCADE on delete)
  - `created_by_user_id` → `users.user_id` (NOT NULL)
  - `updated_by_user_id` → `users.user_id` (nullable)
- **Unique Constraint**: `(user_id, deed_id, entry_date)` - one entry per user per deed per date
- **Check Constraints** (enforced at application level):
  - For scale-based deeds: `measure_value` must be NOT NULL, `count_value` must be NULL
  - For count-based deeds: `count_value` must be NOT NULL, `measure_value` must be NULL
  - `measure_value` must exist in `scale_definitions` for the deed (if scale-based)

## Critical Entry Rules

### Rule 1: Deeds with Sub-Deeds
**If a deed has sub-deeds** (e.g., Namaz with Fajr, Zuhr, etc.):
- **DO NOT** create entries in this table for the parent deed
- **ONLY** create entries for sub-deeds using the `sub_entry_values` table
- Example: For "Namaz" deed, you can only log Fajr, Zuhr, Asr, Maghrib, Isha - NOT "Namaz" itself

### Rule 2: Deeds without Sub-Deeds
**If a deed has no sub-deeds** (e.g., Lie):
- **DO** create entries directly in this table for the deed
- **DO NOT** create sub-entry values
- Example: For "Lie" deed, log directly to "Lie" in this table

### Rule 3: Measure Type Consistency
- **Scale-based deeds**: Must set `measure_value` (from `scale_definitions`), `count_value` must be NULL
- **Count-based deeds**: Must set `count_value` (numeric), `measure_value` must be NULL

## Example Data

### Scale-Based Entry (Lie - No sub-deeds)
```sql
INSERT INTO entries (
    entry_id,
    user_id,
    deed_id,
    entry_date,
    measure_value,
    count_value,
    created_by_user_id
) VALUES (
    '990e8400-e29b-41d4-a716-446655440001',
    '550e8400-e29b-41d4-a716-446655440000',  -- User ID
    '660e8400-e29b-41d4-a716-446655440002',  -- Lie deed_id
    '2024-01-15',
    'No',  -- Did not lie
    NULL,  -- NULL for scale-based
    '550e8400-e29b-41d4-a716-446655440000'   -- Created by owner
);
```

### Count-Based Entry (Charity - No sub-deeds)
```sql
INSERT INTO entries (
    entry_id,
    user_id,
    deed_id,
    entry_date,
    measure_value,
    count_value,
    created_by_user_id
) VALUES (
    '990e8400-e29b-41d4-a716-446655440002',
    '550e8400-e29b-41d4-a716-446655440000',  -- User ID
    '660e8400-e29b-41d4-a716-446655440003',  -- Charity deed_id
    '2024-01-15',
    NULL,  -- NULL for count-based
    5,     -- 5 times charity given
    '550e8400-e29b-41d4-a716-446655440000'   -- Created by owner
);
```

### Entry Created by Friend
```sql
INSERT INTO entries (
    entry_id,
    user_id,
    deed_id,
    entry_date,
    measure_value,
    count_value,
    created_by_user_id
) VALUES (
    '990e8400-e29b-41d4-a716-446655440003',
    '550e8400-e29b-41d4-a716-446655440000',  -- Entry owner
    '660e8400-e29b-41d4-a716-446655440002',  -- Lie deed_id
    '2024-01-15',
    'Yes',  -- Committed lie
    NULL,
    '550e8400-e29b-41d4-a716-446655440999'  -- Created by friend
);
```

## Usage Notes

1. **Sub-Deed Check**: Always check if deed has sub-deeds before creating entry
2. **Measure Type**: Validate measure type matches deed's measure_type
3. **Scale Value Validation**: For scale-based, validate measure_value exists in scale_definitions
4. **Unique Constraint**: One entry per user per deed per date (update existing instead of creating duplicate)
5. **Friend Permissions**: Check friend permissions before allowing friend to create/update entries
6. **Date Handling**: Use user's timezone to determine entry_date

## Business Rules

1. **Entry Constraint**: Cannot create entry for deed with sub-deeds (must use sub_entry_values)
2. **Measure Type**: Must match deed's measure_type
3. **Scale Validation**: measure_value must exist in scale_definitions for the deed
4. **Unique Entry**: One entry per user per deed per date (enforced by unique constraint)
5. **Friend Access**: Friends can create/update entries based on permission_type in friend_relationships


