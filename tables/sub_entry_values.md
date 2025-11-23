# sub_entry_values Table

## Overview
The `sub_entry_values` table stores entry values for sub-deeds. This table is used when a deed has sub-deeds (like Namaz with Fajr, Zuhr, Asr, Maghrib, Isha). Instead of creating entries directly for the parent deed, entries are created for each sub-deed through this table.

## Purpose
- Store entry values for sub-deeds
- Support hierarchical entry structure (parent entry → sub-deed values)
- Maintain same measurement types as parent deed (scale-based or count-based)
- Enable tracking of individual sub-deed performance

## Schema

```sql
CREATE TABLE sub_entry_values (
    sub_entry_value_id UUID PRIMARY KEY,
    entry_id UUID NOT NULL REFERENCES entries(entry_id) ON DELETE CASCADE,
    sub_deed_id UUID NOT NULL REFERENCES sub_deeds(sub_deed_id) ON DELETE CASCADE,
    measure_value VARCHAR,  -- For scale-based sub-deeds
    count_value INTEGER,    -- For count-based sub-deeds
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP
);

CREATE INDEX idx_sub_entry_values_entry ON sub_entry_values(entry_id);
CREATE INDEX idx_sub_entry_values_sub_deed ON sub_entry_values(sub_deed_id);
```

## Fields

### `sub_entry_value_id` (UUID, Primary Key)
- **Type**: UUID (v4)
- **Purpose**: Unique identifier for each sub-entry value
- **Characteristics**: Globally unique
- **Example**: `aa0e8400-e29b-41d4-a716-446655440001`

### `entry_id` (UUID, Foreign Key, Not Null)
- **Type**: UUID
- **Purpose**: References the parent entry
- **Foreign Key**: `entries.entry_id`
- **Constraints**: NOT NULL
- **Cascade**: ON DELETE CASCADE (if entry is deleted, sub-entry values are deleted)
- **Indexed**: Yes (for entry-based queries)
- **Usage**: Links sub-entry value to its parent entry
- **Note**: The parent entry's `deed_id` should be the deed that has sub-deeds

### `sub_deed_id` (UUID, Foreign Key, Not Null)
- **Type**: UUID
- **Purpose**: References the specific sub-deed this value is for
- **Foreign Key**: `sub_deeds.sub_deed_id`
- **Constraints**: NOT NULL
- **Cascade**: ON DELETE CASCADE (if sub-deed is deleted, sub-entry values are deleted)
- **Indexed**: Yes (for sub-deed-based queries)
- **Usage**: Links sub-entry value to the specific sub-deed
- **Example**: For Namaz entry, this would reference Fajr, Zuhr, Asr, Maghrib, or Isha sub-deed

### `measure_value` (VARCHAR, Nullable)
- **Type**: VARCHAR
- **Purpose**: Stores scale value for scale-based sub-deeds
- **Nullable**: Yes (only used for scale-based deeds)
- **Usage**: 
  - Contains the `scale_value` from `scale_definitions` table
  - Only set when parent deed's `measure_type = 'scale_based'`
  - Must match a valid `scale_value` for the parent deed
- **Examples**: 
  - `'Prayed'`, `'Late'`, `'Not Prayed'` (for Namaz sub-deeds)
  - `'Prayed in Mosque'`, `'Prayed at Home'` (for location-based scales)
- **Constraint**: Must be NULL for count-based deeds

### `count_value` (INTEGER, Nullable)
- **Type**: INTEGER
- **Purpose**: Stores numeric count for count-based sub-deeds
- **Nullable**: Yes (only used for count-based deeds)
- **Usage**: 
  - Contains the numeric count entered by user
  - Only set when parent deed's `measure_type = 'count_based'`
  - Used for aggregations and analytics
- **Examples**: 
  - `1` (one instance)
  - `5` (five instances)
- **Constraint**: Must be NULL for scale-based deeds

