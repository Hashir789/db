# deeds Table

## Overview
The `deeds` table stores both system default deeds (like Namaz and Lie) and user-created custom deeds. It defines what users can track in the Kitaab platform, including their category (Hasanaat or Saiyyiaat) and measurement type.

## Purpose
- Store system default deeds available to all users
- Store user-created custom deeds
- Define deed categories (Hasanaat/Saiyyiaat)
- Define measurement types (scale-based or count-based)
- Control visibility with hide types
- Support soft delete functionality

## Schema

```sql
CREATE TABLE deeds (
    deed_id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    parent_deed_id UUID REFERENCES deeds(deed_id) ON DELETE CASCADE,
    name VARCHAR NOT NULL,
    description TEXT,
    category ENUM('hasanaat', 'saiyyiaat') NOT NULL,
    measure_type ENUM('scale_based', 'count_based') NOT NULL,
    is_default BOOLEAN NOT NULL DEFAULT false,
    is_active BOOLEAN NOT NULL DEFAULT true,
    hide_type ENUM('none', 'hide_from_all', 'hide_from_graphs') NOT NULL DEFAULT 'none',
    display_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP
);

CREATE INDEX idx_deeds_user_category ON deeds(user_id, category, is_active);
CREATE INDEX idx_deeds_default ON deeds(is_default) WHERE is_default = true;
CREATE INDEX idx_deeds_user_active ON deeds(user_id, is_active) WHERE is_active = true;
CREATE INDEX idx_deeds_hide_type ON deeds(hide_type, is_active);
CREATE INDEX idx_deeds_parent ON deeds(parent_deed_id, is_active);
CREATE INDEX idx_deeds_user_parent ON deeds(user_id, parent_deed_id, is_active);
CREATE INDEX idx_deeds_parent_active ON deeds(parent_deed_id, is_active) WHERE parent_deed_id IS NOT NULL AND is_active = true;
```

## Fields

### `deed_id` (UUID, Primary Key)
- **Type**: UUID (v4)
- **Purpose**: Unique identifier for each deed
- **Characteristics**: 
  - Globally unique
  - Used as foreign key in related tables
- **Example**: `660e8400-e29b-41d4-a716-446655440001`

### `user_id` (UUID, Foreign Key, Not Null)
- **Type**: UUID
- **Purpose**: Owner of the deed
- **Foreign Key**: `users.user_id`
- **Constraints**: NOT NULL (uniform ownership model)
- **Logic**:
  - **SYSTEM_USER_ID** = System default deed (available to all users)
  - **User UUID** = Custom deed created by that specific user
- **Cascade**: ON DELETE CASCADE (if user is deleted, their custom deeds are deleted)
- **Example**: 
  - `00000000-0000-0000-0000-000000000000` (SYSTEM_USER_ID) for default deed "Namaz"
  - `550e8400-e29b-41d4-a716-446655440000` for custom deed

### `parent_deed_id` (UUID, Foreign Key, Nullable)
- **Type**: UUID
- **Purpose**: References parent deed for hierarchical structure
- **Foreign Key**: `deeds.deed_id` (self-referencing)
- **Nullable**: Yes
- **Logic**:
  - **NULL** = Main deed (top-level)
  - **Set** = Child deed (sub-deed) under parent
- **Enables**: Unlimited nesting of deeds
- **Inheritance**: Child deeds inherit `measure_type` from parent (enforced via trigger)
- **Example**: 
  - `NULL` for main deed "Namaz"
  - `660e8400-e29b-41d4-a716-446655440001` (Namaz deed_id) for child deed "Fajr"

### `name` (VARCHAR, Not Null)
- **Type**: VARCHAR
- **Purpose**: Name of the deed
- **Constraints**: Required (NOT NULL)
- **Usage**: Displayed in UI, used for identification
- **Examples**: 
  - `'Namaz'` (default deed)
  - `'Lie'` (default deed)
  - `'Charity'` (custom deed)
  - `'Reading Quran'` (custom deed)

### `description` (TEXT, Nullable)
- **Type**: TEXT
- **Purpose**: Optional description or instructions for the deed
- **Nullable**: Yes
- **Usage**: 
  - Provide context about the deed
  - Include tracking instructions
  - Add notes or guidelines
- **Example**: `'Track your daily prayers. Each prayer can be marked as prayed, late, or missed.'`

### `category` (ENUM, Not Null, Indexed)
- **Type**: ENUM('hasanaat', 'saiyyiaat')
- **Purpose**: Categorizes the deed as good or bad
- **Values**:
  - `'hasanaat'`: Good deed (e.g., Namaz, Charity, Reading Quran)
  - `'saiyyiaat'`: Bad deed (e.g., Lie, Backbiting)
- **Indexed**: Yes (for filtering and analytics)
- **Usage**: 
  - Separate good and bad deeds in UI
  - Calculate balance between Hasanaat and Saiyyiaat
  - Filter entries by category

