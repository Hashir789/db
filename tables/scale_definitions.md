# scale_definitions Table

## Overview
The `scale_definitions` table stores the possible scale values for scale-based deeds. This table defines what options users can select when logging entries for scale-based deeds (e.g., "Yes/No", "Excellent/Good/Average/Poor", "Prayed/Late/Not Prayed").

## Purpose
- Define scale values for scale-based deeds
- Provide ordering/numeric values for analytics
- Control display order in UI
- Support soft delete of scale values

## Schema

```sql
CREATE TABLE scale_definitions (
    scale_id UUID PRIMARY KEY,
    deed_id UUID NOT NULL REFERENCES deeds(deed_id) ON DELETE CASCADE,
    scale_value VARCHAR NOT NULL,
    numeric_value INTEGER,
    display_order INTEGER NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT true
);

CREATE INDEX idx_scale_definitions_deed ON scale_definitions(deed_id, is_active);
```

## Fields

### `scale_id` (UUID, Primary Key)
- **Type**: UUID (v4)
- **Purpose**: Unique identifier for each scale value
- **Characteristics**: Globally unique
- **Example**: `880e8400-e29b-41d4-a716-446655440001`

### `deed_id` (UUID, Foreign Key, Not Null)
- **Type**: UUID
- **Purpose**: References the deed this scale belongs to
- **Foreign Key**: `deeds.deed_id`
- **Constraints**: NOT NULL
- **Cascade**: ON DELETE CASCADE (if deed is deleted, scale definitions are deleted)
- **Usage**: Links scale values to their parent deed
- **Note**: Only scale-based deeds have entries in this table

### `scale_value` (VARCHAR, Not Null)
- **Type**: VARCHAR
- **Purpose**: The actual scale value text displayed to users
- **Constraints**: Required (NOT NULL)
- **Usage**: 
  - Displayed in UI dropdowns/selectors
  - Stored in `entries.measure_value` when user selects it
- **Examples**: 
  - `'Yes'`, `'No'` (for Yes/No deeds)
  - `'Prayed'`, `'Late'`, `'Not Prayed'` (for Namaz)
  - `'Excellent'`, `'Good'`, `'Average'`, `'Poor'` (for quality ratings)
  - `'Prayed in Mosque'`, `'Prayed at Home'` (for location-based scales)

### `numeric_value` (INTEGER, Nullable)
- **Type**: INTEGER
- **Purpose**: Numeric representation for analytics and calculations
- **Nullable**: Yes
- **Usage**: 
  - Used for trend analysis and aggregations
  - Enables mathematical operations on scale values
  - Higher values typically represent better outcomes
- **Examples**: 
  - Yes/No: `'Yes' = 1`, `'No' = 0`
  - Quality: `'Excellent' = 4`, `'Good' = 3`, `'Average' = 2`, `'Poor' = 1`
  - Prayer status: `'Prayed' = 2`, `'Late' = 1`, `'Not Prayed' = 0`
- **Note**: Should be set for meaningful analytics

### `display_order` (INTEGER, Not Null)
- **Type**: INTEGER
- **Purpose**: Controls the order in which scale values appear in UI
- **Constraints**: Required (NOT NULL)
- **Usage**: 
  - Lower numbers appear first
  - Used for sorting scale values in dropdowns
  - Typically ordered from best to worst or worst to best
- **Example**: 
  - For quality: Excellent=1, Good=2, Average=3, Poor=4
  - For prayer: Prayed=1, Late=2, Not Prayed=3

### `is_active` (BOOLEAN, Default: true)
- **Type**: BOOLEAN
- **Purpose**: Soft delete flag
- **Values**:
  - `true`: Active scale value (visible and selectable)
  - `false`: Deactivated scale value (hidden but not deleted)
- **Default**: `true`
- **Usage**: 
  - Soft delete (preserves historical data)
  - Temporarily hide scale values
  - Filter active scale values in queries

## Indexes

```sql
CREATE INDEX idx_scale_definitions_deed ON scale_definitions(deed_id, is_active);
```

## Relationships

The `scale_definitions` table is referenced by:

1. **deeds** (parent deed)
   - `scale_definitions.deed_id` → `deeds.deed_id`
   - One deed can have many scale definitions
   - CASCADE DELETE: If deed is deleted, scale definitions are deleted

2. **entries** (indirectly via scale_value)
   - `entries.measure_value` stores the `scale_value` string
   - Used for validation: `measure_value` must exist in `scale_definitions` for that deed

## Constraints

- **Primary Key**: `scale_id` (unique, not null)
- **Foreign Key**: `deed_id` → `deeds.deed_id` (NOT NULL, CASCADE on delete)
- **Validation**: `scale_value` must be unique per `deed_id` (enforced at application level)

## Important Rules

1. **Scale-Based Deeds Only**: This table is only used for deeds with `measure_type = 'scale_based'`
2. **Count-Based Deeds**: Deeds with `measure_type = 'count_based'` do not have entries in this table
3. **Validation**: When creating an entry, `measure_value` must match a `scale_value` from this table for the deed
4. **Numeric Value**: Should be set for meaningful analytics and trend calculations

## Example Data

