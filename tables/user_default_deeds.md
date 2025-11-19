# user_default_deeds Table

## Overview
The `user_default_deeds` table is a junction table that tracks which default deeds users have opted-in to during onboarding or added later. It enables users to customize which default deeds (like Namaz and Lie) they want to track, supporting the optional default deeds feature.

## Purpose
- Track which default deeds each user has opted-in to
- Support optional default deeds during onboarding
- Enable users to add/remove default deeds at any time
- Support soft delete (is_active flag)
- Maintain assignment history

## Schema

```sql
CREATE TABLE user_default_deeds (
    user_default_deed_id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    default_deed_id UUID NOT NULL REFERENCES deeds(deed_id) ON DELETE CASCADE,
    is_active BOOLEAN NOT NULL DEFAULT true,
    assigned_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_user_default_deeds_user ON user_default_deeds(user_id, is_active);
CREATE INDEX idx_user_default_deeds_deed ON user_default_deeds(default_deed_id, is_active);
```

## Fields

### `user_default_deed_id` (UUID, Primary Key)
- **Type**: UUID (v4)
- **Purpose**: Unique identifier for each user-default deed association
- **Characteristics**: Globally unique
- **Example**: `330e8400-e29b-41d4-a716-446655440001`

### `user_id` (UUID, Foreign Key, Not Null)
- **Type**: UUID
- **Purpose**: The user who has opted-in to this default deed
- **Foreign Key**: `users.user_id`
- **Constraints**: NOT NULL
- **Cascade**: ON DELETE CASCADE (if user is deleted, user_default_deeds are deleted)
- **Indexed**: Yes (for user-based queries)
- **Usage**: Links to the user

### `default_deed_id` (UUID, Foreign Key, Not Null)
- **Type**: UUID
- **Purpose**: References the default deed
- **Foreign Key**: `deeds.deed_id`
- **Constraints**: NOT NULL
- **Cascade**: ON DELETE CASCADE (if deed is deleted, user_default_deeds are deleted)
- **Indexed**: Yes (for deed-based queries)
- **Usage**: Links to the default deed (should have `deeds.is_default = true`)
- **Note**: Should reference a deed with `is_default = true` and `user_id = NULL`

### `is_active` (BOOLEAN, Default: true)
- **Type**: BOOLEAN
- **Purpose**: Soft delete flag for the association
- **Values**:
  - `true`: Active association (deed is available to user)
  - `false`: Deactivated association (deed is hidden but not deleted)
- **Default**: `true`
- **Usage**: 
  - Soft delete (preserves history)
  - Remove default deed from user without deleting record
  - Filter active default deeds for user

### `assigned_at` (TIMESTAMP, Default: CURRENT_TIMESTAMP)
- **Type**: TIMESTAMP
- **Purpose**: Records when the default deed was assigned to the user
- **Default**: CURRENT_TIMESTAMP
- **Usage**: 
  - Track when user opted-in during onboarding
  - Track when user added default deed later
  - Maintain assignment history

## Indexes

```sql
CREATE INDEX idx_user_default_deeds_user ON user_default_deeds(user_id, is_active);
CREATE INDEX idx_user_default_deeds_deed ON user_default_deeds(default_deed_id, is_active);
```

## Relationships

The `user_default_deeds` table is referenced by:

1. **users** (user who has the default deed)
   - `user_default_deeds.user_id` → `users.user_id`
   - One user can have many default deeds
   - CASCADE DELETE: If user is deleted, user_default_deeds are deleted

2. **deeds** (the default deed)
   - `user_default_deeds.default_deed_id` → `deeds.deed_id`
   - One default deed can be assigned to many users
   - CASCADE DELETE: If deed is deleted, user_default_deeds are deleted

## Constraints

- **Primary Key**: `user_default_deed_id` (unique, not null)
- **Foreign Keys**: 
  - `user_id` → `users.user_id` (NOT NULL, CASCADE on delete)
  - `default_deed_id` → `deeds.deed_id` (NOT NULL, CASCADE on delete)
- **Unique Constraint**: `(user_id, default_deed_id)` - one record per user per default deed (enforced at application level to allow re-adding after removal)

## Important Rules

### Rule 1: Default Deeds Only
- Should only reference deeds with `is_default = true` and `user_id = NULL`
- Application should validate this before creating records

### Rule 2: Optional During Onboarding
- Users can choose to accept or skip default deeds during onboarding
- If user accepts: Create records with `is_active = true`
- If user skips: Do not create records (user can add later)

### Rule 3: Add/Remove Anytime
- Users can add default deeds at any time (create new record)
- Users can remove default deeds by setting `is_active = false`
- Users can re-add by setting `is_active = true` or creating new record

### Rule 4: Soft Delete
- Use `is_active = false` to remove default deed from user
- Preserves history and allows re-adding
- Filter by `is_active = true` when querying user's active default deeds

