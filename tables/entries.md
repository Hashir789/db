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
    edited_by_user_id UUID REFERENCES users(user_id),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP
);

-- Constraints
ALTER TABLE entries ADD CONSTRAINT check_measure_type 
  CHECK (
    (measure_value IS NOT NULL AND count_value IS NULL) OR
    (count_value IS NOT NULL AND measure_value IS NULL)
  );

ALTER TABLE entries ADD CONSTRAINT unique_entry_per_editor
  UNIQUE (user_id, deed_id, entry_date, edited_by_user_id);

-- Indexes
CREATE INDEX idx_entries_user_date ON entries(user_id, entry_date DESC);
CREATE INDEX idx_entries_deed_date ON entries(deed_id, entry_date DESC);
CREATE INDEX idx_entries_user_deed_date ON entries(user_id, deed_id, entry_date);
CREATE INDEX idx_entries_date_range ON entries(entry_date) WHERE entry_date >= CURRENT_DATE - INTERVAL '1 year';
CREATE INDEX idx_entries_edited_by ON entries(edited_by_user_id, entry_date DESC) WHERE edited_by_user_id IS NOT NULL;
CREATE INDEX idx_entries_user_date_edited ON entries(user_id, entry_date, edited_by_user_id);
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
- **Purpose**: The deed this entry is for (can be parent or child deed)
- **Foreign Key**: `deeds.deed_id`
- **Constraints**: NOT NULL
- **Cascade**: ON DELETE CASCADE (if deed is deleted, entries are deleted)
- **Indexed**: Yes (for deed-based queries)
- **Usage**: Links entry to the deed being tracked
- **Note**: Can reference either a parent deed or a child deed (sub-deed) - entries are created directly for the deed being tracked

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

### `edited_by_user_id` (UUID, Foreign Key, Nullable)
- **Type**: UUID
- **Purpose**: Tracks who edited the entry (for friend/follower edits)
- **Foreign Key**: `users.user_id`
- **Nullable**: Yes
- **Usage**: 
  - **NULL** = Entry created/edited by owner
  - **Set** = Entry created/edited by friend/follower
  - Creates new entry row when friend/follower edits (old value remains for history)
  - Used for audit trail and revert functionality

### `created_at` (TIMESTAMP, Indexed)
- **Type**: TIMESTAMP
- **Purpose**: Records when the entry was created
- **Default**: CURRENT_TIMESTAMP
- **Indexed**: Yes (for chronological queries)
- **Usage**: Track creation time for audit, sorting, and revert window (30 days)

### `updated_at` (TIMESTAMP)
- **Type**: TIMESTAMP
- **Purpose**: Tracks when the entry was last modified
- **Nullable**: Yes (null if never updated)
- **Usage**: Track modification time (auto-updated via trigger)

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

3. **users** (who edited - friend/follower)
   - `entries.edited_by_user_id` → `users.user_id`
   - Tracks friend/follower edits (NULL for owner's entries)

## Constraints

- **Primary Key**: `entry_id` (unique, not null)
- **Foreign Keys**: 
  - `user_id` → `users.user_id` (NOT NULL, CASCADE on delete)
  - `deed_id` → `deeds.deed_id` (NOT NULL, CASCADE on delete)
  - `edited_by_user_id` → `users.user_id` (nullable)
- **Unique Constraint**: `(user_id, deed_id, entry_date, edited_by_user_id)` - one entry per user per deed per date per editor
- **Check Constraints**:
  - Measure type consistency: `(measure_value IS NOT NULL AND count_value IS NULL) OR (count_value IS NOT NULL AND measure_value IS NULL)`
  - `measure_value` must exist in `scale_definitions` for the deed (if scale-based) - enforced via trigger

## Critical Entry Rules

### Rule 1: Direct Entry Creation
**Entries are created directly for the deed being tracked** (parent or child):
- **For any deed** (parent or child): Create entry with `deed_id` pointing to that specific deed
- **No separate sub-entry table**: All entries go directly into this table
- Example: For Namaz with child deeds (Fajr, Zuhr, etc.), create entries with `deed_id` pointing to Fajr, Zuhr, etc.
- Example: For "Lie" deed (no children), create entry with `deed_id` pointing to Lie deed

### Rule 2: Measure Type Consistency
- **Scale-based deeds**: Must set `measure_value` (from `scale_definitions`), `count_value` must be NULL
- **Count-based deeds**: Must set `count_value` (numeric), `measure_value` must be NULL
- Enforced at database level via check constraint

### Rule 3: Friend/Follower Edits
- **Owner entries**: `edited_by_user_id = NULL`
- **Friend/follower edits**: `edited_by_user_id = friend/follower's user_id`
- **History**: Creates new entry row when friend/follower edits (old value remains)
- **Revert Window**: Owner can revert friend/follower changes within 30 days (enforced via trigger)

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

### Entry Created by Friend/Follower
```sql
INSERT INTO entries (
    entry_id,
    user_id,
    deed_id,
    entry_date,
    measure_value,
    count_value,
    edited_by_user_id
) VALUES (
    '990e8400-e29b-41d4-a716-446655440003',
    '550e8400-e29b-41d4-a716-446655440000',  -- Entry owner
    '660e8400-e29b-41d4-a716-446655440002',  -- Lie deed_id
    '2024-01-15',
    'Yes',  -- Committed lie
    NULL,
    '550e8400-e29b-41d4-a716-446655440999'  -- Edited by friend/follower
);
```

### Entry for Child Deed (Namaz - Fajr)
```sql
INSERT INTO entries (
    entry_id,
    user_id,
    deed_id,  -- Points to Fajr child deed_id
    entry_date,
    measure_value,
    count_value,
    edited_by_user_id
) VALUES (
    '990e8400-e29b-41d4-a716-446655440004',
    '550e8400-e29b-41d4-a716-446655440000',  -- User ID
    '770e8400-e29b-41d4-a716-446655440001',  -- Fajr child deed_id
    '2024-01-15',
    'Prayed',  -- Scale value
    NULL,
    NULL  -- Created by owner
);
```

## Usage Notes

1. **Direct Entry Creation**: Create entries directly for the deed being tracked (parent or child)
2. **Measure Type**: Validate measure type matches deed's measure_type (enforced at database level)
3. **Scale Value Validation**: For scale-based, validate measure_value exists in scale_definitions (enforced via trigger)
4. **Unique Constraint**: One entry per user per deed per date per editor (update existing instead of creating duplicate)
5. **Friend Permissions**: Check friend permissions in `friend_deed_permissions` before allowing friend to create/update entries
6. **Date Handling**: Use user's timezone to determine entry_date
7. **Revert Window**: Friend/follower edits can be reverted within 30 days (enforced via trigger)

## Business Rules

1. **Entry Creation**: Entries are created directly for the deed being tracked (parent or child)
2. **Measure Type**: Must match deed's measure_type (enforced at database level)
3. **Scale Validation**: measure_value must exist in scale_definitions for the deed (enforced via trigger)
4. **Unique Entry**: One entry per user per deed per date per editor (enforced by unique constraint)
5. **Friend Access**: Friends/followers can create/update entries based on permissions in `friend_deed_permissions` table
6. **Edit History**: Friend/follower edits create new entry rows (old value remains for full history)
7. **Revert Window**: Owner can revert friend/follower changes within 30 days


