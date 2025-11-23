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
    user_id UUID REFERENCES users(user_id) ON DELETE CASCADE,
    name VARCHAR NOT NULL,
    description TEXT,
    category ENUM('hasanaat', 'saiyyiaat') NOT NULL,
    measure_type ENUM('scale_based', 'count_based') NOT NULL,
    is_default BOOLEAN NOT NULL DEFAULT false,
    is_active BOOLEAN NOT NULL DEFAULT true,
    hide_type ENUM('none', 'hide_from_all', 'hide_from_graphs') NOT NULL DEFAULT 'none',
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP
);

CREATE INDEX idx_deeds_user_category ON deeds(user_id, category, is_active);
CREATE INDEX idx_deeds_default ON deeds(is_default) WHERE is_default = true;
CREATE INDEX idx_deeds_user_active ON deeds(user_id, is_active) WHERE is_active = true;
CREATE INDEX idx_deeds_hide_type ON deeds(hide_type, is_active);
```

## Fields

### `deed_id` (UUID, Primary Key)
- **Type**: UUID (v4)
- **Purpose**: Unique identifier for each deed
- **Characteristics**: 
  - Globally unique
  - Used as foreign key in related tables
- **Example**: `660e8400-e29b-41d4-a716-446655440001`

### `user_id` (UUID, Foreign Key, Nullable)
- **Type**: UUID
- **Purpose**: Owner of the deed
- **Foreign Key**: `users.user_id`
- **Nullable**: Yes
- **Logic**:
  - **NULL** = System default deed (available to all users)
  - **Set** = Custom deed created by that specific user
- **Cascade**: ON DELETE CASCADE (if user is deleted, their custom deeds are deleted)
- **Example**: 
  - `NULL` for default deed "Namaz"
  - `550e8400-e29b-41d4-a716-446655440000` for custom deed

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

1. **sub_deeds** (sub-deeds under this deed)
   - `sub_deeds.deed_id` → `deeds.deed_id`
   - One deed can have many sub-deeds
   - CASCADE DELETE: If deed is deleted, sub-deeds are deleted

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
- **Foreign Key**: `user_id` → `users.user_id` (nullable, CASCADE on delete)
- **Check Constraint**: If `is_default = true`, then `user_id` should be NULL (enforced at application level)

## Entry Rules

**Important**: The way entries are created depends on whether the deed has sub-deeds:

1. **If deed has sub-deeds** (e.g., Namaz with Fajr, Zuhr, etc.):
   - Entries can ONLY be created for sub-deeds (via `sub_entry_values` table)
   - Cannot create entry directly for the parent deed
   - Example: For Namaz, you can only log Fajr, Zuhr, Asr, Maghrib, Isha - not "Namaz" itself

2. **If deed has no sub-deeds** (e.g., Lie):
   - Entries can be created directly for the deed (in `entries` table)
   - No sub-entry values needed
   - Example: For Lie, you log directly to "Lie" deed

## Example Data

### Default Deed (Namaz)
```sql
INSERT INTO deeds (
    deed_id,
    user_id,
    name,
    description,
    category,
    measure_type,
    is_default,
    is_active,
    hide_type
) VALUES (
    '660e8400-e29b-41d4-a716-446655440001',
    NULL,  -- NULL for default deeds
    'Namaz',
    'Daily prayers - track each prayer separately',
    'hasanaat',
    'scale_based',
    true,
    true,
    'none'
);
```

### Default Deed (Lie)
```sql
INSERT INTO deeds (
    deed_id,
    user_id,
    name,
    description,
    category,
    measure_type,
    is_default,
    is_active,
    hide_type
) VALUES (
    '660e8400-e29b-41d4-a716-446655440002',
    NULL,
    'Lie',
    'Track instances of lying',
    'saiyyiaat',
    'scale_based',
    true,
    true,
    'none'
);
```

### Custom Deed (Charity)
```sql
INSERT INTO deeds (
    deed_id,
    user_id,
    name,
    description,
    category,
    measure_type,
    is_default,
    is_active,
    hide_type
) VALUES (
    '660e8400-e29b-41d4-a716-446655440003',
    '550e8400-e29b-41d4-a716-446655440000',  -- User's ID
    'Charity',
    'Track charitable donations and acts',
    'hasanaat',
    'count_based',
    false,
    true,
    'none'
);
```

## Usage Notes

1. **Default Deeds**: Created by system, `user_id = NULL`, `is_default = true`
2. **Custom Deeds**: Created by users, `user_id` is set, `is_default = false`
3. **Sub-deeds**: Check if deed has sub-deeds before allowing entry creation
4. **Hide Type**: Update dynamically based on conditions (e.g., date-based for Ramadan Fasts)
5. **Soft Delete**: Use `is_active = false` instead of deleting records
6. **Measure Type**: Must match between deed and entries (enforced at application level)

## Business Rules

1. **Default Deeds**: Cannot be deleted by users, only deactivated via `user_default_deeds.is_active`
2. **Custom Deeds**: Can be deleted by the owner (soft delete via `is_active = false`)
3. **Sub-deed Inheritance**: Sub-deeds inherit `measure_type` from parent deed
4. **Entry Constraint**: If deed has sub-deeds, entries must be for sub-deeds only