## Example Data

### User Opts-In to Default Deeds During Onboarding
```sql
-- User accepts Namaz
INSERT INTO user_default_deeds (
    user_default_deed_id,
    user_id,
    default_deed_id,
    is_active,
    assigned_at
) VALUES (
    '330e8400-e29b-41d4-a716-446655440001',
    '550e8400-e29b-41d4-a716-446655440000',  -- User ID
    '660e8400-e29b-41d4-a716-446655440001',  -- Namaz deed_id
    true,
    CURRENT_TIMESTAMP
);

-- User accepts Lie
INSERT INTO user_default_deeds (
    user_default_deed_id,
    user_id,
    default_deed_id,
    is_active,
    assigned_at
) VALUES (
    '330e8400-e29b-41d4-a716-446655440002',
    '550e8400-e29b-41d4-a716-446655440000',  -- User ID
    '660e8400-e29b-41d4-a716-446655440002',  -- Lie deed_id
    true,
    CURRENT_TIMESTAMP
);
```

### User Removes Default Deed
```sql
-- User removes Namaz (soft delete)
UPDATE user_default_deeds
SET 
    is_active = false
WHERE user_id = '550e8400-e29b-41d4-a716-446655440000'
  AND default_deed_id = '660e8400-e29b-41d4-a716-446655440001';
```

### User Re-Adds Default Deed
```sql
-- Option 1: Reactivate existing record
UPDATE user_default_deeds
SET 
    is_active = true,
    assigned_at = CURRENT_TIMESTAMP
WHERE user_id = '550e8400-e29b-41d4-a716-446655440000'
  AND default_deed_id = '660e8400-e29b-41d4-a716-446655440001';

-- Option 2: Create new record (if previous was deleted)
INSERT INTO user_default_deeds (
    user_default_deed_id,
    user_id,
    default_deed_id,
    is_active,
    assigned_at
) VALUES (
    '330e8400-e29b-41d4-a716-446655440003',
    '550e8400-e29b-41d4-a716-446655440000',
    '660e8400-e29b-41d4-a716-446655440001',
    true,
    CURRENT_TIMESTAMP
);
```

### User Adds Default Deed Later
```sql
-- User adds Namaz after initially skipping it
INSERT INTO user_default_deeds (
    user_default_deed_id,
    user_id,
    default_deed_id,
    is_active,
    assigned_at
) VALUES (
    '330e8400-e29b-41d4-a716-446655440004',
    '550e8400-e29b-41d4-a716-446655440000',
    '660e8400-e29b-41d4-a716-446655440001',  -- Namaz
    true,
    CURRENT_TIMESTAMP
);
```

## Usage Notes

1. **Onboarding**: Check if user opted-in during onboarding before creating records
2. **Active Filter**: Always filter by `is_active = true` when querying user's available default deeds
3. **Validation**: Ensure `default_deed_id` references a deed with `is_default = true`
4. **Soft Delete**: Use `is_active = false` instead of deleting records
5. **Re-adding**: Check if record exists before creating (update existing if found)

## Business Rules

1. **Optional Onboarding**: Users can skip default deeds during onboarding
2. **Add Anytime**: Users can add default deeds at any time
3. **Remove Anytime**: Users can remove default deeds (soft delete via `is_active = false`)
4. **Default Deed Validation**: Should only reference deeds with `is_default = true`
5. **Cascade Delete**: Deleting user or deed deletes related user_default_deeds

## Query Examples

### Get User's Active Default Deeds
```sql
SELECT 
    d.name,
    d.description,
    d.category,
    udd.assigned_at
FROM user_default_deeds udd
JOIN deeds d ON udd.default_deed_id = d.deed_id
WHERE udd.user_id = '550e8400-e29b-41d4-a716-446655440000'
  AND udd.is_active = true
  AND d.is_default = true;
```

### Check if User Has Default Deed
```sql
SELECT EXISTS (
    SELECT 1
    FROM user_default_deeds
    WHERE user_id = '550e8400-e29b-41d4-a716-446655440000'
      AND default_deed_id = '660e8400-e29b-41d4-a716-446655440001'
      AND is_active = true
);
```

### Get All Users with Default Deed
```sql
SELECT 
    u.username,
    u.email,
    udd.assigned_at
FROM user_default_deeds udd
JOIN users u ON udd.user_id = u.user_id
WHERE udd.default_deed_id = '660e8400-e29b-41d4-a716-446655440001'
  AND udd.is_active = true;
```

### Get User's Default Deed History
```sql
SELECT 
    d.name,
    udd.is_active,
    udd.assigned_at
FROM user_default_deeds udd
JOIN deeds d ON udd.default_deed_id = d.deed_id
WHERE udd.user_id = '550e8400-e29b-41d4-a716-446655440000'
ORDER BY udd.assigned_at DESC;
```