### `created_at` (TIMESTAMP)
- **Type**: TIMESTAMP
- **Purpose**: Records when the sub-entry value was created
- **Default**: CURRENT_TIMESTAMP
- **Usage**: Track creation time

### `updated_at` (TIMESTAMP)
- **Type**: TIMESTAMP
- **Purpose**: Tracks when the sub-entry value was last modified
- **Nullable**: Yes (null if never updated)
- **Usage**: Track modification time

## Indexes

```sql
CREATE INDEX idx_sub_entry_values_entry ON sub_entry_values(entry_id);
CREATE INDEX idx_sub_entry_values_sub_deed ON sub_entry_values(sub_deed_id);
```

## Relationships

The `sub_entry_values` table is referenced by:

1. **entries** (parent entry)
   - `sub_entry_values.entry_id` → `entries.entry_id`
   - One entry can have many sub-entry values
   - CASCADE DELETE: If entry is deleted, sub-entry values are deleted

2. **sub_deeds** (the sub-deed being tracked)
   - `sub_entry_values.sub_deed_id` → `sub_deeds.sub_deed_id`
   - One sub-deed can have many sub-entry values
   - CASCADE DELETE: If sub-deed is deleted, sub-entry values are deleted

## Constraints

- **Primary Key**: `sub_entry_value_id` (unique, not null)
- **Foreign Keys**: 
  - `entry_id` → `entries.entry_id` (NOT NULL, CASCADE on delete)
  - `sub_deed_id` → `sub_deeds.sub_deed_id` (NOT NULL, CASCADE on delete)
- **Check Constraints** (enforced at application level):
  - For scale-based deeds: `measure_value` must be NOT NULL, `count_value` must be NULL
  - For count-based deeds: `count_value` must be NOT NULL, `measure_value` must be NULL
  - `measure_value` must exist in `scale_definitions` for the parent deed (if scale-based)
  - `sub_deed_id` must belong to the same `deed_id` as the entry's `deed_id`

## Important Rules

### Rule 1: Only for Deeds with Sub-Deeds
- This table is **ONLY** used when the parent deed has sub-deeds
- If a deed has no sub-deeds, use the `entries` table directly
- Example: Namaz has sub-deeds → use this table; Lie has no sub-deeds → use entries table

### Rule 2: Measure Type Inheritance
- Sub-entry values inherit the `measure_type` from the parent deed
- If parent deed is `scale_based`, all sub-entry values must use `measure_value`
- If parent deed is `count_based`, all sub-entry values must use `count_value`

### Rule 3: Entry Structure
- First create an entry in `entries` table (for the parent deed)
- Then create sub-entry values in this table (one for each sub-deed)
- The entry's `deed_id` should match the sub-deed's parent `deed_id`

## Example Data

