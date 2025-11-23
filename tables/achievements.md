# achievements Table

## Overview
The `achievements` table defines achievement conditions and rules. Achievements can be system-wide (available to all users) or custom (user-specific). They use flexible JSONB configuration to define conditions based on deed/sub-deed patterns (e.g., "All prayers in mosque", "All prayers except Fajr in mosque").

## Purpose
- Define achievement conditions and rules
- Support system-wide and custom achievements
- Store flexible condition configurations in JSONB
- Enable conditional achievement tracking
- Track achievement definitions (not user achievements)

## Schema

```sql
CREATE TABLE achievements (
    achievement_id UUID PRIMARY KEY,
    user_id UUID REFERENCES users(user_id) ON DELETE CASCADE,
    name VARCHAR NOT NULL,
    description TEXT,
    condition_type ENUM('all_sub_deeds', 'specific_sub_deeds', 'custom') NOT NULL,
    condition_config JSONB NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP
);

CREATE INDEX idx_achievements_user ON achievements(user_id, is_active) WHERE user_id IS NOT NULL;
CREATE INDEX idx_achievements_system ON achievements(is_active) WHERE user_id IS NULL;
```

## Fields

### `achievement_id` (UUID, Primary Key)
- **Type**: UUID (v4)
- **Purpose**: Unique identifier for each achievement definition
- **Characteristics**: Globally unique
- **Example**: `ee0e8400-e29b-41d4-a716-446655440001`

### `user_id` (UUID, Foreign Key, Nullable)
- **Type**: UUID
- **Purpose**: Owner of custom achievement (NULL for system-wide)
- **Foreign Key**: `users.user_id`
- **Nullable**: Yes
- **Logic**:
  - **NULL** = System-wide achievement (available to all users)
  - **Set** = Custom achievement created by that specific user
- **Cascade**: ON DELETE CASCADE (if user is deleted, their custom achievements are deleted)
- **Usage**: Distinguishes system achievements from user-created ones

### `name` (VARCHAR, Not Null)
- **Type**: VARCHAR
- **Purpose**: Name of the achievement
- **Constraints**: Required (NOT NULL)
- **Usage**: Displayed in UI, used for identification
- **Examples**: 
  - `'All Prayers in Mosque'`
  - `'All Prayers Except Fajr in Mosque'`
  - `'Perfect Prayer Day'`
  - `'Consistent Charity'`

### `description` (TEXT, Nullable)
- **Type**: TEXT
- **Purpose**: Optional description of the achievement
- **Nullable**: Yes
- **Usage**: 
  - Explain what the achievement means
  - Provide context or requirements
- **Example**: `'Achieve this by praying all five daily prayers in the mosque on the same day.'`

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
  - All sub-deeds: `{"deed_id": "...", "scale_value": "prayed_in_mosque"}`
  - Specific sub-deeds: `{"deed_id": "...", "sub_deed_ids": ["...", "..."], "scale_value": "prayed_in_mosque"}`
  - Custom: `{"custom_logic": "...", "parameters": {...}}`

### `is_active` (BOOLEAN, Default: true)
- **Type**: BOOLEAN
- **Purpose**: Soft delete flag
- **Values**:
  - `true`: Active achievement (evaluated and available)
  - `false`: Deactivated achievement (not evaluated)
- **Default**: `true`
- **Usage**: 
  - Soft delete (preserves data)
  - Temporarily disable achievements
  - Filter active achievements in queries

### `created_at` (TIMESTAMP)
- **Type**: TIMESTAMP
- **Purpose**: Records when the achievement was created
- **Default**: CURRENT_TIMESTAMP
- **Usage**: Track creation time

### `updated_at` (TIMESTAMP)
- **Type**: TIMESTAMP
- **Purpose**: Tracks when achievement details were last modified
- **Nullable**: Yes (null if never updated)
- **Usage**: Track modifications

## Indexes

```sql
CREATE INDEX idx_achievements_user ON achievements(user_id, is_active) WHERE user_id IS NOT NULL;
CREATE INDEX idx_achievements_system ON achievements(is_active) WHERE user_id IS NULL;
```

## Relationships

The `achievements` table is referenced by:

1. **users** (custom achievement owner)
   - `achievements.user_id` → `users.user_id` (nullable)
   - One user can create many custom achievements
   - CASCADE DELETE: If user is deleted, their custom achievements are deleted

2. **user_achievements** (when users earn achievements)
   - `user_achievements.achievement_id` → `achievements.achievement_id`
   - One achievement can be earned by many users
   - CASCADE DELETE: If achievement is deleted, user achievements are deleted

## Constraints

- **Primary Key**: `achievement_id` (unique, not null)
- **Foreign Key**: `user_id` → `users.user_id` (nullable, CASCADE on delete)

## Condition Config Examples

### All Sub-Deeds Condition
```json
{
  "deed_id": "660e8400-e29b-41d4-a716-446655440001",
  "scale_value": "prayed_in_mosque"
}
```
**Meaning**: All sub-deeds of the Namaz deed must have `scale_value = 'prayed_in_mosque'`

