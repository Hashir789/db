# demerits Table

## Overview
The `demerits` table defines demerit conditions and rules. Demerits can be system-wide (available to all users) or custom (user-specific). They use flexible JSONB configuration to define conditions based on deed/sub-deed patterns (e.g., "All prayers late/not prayed", "All prayers missed").

## Purpose
- Define demerit conditions and rules
- Support system-wide and custom demerits
- Store flexible condition configurations in JSONB
- Enable conditional demerit tracking
- Track demerit definitions (not user demerits)

## Schema

```sql
CREATE TABLE demerits (
    demerit_id UUID PRIMARY KEY,
    user_id UUID REFERENCES users(user_id) ON DELETE CASCADE,
    name VARCHAR NOT NULL,
    description TEXT,
    condition_type ENUM('all_sub_deeds', 'specific_sub_deeds', 'custom') NOT NULL,
    condition_config JSONB NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP
);

CREATE INDEX idx_demerits_user ON demerits(user_id, is_active) WHERE user_id IS NOT NULL;
CREATE INDEX idx_demerits_system ON demerits(is_active) WHERE user_id IS NULL;
```

## Fields

### `demerit_id` (UUID, Primary Key)
- **Type**: UUID (v4)
- **Purpose**: Unique identifier for each demerit definition
- **Characteristics**: Globally unique
- **Example**: `110e8400-e29b-41d4-a716-446655440001`

### `user_id` (UUID, Foreign Key, Nullable)
- **Type**: UUID
- **Purpose**: Owner of custom demerit (NULL for system-wide)
- **Foreign Key**: `users.user_id`
- **Nullable**: Yes
- **Logic**:
  - **NULL** = System-wide demerit (available to all users)
  - **Set** = Custom demerit created by that specific user
- **Cascade**: ON DELETE CASCADE (if user is deleted, their custom demerits are deleted)
- **Usage**: Distinguishes system demerits from user-created ones

### `name` (VARCHAR, Not Null)
- **Type**: VARCHAR
- **Purpose**: Name of the demerit
- **Constraints**: Required (NOT NULL)
- **Usage**: Displayed in UI, used for identification
- **Examples**: 
  - `'All Prayers Late/Not Prayed'`
  - `'All Prayers Missed'`
  - `'Multiple Lies'`
  - `'Consistent Backbiting'`

### `description` (TEXT, Nullable)
- **Type**: TEXT
- **Purpose**: Optional description of the demerit
- **Nullable**: Yes
- **Usage**: 
  - Explain what the demerit means
  - Provide context or consequences
- **Example**: `'This demerit is earned when all prayers are either late or not prayed on the same day.'`

### `condition_type` (ENUM, Not Null)
- **Type**: ENUM('all_sub_deeds', 'specific_sub_deeds', 'custom')
- **Purpose**: Type of condition evaluation
- **Values**:
  - `'all_sub_deeds'`: Check if all sub-deeds of a deed meet the condition
  - `'specific_sub_deeds'`: Check if specific sub-deeds meet the condition
  - `'custom'`: Custom logic (evaluated at application level)
- **Usage**: Determines how `condition_config` is interpreted

### `condition_config` (JSONB, Not Null)
- **Type**: JSONB
- **Purpose**: Stores flexible condition rules
- **Constraints**: Required (NOT NULL)
- **Format**: JSON object with condition parameters
- **Usage**: 
  - Defines what conditions must be met
  - Evaluated by application logic
  - Flexible structure for different condition types
- **Examples**:
  - All sub-deeds: `{"deed_id": "...", "scale_values": ["late_prayed", "not_prayed"]}`
  - Specific sub-deeds: `{"deed_id": "...", "sub_deed_ids": ["...", "..."], "scale_values": ["not_prayed"]}`
  - Custom: `{"custom_logic": "...", "parameters": {...}}`

### `is_active` (BOOLEAN, Default: true)
- **Type**: BOOLEAN
- **Purpose**: Soft delete flag
- **Values**:
  - `true`: Active demerit (evaluated and available)
  - `false`: Deactivated demerit (not evaluated)
- **Default**: `true`
- **Usage**: 
  - Soft delete (preserves data)
  - Temporarily disable demerits
  - Filter active demerits in queries

### `created_at` (TIMESTAMP)
- **Type**: TIMESTAMP
- **Purpose**: Records when the demerit was created
- **Default**: CURRENT_TIMESTAMP
- **Usage**: Track creation time

### `updated_at` (TIMESTAMP)
- **Type**: TIMESTAMP
- **Purpose**: Tracks when demerit details were last modified
- **Nullable**: Yes (null if never updated)
- **Usage**: Track modifications

## Indexes

```sql
CREATE INDEX idx_demerits_user ON demerits(user_id, is_active) WHERE user_id IS NOT NULL;
CREATE INDEX idx_demerits_system ON demerits(is_active) WHERE user_id IS NULL;
```

## Relationships

The `demerits` table is referenced by:

1. **users** (custom demerit owner)
   - `demerits.user_id` → `users.user_id` (nullable)
   - One user can create many custom demerits
   - CASCADE DELETE: If user is deleted, their custom demerits are deleted