### Namaz Deed Scale Values
```sql
-- Prayed
INSERT INTO scale_definitions (
    scale_id,
    deed_id,
    scale_value,
    numeric_value,
    display_order,
    is_active
) VALUES (
    '880e8400-e29b-41d4-a716-446655440001',
    '660e8400-e29b-41d4-a716-446655440001',  -- Namaz deed_id
    'Prayed',
    2,
    1,
    true
);

-- Late
INSERT INTO scale_definitions (
    scale_id,
    deed_id,
    scale_value,
    numeric_value,
    display_order,
    is_active
) VALUES (
    '880e8400-e29b-41d4-a716-446655440002',
    '660e8400-e29b-41d4-a716-446655440001',  -- Namaz deed_id
    'Late',
    1,
    2,
    true
);

-- Not Prayed
INSERT INTO scale_definitions (
    scale_id,
    deed_id,
    scale_value,
    numeric_value,
    display_order,
    is_active
) VALUES (
    '880e8400-e29b-41d4-a716-446655440003',
    '660e8400-e29b-41d4-a716-446655440001',  -- Namaz deed_id
    'Not Prayed',
    0,
    3,
    true
);
```

### Namaz with Location Scale Values
```sql
-- Prayed in Mosque
INSERT INTO scale_definitions (
    scale_id,
    deed_id,
    scale_value,
    numeric_value,
    display_order,
    is_active
) VALUES (
    '880e8400-e29b-41d4-a716-446655440010',
    '660e8400-e29b-41d4-a716-446655440001',  -- Namaz deed_id
    'Prayed in Mosque',
    3,
    1,
    true
);

-- Prayed at Home
INSERT INTO scale_definitions (
    scale_id,
    deed_id,
    scale_value,
    numeric_value,
    display_order,
    is_active
) VALUES (
    '880e8400-e29b-41d4-a716-446655440011',
    '660e8400-e29b-41d4-a716-446655440001',  -- Namaz deed_id
    'Prayed at Home',
    2,
    2,
    true
);

-- Late
INSERT INTO scale_definitions (
    scale_id,
    deed_id,
    scale_value,
    numeric_value,
    display_order,
    is_active
) VALUES (
    '880e8400-e29b-41d4-a716-446655440012',
    '660e8400-e29b-41d4-a716-446655440001',  -- Namaz deed_id
    'Late',
    1,
    3,
    true
);

-- Not Prayed
INSERT INTO scale_definitions (
    scale_id,
    deed_id,
    scale_value,
    numeric_value,
    display_order,
    is_active
) VALUES (
    '880e8400-e29b-41d4-a716-446655440013',
    '660e8400-e29b-41d4-a716-446655440001',  -- Namaz deed_id
    'Not Prayed',
    0,
    4,
    true
);
```

### Lie Deed Scale Values (Yes/No)
```sql
-- Yes (committed lie)
INSERT INTO scale_definitions (
    scale_id,
    deed_id,
    scale_value,
    numeric_value,
    display_order,
    is_active
) VALUES (
    '880e8400-e29b-41d4-a716-446655440020',
    '660e8400-e29b-41d4-a716-446655440002',  -- Lie deed_id
    'Yes',
    1,
    1,
    true
);

-- No (did not lie)
INSERT INTO scale_definitions (
    scale_id,
    deed_id,
    scale_value,
    numeric_value,
    display_order,
    is_active
) VALUES (
    '880e8400-e29b-41d4-a716-446655440021',
    '660e8400-e29b-41d4-a716-446655440002',  -- Lie deed_id
    'No',
    0,
    2,
    true
);
```

### Quality Rating Scale (for custom deeds)
```sql
-- Excellent
INSERT INTO scale_definitions (
    scale_id,
    deed_id,
    scale_value,
    numeric_value,
    display_order,
    is_active
) VALUES (
    '880e8400-e29b-41d4-a716-446655440030',
    '660e8400-e29b-41d4-a716-446655440003',  -- Custom deed_id
    'Excellent',
    4,
    1,
    true
);

-- Good
INSERT INTO scale_definitions (
    scale_id,
    deed_id,
    scale_value,
    numeric_value,
    display_order,
    is_active
) VALUES (
    '880e8400-e29b-41d4-a716-446655440031',
    '660e8400-e29b-41d4-a716-446655440003',  -- Custom deed_id
    'Good',
    3,
    2,
    true
);

-- Average
INSERT INTO scale_definitions (
    scale_id,
    deed_id,
    scale_value,
    numeric_value,
    display_order,
    is_active
) VALUES (
    '880e8400-e29b-41d4-a716-446655440032',
    '660e8400-e29b-41d4-a716-446655440003',  -- Custom deed_id
    'Average',
    2,
    3,
    true
);

-- Poor
INSERT INTO scale_definitions (
    scale_id,
    deed_id,
    scale_value,
    numeric_value,
    display_order,
    is_active
) VALUES (
    '880e8400-e29b-41d4-a716-446655440033',
    '660e8400-e29b-41d4-a716-446655440003',  -- Custom deed_id
    'Poor',
    1,
    4,
    true
);
```

## Usage Notes

1. **Validation**: Always validate that `measure_value` in entries exists in `scale_definitions` for that deed
2. **Numeric Value**: Set meaningful `numeric_value` for analytics (higher = better typically)
3. **Display Order**: Order scale values logically (best to worst or worst to best)
4. **Soft Delete**: Use `is_active = false` instead of deleting records (preserves historical data)
5. **Uniqueness**: Ensure `scale_value` is unique per `deed_id` (enforced at application level)

## Business Rules

1. **Scale-Based Only**: Only deeds with `measure_type = 'scale_based'` have entries in this table
2. **Validation**: `entries.measure_value` must match a `scale_value` from this table
3. **Cascade Delete**: Deleting a deed automatically deletes all its scale definitions
4. **Numeric Value**: Should be set for meaningful trend analysis and aggregations