### `measure_type` (ENUM, Not Null)
- **Type**: ENUM('scale_based', 'count_based')
- **Purpose**: Defines how the deed is measured
- **Values**:
  - `'scale_based'`: User selects from predefined scale values (e.g., Yes/No, Excellent/Good/Average)
  - `'count_based'`: User enters a numeric count
- **Usage**: 
  - Determines which fields are used in entries table
  - For scale-based: uses `measure_value` in entries
  - For count-based: uses `count_value` in entries
- **Example**: 
  - Namaz: `'scale_based'` (prayed, late, not prayed)
  - Charity: `'count_based'` (number of times)

### `is_default` (BOOLEAN, Default: false, Indexed)
- **Type**: BOOLEAN
- **Purpose**: Indicates if this is a system default deed
- **Values**:
  - `true`: System default deed (e.g., Namaz, Lie)
  - `false`: Custom deed created by a user
- **Default**: `false`
- **Indexed**: Yes (for quick lookup of default deeds)
- **Note**: Default deeds have `user_id = NULL` and `is_default = true`

### `is_active` (BOOLEAN, Default: true)
- **Type**: BOOLEAN
- **Purpose**: Soft delete flag
- **Values**:
  - `true`: Active deed (visible and usable)
  - `false`: Deactivated deed (hidden but not deleted)
- **Default**: `true`
- **Usage**: 
  - Soft delete (preserves data)
  - Temporarily hide deeds
  - Filter active deeds in queries

### `hide_type` (ENUM, Default: 'none')
- **Type**: ENUM('none', 'hide_from_all', 'hide_from_graphs')
- **Purpose**: Controls visibility of the deed
- **Values**:
  - `'none'`: Visible everywhere (default)
  - `'hide_from_all'`: Hidden from both input forms AND graphs
    - Example: Ramadan Fasts when not in Ramadan
  - `'hide_from_graphs'`: Visible in input forms but hidden in graphs only
- **Default**: `'none'`
- **Usage**: 
  - Conditional visibility based on date/context
  - Hide seasonal deeds when not relevant
  - Show in inputs but exclude from analytics

### `created_at` (TIMESTAMP)
- **Type**: TIMESTAMP
- **Purpose**: Records when the deed was created
- **Default**: CURRENT_TIMESTAMP
- **Usage**: Track creation time for default and custom deeds

### `updated_at` (TIMESTAMP)
- **Type**: TIMESTAMP
- **Purpose**: Tracks when deed details were last modified
- **Nullable**: Yes
- **Usage**: Track modifications to deed properties

## Indexes

```sql
CREATE INDEX idx_deeds_user_category ON deeds(user_id, category, is_active);
CREATE INDEX idx_deeds_default ON deeds(is_default) WHERE is_default = true;
CREATE INDEX idx_deeds_user_active ON deeds(user_id, is_active) WHERE is_active = true;
CREATE INDEX idx_deeds_hide_type ON deeds(hide_type, is_active);
```

## Relationships

The `deeds` table is referenced by:

1. **deeds** (self-referencing: child deeds)
   - `deeds.parent_deed_id` → `deeds.deed_id`
   - One deed can have many child deeds (unlimited nesting)
   - CASCADE DELETE: If parent deed is deleted, child deeds are deleted

2. **scale_definitions** (scale values for scale-based deeds)
   - `scale_definitions.deed_id` → `deeds.deed_id`
   - One deed can have many scale definitions
   - CASCADE DELETE: If deed is deleted, scale definitions are deleted

3. **entries** (daily entries for this deed)
   - `entries.deed_id` → `deeds.deed_id`
   - One deed can have many entries
   - CASCADE DELETE: If deed is deleted, entries are deleted

4. **user_default_deeds** (which users have opted-in to default deeds)
   - `user_default_deeds.default_deed_id` → `deeds.deed_id`
   - One default deed can be opted-in by many users
   - CASCADE DELETE: If deed is deleted, user_default_deeds records are deleted

5. **achievements** (achievement conditions reference deed_id)
   - Referenced in `achievements.condition_config` JSONB field
   - Achievements can reference deeds in their conditions

6. **demerits** (demerit conditions reference deed_id)
   - Referenced in `demerits.condition_config` JSONB field
   - Demerits can reference deeds in their conditions

## Constraints

- **Primary Key**: `deed_id` (unique, not null)
- **Foreign Keys**: 
  - `user_id` → `users.user_id` (NOT NULL, CASCADE on delete)
  - `parent_deed_id` → `deeds.deed_id` (nullable, self-referencing, CASCADE on delete)
- **Check Constraint**: If `is_default = true`, then `user_id = SYSTEM_USER_ID` (enforced via trigger)
- **Trigger**: Child deeds must inherit `measure_type` from parent (enforced via trigger)

## Entry Rules

**Important**: Entries are created directly for the deed being tracked (parent or child):

1. **For any deed** (parent or child):
   - Entries are created directly in the `entries` table
   - Set `deed_id` to the specific deed being tracked
   - Example: For Namaz with child deeds (Fajr, Zuhr, etc.), create entries with `deed_id` pointing to Fajr, Zuhr, etc.