### Specific Sub-Deeds Condition
```json
{
  "deed_id": "660e8400-e29b-41d4-a716-446655440001",
  "sub_deed_ids": [
    "770e8400-e29b-41d4-a716-446655440002",  // Zuhr
    "770e8400-e29b-41d4-a716-446655440003",  // Asr
    "770e8400-e29b-41d4-a716-446655440004",  // Maghrib
    "770e8400-e29b-41d4-a716-446655440005"   // Isha
  ],
  "scale_value": "prayed_in_mosque"
}
```
**Meaning**: Zuhr, Asr, Maghrib, and Isha must have `scale_value = 'prayed_in_mosque'` (Fajr excluded)

### Multiple Scale Values Condition
```json
{
  "deed_id": "660e8400-e29b-41d4-a716-446655440001",
  "scale_values": ["prayed_in_mosque", "prayed_at_home"]
}
```
**Meaning**: All sub-deeds must have scale_value in the specified list

### Custom Condition
```json
{
  "custom_logic": "complex_evaluation",
  "parameters": {
    "deed_ids": ["...", "..."],
    "min_count": 5,
    "date_range": "weekly"
  }
}
```
**Meaning**: Custom logic evaluated at application level

## Example Data

### System-Wide Achievement: All Prayers in Mosque
```sql
INSERT INTO achievements (
    achievement_id,
    user_id,
    name,
    description,
    condition_type,
    condition_config,
    is_active
) VALUES (
    'ee0e8400-e29b-41d4-a716-446655440001',
    NULL,  -- NULL for system-wide
    'All Prayers in Mosque',
    'Pray all five daily prayers in the mosque on the same day',
    'all_sub_deeds',
    '{
        "deed_id": "660e8400-e29b-41d4-a716-446655440001",
        "scale_value": "prayed_in_mosque"
    }'::jsonb,
    true
);
```

### System-Wide Achievement: All Prayers Except Fajr in Mosque
```sql
INSERT INTO achievements (
    achievement_id,
    user_id,
    name,
    description,
    condition_type,
    condition_config,
    is_active
) VALUES (
    'ee0e8400-e29b-41d4-a716-446655440002',
    NULL,  -- NULL for system-wide
    'All Prayers Except Fajr in Mosque',
    'Pray Zuhr, Asr, Maghrib, and Isha in the mosque on the same day',
    'specific_sub_deeds',
    '{
        "deed_id": "660e8400-e29b-41d4-a716-446655440001",
        "sub_deed_ids": [
            "770e8400-e29b-41d4-a716-446655440002",
            "770e8400-e29b-41d4-a716-446655440003",
            "770e8400-e29b-41d4-a716-446655440004",
            "770e8400-e29b-41d4-a716-446655440005"
        ],
        "scale_value": "prayed_in_mosque"
    }'::jsonb,
    true
);
```

### Custom User Achievement
```sql
INSERT INTO achievements (
    achievement_id,
    user_id,
    name,
    description,
    condition_type,
    condition_config,
    is_active
) VALUES (
    'ee0e8400-e29b-41d4-a716-446655440003',
    '550e8400-e29b-41d4-a716-446655440000',  -- User's ID
    'My Personal Goal',
    'Pray at least 3 prayers in mosque this week',
    'custom',
    '{
        "custom_logic": "weekly_mosque_prayers",
        "parameters": {
            "deed_id": "660e8400-e29b-41d4-a716-446655440001",
            "min_count": 3,
            "scale_value": "prayed_in_mosque"
        }
    }'::jsonb,
    true
);
```

## Usage Notes

1. **Evaluation**: Conditions are evaluated at application level after entry creation/update
2. **System vs. Custom**: System achievements (user_id = NULL) are available to all users
3. **JSONB Queries**: Use PostgreSQL JSONB operators for querying condition_config
4. **Active Only**: Only evaluate active achievements (is_active = true)
5. **Custom Logic**: 'custom' condition_type requires application-level evaluation logic

## Business Rules

1. **System Achievements**: user_id = NULL, available to all users
2. **Custom Achievements**: user_id is set, only visible to that user
3. **Evaluation Trigger**: Evaluate after entry creation/update or scheduled daily check
4. **User Achievement Creation**: When condition is met, create record in `user_achievements` table
5. **Cascade Delete**: Deleting a user deletes their custom achievements

## Evaluation Logic

### All Sub-Deeds Evaluation
1. Get all sub-deeds for the deed_id
2. Check if all sub-deeds have entries for the date
3. Verify all entries match the condition (e.g., scale_value)
4. If all match, achievement is earned

### Specific Sub-Deeds Evaluation
1. Get specified sub_deed_ids
2. Check if all specified sub-deeds have entries for the date
3. Verify all entries match the condition
4. If all match, achievement is earned

### Custom Evaluation
1. Read custom_logic from condition_config
2. Execute custom application logic
3. Return true/false based on custom rules