### Namaz Entry with Sub-Entry Values (Scale-Based)
```sql
-- First, create the parent entry
INSERT INTO entries (
    entry_id,
    user_id,
    deed_id,  -- Namaz deed_id
    entry_date,
    measure_value,
    count_value,
    created_by_user_id
) VALUES (
    '990e8400-e29b-41d4-a716-446655440010',
    '550e8400-e29b-41d4-a716-446655440000',  -- User ID
    '660e8400-e29b-41d4-a716-446655440001',  -- Namaz deed_id
    '2024-01-15',
    NULL,  -- NULL because we use sub_entry_values
    NULL,
    '550e8400-e29b-41d4-a716-446655440000'
);

-- Then, create sub-entry values for each prayer
-- Fajr
INSERT INTO sub_entry_values (
    sub_entry_value_id,
    entry_id,
    sub_deed_id,  -- Fajr sub_deed_id
    measure_value,
    count_value
) VALUES (
    'aa0e8400-e29b-41d4-a716-446655440001',
    '990e8400-e29b-41d4-a716-446655440010',  -- Parent entry
    '770e8400-e29b-41d4-a716-446655440001',  -- Fajr sub_deed_id
    'Prayed',
    NULL
);

-- Zuhr
INSERT INTO sub_entry_values (
    sub_entry_value_id,
    entry_id,
    sub_deed_id,  -- Zuhr sub_deed_id
    measure_value,
    count_value
) VALUES (
    'aa0e8400-e29b-41d4-a716-446655440002',
    '990e8400-e29b-41d4-a716-446655440010',  -- Parent entry
    '770e8400-e29b-41d4-a716-446655440002',  -- Zuhr sub_deed_id
    'Prayed',
    NULL
);

-- Asr
INSERT INTO sub_entry_values (
    sub_entry_value_id,
    entry_id,
    sub_deed_id,  -- Asr sub_deed_id
    measure_value,
    count_value
) VALUES (
    'aa0e8400-e29b-41d4-a716-446655440003',
    '990e8400-e29b-41d4-a716-446655440010',  -- Parent entry
    '770e8400-e29b-41d4-a716-446655440003',  -- Asr sub_deed_id
    'Late',
    NULL
);

-- Maghrib
INSERT INTO sub_entry_values (
    sub_entry_value_id,
    entry_id,
    sub_deed_id,  -- Maghrib sub_deed_id
    measure_value,
    count_value
) VALUES (
    'aa0e8400-e29b-41d4-a716-446655440004',
    '990e8400-e29b-41d4-a716-446655440010',  -- Parent entry
    '770e8400-e29b-41d4-a716-446655440004',  -- Maghrib sub_deed_id
    'Prayed',
    NULL
);

-- Isha
INSERT INTO sub_entry_values (
    sub_entry_value_id,
    entry_id,
    sub_deed_id,  -- Isha sub_deed_id
    measure_value,
    count_value
) VALUES (
    'aa0e8400-e29b-41d4-a716-446655440005',
    '990e8400-e29b-41d4-a716-446655440010',  -- Parent entry
    '770e8400-e29b-41d4-a716-446655440005',  -- Isha sub_deed_id
    'Not Prayed',
    NULL
);
```

### Namaz Entry with Location-Based Scale
```sql
-- Fajr - Prayed in Mosque
INSERT INTO sub_entry_values (
    sub_entry_value_id,
    entry_id,
    sub_deed_id,
    measure_value,
    count_value
) VALUES (
    'aa0e8400-e29b-41d4-a716-446655440010',
    '990e8400-e29b-41d4-a716-446655440010',
    '770e8400-e29b-41d4-a716-446655440001',  -- Fajr
    'Prayed in Mosque',
    NULL
);

-- Zuhr - Prayed at Home
INSERT INTO sub_entry_values (
    sub_entry_value_id,
    entry_id,
    sub_deed_id,
    measure_value,
    count_value
) VALUES (
    'aa0e8400-e29b-41d4-a716-446655440011',
    '990e8400-e29b-41d4-a716-446655440010',
    '770e8400-e29b-41d4-a716-446655440002',  -- Zuhr
    'Prayed at Home',
    NULL
);
```

## Usage Notes

1. **Parent Entry First**: Always create the parent entry in `entries` table before creating sub-entry values
2. **Sub-Deed Validation**: Ensure `sub_deed_id` belongs to the same `deed_id` as the entry's `deed_id`
3. **Measure Type**: Inherit measure type from parent deed
4. **Scale Validation**: For scale-based, validate measure_value exists in scale_definitions for the parent deed
5. **Complete Entry**: Typically create sub-entry values for all sub-deeds of the parent deed (though not required)

## Business Rules

1. **Sub-Deed Requirement**: Only use this table for deeds that have sub-deeds
2. **Measure Type Consistency**: Must match parent deed's measure_type
3. **Cascade Delete**: Deleting an entry automatically deletes all its sub-entry values
4. **Sub-Deed Validation**: sub_deed_id must belong to the same deed_id as the entry's deed_id