2. **No separate sub-entry table needed**:
   - The self-referencing structure eliminates the need for `sub_entry_values` table
   - All entries go directly into the `entries` table
   - Example: For "Lie" deed (no children), create entry with `deed_id` pointing to Lie deed

## Example Data

### Default Deed (Namaz - Parent)
```sql
INSERT INTO deeds (
    deed_id,
    user_id,
    parent_deed_id,
    name,
    description,
    category,
    measure_type,
    is_default,
    is_active,
    hide_type,
    display_order
) VALUES (
    '660e8400-e29b-41d4-a716-446655440001',
    '00000000-0000-0000-0000-000000000000',  -- SYSTEM_USER_ID
    NULL,  -- NULL for parent deeds
    'Namaz',
    'Daily prayers - track each prayer separately',
    'hasanaat',
    'scale_based',
    true,
    true,
    'none',
    0
);

-- Child deeds (Fajr, Zuhr, etc.)
INSERT INTO deeds (
    deed_id,
    user_id,
    parent_deed_id,
    name,
    description,
    category,
    measure_type,
    is_default,
    is_active,
    hide_type,
    display_order
) VALUES 
-- Fajr
('770e8400-e29b-41d4-a716-446655440001', '00000000-0000-0000-0000-000000000000', '660e8400-e29b-41d4-a716-446655440001', 'Fajr', 'Morning prayer', 'hasanaat', 'scale_based', true, true, 'none', 1),
-- Zuhr
('770e8400-e29b-41d4-a716-446655440002', '00000000-0000-0000-0000-000000000000', '660e8400-e29b-41d4-a716-446655440001', 'Zuhr', 'Midday prayer', 'hasanaat', 'scale_based', true, true, 'none', 2),
-- Asr
('770e8400-e29b-41d4-a716-446655440003', '00000000-0000-0000-0000-000000000000', '660e8400-e29b-41d4-a716-446655440001', 'Asr', 'Afternoon prayer', 'hasanaat', 'scale_based', true, true, 'none', 3),
-- Maghrib
('770e8400-e29b-41d4-a716-446655440004', '00000000-0000-0000-0000-000000000000', '660e8400-e29b-41d4-a716-446655440001', 'Maghrib', 'Evening prayer', 'hasanaat', 'scale_based', true, true, 'none', 4),
-- Isha
('770e8400-e29b-41d4-a716-446655440005', '00000000-0000-0000-0000-000000000000', '660e8400-e29b-41d4-a716-446655440001', 'Isha', 'Night prayer', 'hasanaat', 'scale_based', true, true, 'none', 5);
```

### Default Deed (Lie - No Children)
```sql
INSERT INTO deeds (
    deed_id,
    user_id,
    parent_deed_id,
    name,
    description,
    category,
    measure_type,
    is_default,
    is_active,
    hide_type,
    display_order
) VALUES (
    '660e8400-e29b-41d4-a716-446655440002',
    '00000000-0000-0000-0000-000000000000',  -- SYSTEM_USER_ID
    NULL,  -- No parent (main deed)
    'Lie',
    'Track instances of lying',
    'saiyyiaat',
    'scale_based',
    true,
    true,
    'none',
    0
);
```

### Custom Deed (Charity - No Children)
```sql
INSERT INTO deeds (
    deed_id,
    user_id,
    parent_deed_id,
    name,
    description,
    category,
    measure_type,
    is_default,
    is_active,
    hide_type,
    display_order
) VALUES (
    '660e8400-e29b-41d4-a716-446655440003',
    '550e8400-e29b-41d4-a716-446655440000',  -- User's ID
    NULL,  -- No parent (main deed)
    'Charity',
    'Track charitable donations and acts',
    'hasanaat',
    'count_based',
    false,
    true,
    'none',
    0
);
```

## Usage Notes

1. **Default Deeds**: Created by system, `user_id = SYSTEM_USER_ID`, `is_default = true`
2. **Custom Deeds**: Created by users, `user_id` is set, `is_default = false`
3. **Child Deeds**: Use `parent_deed_id` to create hierarchical structure (unlimited nesting)
4. **Hide Type**: Update dynamically based on conditions (e.g., date-based for Ramadan Fasts)
5. **Soft Delete**: Use `is_active = false` instead of deleting records
6. **Measure Type**: Must match between deed and entries (enforced at database level)
7. **Child Inheritance**: Child deeds automatically inherit `measure_type` from parent (enforced via trigger)

## Business Rules

1. **Default Deeds**: Cannot be deleted by users, only deactivated via `user_default_deeds.is_active`
2. **Custom Deeds**: Can be deleted by the owner (soft delete via `is_active = false`)
3. **Child Deed Inheritance**: Child deeds inherit `measure_type` from parent deed (enforced via trigger)
4. **Entry Creation**: Entries are created directly for the deed being tracked (parent or child)
5. **Self-Reference**: A deed cannot be its own parent (enforced at application level)