2. **user_demerits** (when users earn demerits)
   - `user_demerits.demerit_id` → `demerits.demerit_id`
   - One demerit can be earned by many users
   - CASCADE DELETE: If demerit is deleted, user demerits are deleted

## Constraints

- **Primary Key**: `demerit_id` (unique, not null)
- **Foreign Key**: `user_id` → `users.user_id` (nullable, CASCADE on delete)

## Condition Config Examples

### All Sub-Deeds Condition (Multiple Scale Values)
```json
{
  "deed_id": "660e8400-e29b-41d4-a716-446655440001",
  "scale_values": ["late_prayed", "not_prayed"]
}
```
**Meaning**: All sub-deeds of the Namaz deed must have `scale_value` in `['late_prayed', 'not_prayed']`

### All Sub-Deeds Condition (Single Scale Value)
```json
{
  "deed_id": "660e8400-e29b-41d4-a716-446655440001",
  "scale_value": "not_prayed"
}
```
**Meaning**: All sub-deeds must have `scale_value = 'not_prayed'`

### Specific Sub-Deeds Condition
```json
{
  "deed_id": "660e8400-e29b-41d4-a716-446655440001",
  "sub_deed_ids": [
    "770e8400-e29b-41d4-a716-446655440001",  // Fajr
    "770e8400-e29b-41d4-a716-446655440002"   // Zuhr
  ],
  "scale_values": ["late_prayed", "not_prayed"]
}
```
**Meaning**: Fajr and Zuhr must have scale_value in the specified list

### Custom Condition
```json
{
  "custom_logic": "complex_evaluation",
  "parameters": {
    "deed_ids": ["...", "..."],
    "min_count": 3,
    "date_range": "daily"
  }
}
```
**Meaning**: Custom logic evaluated at application level

## Example Data

### System-Wide Demerit: All Prayers Late/Not Prayed
```sql
INSERT INTO demerits (
    demerit_id,
    user_id,
    name,
    description,
    condition_type,
    condition_config,
    is_active
) VALUES (
    '110e8400-e29b-41d4-a716-446655440001',
    NULL,  -- NULL for system-wide
    'All Prayers Late/Not Prayed',
    'All five daily prayers are either late or not prayed on the same day',
    'all_sub_deeds',
    '{
        "deed_id": "660e8400-e29b-41d4-a716-446655440001",
        "scale_values": ["late_prayed", "not_prayed"]
    }'::jsonb,
    true
);
```

### System-Wide Demerit: All Prayers Missed
```sql
INSERT INTO demerits (
    demerit_id,
    user_id,
    name,
    description,
    condition_type,
    condition_config,
    is_active
) VALUES (
    '110e8400-e29b-41d4-a716-446655440002',
    NULL,  -- NULL for system-wide
    'All Prayers Missed',
    'All five daily prayers are not prayed on the same day',
    'all_sub_deeds',
    '{
        "deed_id": "660e8400-e29b-41d4-a716-446655440001",
        "scale_value": "not_prayed"
    }'::jsonb,
    true
);
```

### Custom User Demerit
```sql
INSERT INTO demerits (
    demerit_id,
    user_id,
    name,
    description,
    condition_type,
    condition_config,
    is_active
) VALUES (
    '110e8400-e29b-41d4-a716-446655440003',
    '550e8400-e29b-41d4-a716-446655440000',  -- User's ID
    'My Personal Warning',
    'Miss more than 2 prayers in a day',
    'custom',
    '{
        "custom_logic": "daily_missed_prayers",
        "parameters": {
            "deed_id": "660e8400-e29b-41d4-a716-446655440001",
            "min_missed": 2,
            "scale_value": "not_prayed"
        }
    }'::jsonb,
    true
);
```

## Usage Notes

1. **Evaluation**: Conditions are evaluated at application level after entry creation/update
2. **System vs. Custom**: System demerits (user_id = NULL) are available to all users
3. **JSONB Queries**: Use PostgreSQL JSONB operators for querying condition_config
4. **Active Only**: Only evaluate active demerits (is_active = true)
5. **Custom Logic**: 'custom' condition_type requires application-level evaluation logic
6. **Multiple Scale Values**: Often use `scale_values` array for demerits (unlike achievements which often use single `scale_value`)

## Business Rules

1. **System Demerits**: user_id = NULL, available to all users
2. **Custom Demerits**: user_id is set, only visible to that user
3. **Evaluation Trigger**: Evaluate after entry creation/update or scheduled daily check
4. **User Demerit Creation**: When condition is met, create record in `user_demerits` table
5. **Cascade Delete**: Deleting a user deletes their custom demerits

## Evaluation Logic

### All Sub-Deeds Evaluation
1. Get all sub-deeds for the deed_id
2. Check if all sub-deeds have entries for the date
3. Verify all entries match the condition (e.g., scale_value in scale_values array)
4. If all match, demerit is earned

### Specific Sub-Deeds Evaluation
1. Get specified sub_deed_ids
2. Check if all specified sub-deeds have entries for the date
3. Verify all entries match the condition
4. If all match, demerit is earned

### Custom Evaluation
1. Read custom_logic from condition_config
2. Execute custom application logic
3. Return true/false based on custom rules


