# sub_deeds Table

## Overview
The `sub_deeds` table stores sub-deeds that belong to parent deeds. Sub-deeds allow hierarchical organization of deeds, where a parent deed (like "Namaz") can have multiple sub-deeds (like "Fajr", "Zuhr", "Asr", "Maghrib", "Isha"). Sub-deeds inherit the measurement type from their parent deed.

## Purpose
- Organize deeds hierarchically (parent-child relationship)
- Break down complex deeds into trackable components
- Support entry creation at sub-deed level
- Control visibility with hide types
- Maintain display order for UI presentation

## Schema

```sql
CREATE TABLE sub_deeds (
    sub_deed_id UUID PRIMARY KEY,
    deed_id UUID NOT NULL REFERENCES deeds(deed_id) ON DELETE CASCADE,
    name VARCHAR NOT NULL,
    display_order INTEGER NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT true,
    hide_type ENUM('none', 'hide_from_all', 'hide_from_graphs') NOT NULL DEFAULT 'none',
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_sub_deeds_deed ON sub_deeds(deed_id);
CREATE INDEX idx_sub_deeds_hide_type ON sub_deeds(hide_type, is_active);
```

## Fields

### `sub_deed_id` (UUID, Primary Key)
- **Type**: UUID (v4)
- **Purpose**: Unique identifier for each sub-deed
- **Characteristics**: 
  - Globally unique
  - Used as foreign key in `sub_entry_values` table
- **Example**: `770e8400-e29b-41d4-a716-446655440001`

### `deed_id` (UUID, Foreign Key, Not Null)
- **Type**: UUID
- **Purpose**: References the parent deed
- **Foreign Key**: `deeds.deed_id`
- **Constraints**: NOT NULL (every sub-deed must have a parent)
- **Cascade**: ON DELETE CASCADE (if parent deed is deleted, sub-deeds are deleted)
- **Usage**: Links sub-deed to its parent deed
- **Example**: For sub-deed "Fajr", this would reference the "Namaz" deed

### `name` (VARCHAR, Not Null)
- **Type**: VARCHAR
- **Purpose**: Name of the sub-deed
- **Constraints**: Required (NOT NULL)
- **Usage**: Displayed in UI for entry selection
- **Examples**: 
  - `'Fajr'` (under Namaz deed)
  - `'Zuhr'` (under Namaz deed)
  - `'Asr'` (under Namaz deed)
  - `'Maghrib'` (under Namaz deed)
  - `'Isha'` (under Namaz deed)
  - `'Ramadan Fasts'` (under Fasts deed)

### `display_order` (INTEGER, Default: 0)
- **Type**: INTEGER
- **Purpose**: Controls the order in which sub-deeds are displayed in the UI
- **Default**: `0`
- **Usage**: 
  - Lower numbers appear first
  - Used for sorting sub-deeds in input forms and lists
  - Example: Fajr=1, Zuhr=2, Asr=3, Maghrib=4, Isha=5
- **Note**: Can be negative or positive integers

### `is_active` (BOOLEAN, Default: true)
- **Type**: BOOLEAN
- **Purpose**: Soft delete flag
- **Values**:
  - `true`: Active sub-deed (visible and usable)
  - `false`: Deactivated sub-deed (hidden but not deleted)
- **Default**: `true`
- **Usage**: 
  - Soft delete (preserves data)
  - Temporarily hide sub-deeds
  - Filter active sub-deeds in queries

### `hide_type` (ENUM, Default: 'none')
- **Type**: ENUM('none', 'hide_from_all', 'hide_from_graphs')
- **Purpose**: Controls visibility of the sub-deed
- **Values**:
  - `'none'`: Visible everywhere (default)
  - `'hide_from_all'`: Hidden from both input forms AND graphs
    - Example: "Ramadan Fasts" sub-deed when not in Ramadan
  - `'hide_from_graphs'`: Visible in input forms but hidden in graphs only
- **Default**: `'none'`
- **Usage**: 
  - Conditional visibility based on date/context
  - Hide seasonal sub-deeds when not relevant
  - Show in inputs but exclude from analytics

### `created_at` (TIMESTAMP)
- **Type**: TIMESTAMP
- **Purpose**: Records when the sub-deed was created
- **Default**: CURRENT_TIMESTAMP
- **Usage**: Track creation time

## Indexes

```sql
CREATE INDEX idx_sub_deeds_deed ON sub_deeds(deed_id);
CREATE INDEX idx_sub_deeds_hide_type ON sub_deeds(hide_type, is_active);
```

## Relationships

The `sub_deeds` table is referenced by:

1. **deeds** (parent deed)
   - `sub_deeds.deed_id` → `deeds.deed_id`
   - Many sub-deeds belong to one deed
   - CASCADE DELETE: If deed is deleted, sub-deeds are deleted

2. **sub_entry_values** (entry values for sub-deeds)
   - `sub_entry_values.sub_deed_id` → `sub_deeds.sub_deed_id`
   - One sub-deed can have many entry values
   - CASCADE DELETE: If sub-deed is deleted, entry values are deleted

## Constraints

- **Primary Key**: `sub_deed_id` (unique, not null)
- **Foreign Key**: `deed_id` → `deeds.deed_id` (NOT NULL, CASCADE on delete)
- **Inheritance Constraint**: Sub-deeds inherit `measure_type` from parent deed (enforced at application level)

## Important Rules

### 1. Measure Type Inheritance
- Sub-deeds **inherit** the `measure_type` from their parent deed
- If parent deed is `scale_based`, all sub-deeds are `scale_based`
- If parent deed is `count_based`, all sub-deeds are `count_based`
- No separate `measure_type` column in `sub_deeds` table

### 2. Entry Creation Rule
- **If a deed has sub-deeds**: Entries can ONLY be created for sub-deeds (via `sub_entry_values` table)
- **Cannot create entry directly for the parent deed** if it has sub-deeds
- Example: For "Namaz" deed with sub-deeds (Fajr, Zuhr, etc.), you can only log to Fajr, Zuhr, etc. - not to "Namaz" directly

### 3. Hide Type Behavior
- `hide_from_all`: Sub-deed is completely hidden from UI (input forms and graphs)
- `hide_from_graphs`: Sub-deed appears in input forms but is excluded from analytics/graphs
- `none`: Sub-deed is visible everywhere

## Example Data

### Namaz Sub-Deeds
```sql
-- Fajr
INSERT INTO sub_deeds (
    sub_deed_id,
    deed_id,
    name,
    display_order,
    is_active,
    hide_type
) VALUES (
    '770e8400-e29b-41d4-a716-446655440001',
    '660e8400-e29b-41d4-a716-446655440001',  -- Namaz deed_id
    'Fajr',
    1,
    true,
    'none'
);

-- Zuhr
INSERT INTO sub_deeds (
    sub_deed_id,
    deed_id,
    name,
    display_order,
    is_active,
    hide_type
) VALUES (
    '770e8400-e29b-41d4-a716-446655440002',
    '660e8400-e29b-41d4-a716-446655440001',  -- Namaz deed_id
    'Zuhr',
    2,
    true,
    'none'
);

-- Asr
INSERT INTO sub_deeds (
    sub_deed_id,
    deed_id,
    name,
    display_order,
    is_active,
    hide_type
) VALUES (
    '770e8400-e29b-41d4-a716-446655440003',
    '660e8400-e29b-41d4-a716-446655440001',  -- Namaz deed_id
    'Asr',
    3,
    true,
    'none'
);

-- Maghrib
INSERT INTO sub_deeds (
    sub_deed_id,
    deed_id,
    name,
    display_order,
    is_active,
    hide_type
) VALUES (
    '770e8400-e29b-41d4-a716-446655440004',
    '660e8400-e29b-41d4-a716-446655440001',  -- Namaz deed_id
    'Maghrib',
    4,
    true,
    'none'
);

-- Isha
INSERT INTO sub_deeds (
    sub_deed_id,
    deed_id,
    name,
    display_order,
    is_active,
    hide_type
) VALUES (
    '770e8400-e29b-41d4-a716-446655440005',
    '660e8400-e29b-41d4-a716-446655440001',  -- Namaz deed_id
    'Isha',
    5,
    true,
    'none'
);
```

### Fasts Sub-Deeds (with conditional hiding)
```sql
-- Regular Fasts
INSERT INTO sub_deeds (
    sub_deed_id,
    deed_id,
    name,
    display_order,
    is_active,
    hide_type
) VALUES (
    '770e8400-e29b-41d4-a716-446655440010',
    '660e8400-e29b-41d4-a716-446655440010',  -- Fasts deed_id
    'Regular Fasts',
    1,
    true,
    'none'
);

-- Ramadan Fasts (hidden when not in Ramadan)
INSERT INTO sub_deeds (
    sub_deed_id,
    deed_id,
    name,
    display_order,
    is_active,
    hide_type
) VALUES (
    '770e8400-e29b-41d4-a716-446655440011',
    '660e8400-e29b-41d4-a716-446655440010',  -- Fasts deed_id
    'Ramadan Fasts',
    2,
    true,
    'hide_from_all'  -- Hidden when not in Ramadan
);
```

## Usage Notes

1. **Display Order**: Use `display_order` to control UI presentation order
2. **Hide Type**: Update `hide_type` dynamically based on conditions (e.g., date-based for Ramadan)
3. **Soft Delete**: Use `is_active = false` instead of deleting records
4. **Measure Type**: Always check parent deed's `measure_type` when creating entries
5. **Entry Creation**: Only create entries for sub-deeds if parent deed has sub-deeds

## Business Rules

1. **Sub-deed Requirement**: If a deed has sub-deeds, entries must be created for sub-deeds only
2. **Measure Type Consistency**: All sub-deeds under a deed must use the same measure type (inherited from parent)
3. **Cascade Delete**: Deleting a deed automatically deletes all its sub-deeds
4. **Hide Type Updates**: Application should update `hide_type` based on context (e.g., date checks for Ramadan)

