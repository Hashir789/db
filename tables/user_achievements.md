# user_achievements Table

## Overview
The `user_achievements` table tracks when users earn achievements. It records which achievement was earned, by which user, and on which date. This table is populated automatically when achievement conditions are met.

## Purpose
- Track user achievement earnings
- Record achievement dates
- Support achievement history and statistics
- Enable achievement display and notifications

## Schema

```sql
CREATE TABLE user_achievements (
    user_achievement_id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    achievement_id UUID NOT NULL REFERENCES achievements(achievement_id) ON DELETE CASCADE,
    achieved_date DATE NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_user_achievements_user_date ON user_achievements(user_id, achieved_date DESC);
CREATE INDEX idx_user_achievements_achievement ON user_achievements(achievement_id, achieved_date DESC);
```

## Fields

### `user_achievement_id` (UUID, Primary Key)
- **Type**: UUID (v4)
- **Purpose**: Unique identifier for each user achievement record
- **Characteristics**: Globally unique
- **Example**: `ff0e8400-e29b-41d4-a716-446655440001`

### `user_id` (UUID, Foreign Key, Not Null)
- **Type**: UUID
- **Purpose**: The user who earned the achievement
- **Foreign Key**: `users.user_id`
- **Constraints**: NOT NULL
- **Cascade**: ON DELETE CASCADE (if user is deleted, user achievements are deleted)
- **Indexed**: Yes (for user-based queries)
- **Usage**: Links achievement to the user who earned it

### `achievement_id` (UUID, Foreign Key, Not Null)
- **Type**: UUID
- **Purpose**: References the achievement that was earned
- **Foreign Key**: `achievements.achievement_id`
- **Constraints**: NOT NULL
- **Cascade**: ON DELETE CASCADE (if achievement is deleted, user achievements are deleted)
- **Indexed**: Yes (for achievement-based queries)
- **Usage**: Links to the achievement definition

### `achieved_date` (DATE, Not Null, Indexed)
- **Type**: DATE
- **Purpose**: The date on which the achievement was earned
- **Constraints**: Required (NOT NULL)
- **Indexed**: Yes (for date-based queries)
- **Usage**: 
  - Records when achievement was earned
  - Part of unique constraint (one achievement per user per achievement per day)
  - Enables date-range queries and statistics
- **Example**: `'2024-01-15'`

### `created_at` (TIMESTAMP)
- **Type**: TIMESTAMP
- **Purpose**: Records when the user achievement record was created
- **Default**: CURRENT_TIMESTAMP
- **Usage**: Track creation time (usually same as achieved_date, but can differ if evaluated later)

## Indexes

```sql
CREATE INDEX idx_user_achievements_user_date ON user_achievements(user_id, achieved_date DESC);
CREATE INDEX idx_user_achievements_achievement ON user_achievements(achievement_id, achieved_date DESC);
```

## Relationships

The `user_achievements` table is referenced by:

1. **users** (user who earned achievement)
   - `user_achievements.user_id` → `users.user_id`
   - One user can earn many achievements
   - CASCADE DELETE: If user is deleted, user achievements are deleted

2. **achievements** (achievement definition)
   - `user_achievements.achievement_id` → `achievements.achievement_id`
   - One achievement can be earned by many users
   - CASCADE DELETE: If achievement is deleted, user achievements are deleted

## Constraints

- **Primary Key**: `user_achievement_id` (unique, not null)
- **Foreign Keys**: 
  - `user_id` → `users.user_id` (NOT NULL, CASCADE on delete)
  - `achievement_id` → `achievements.achievement_id` (NOT NULL, CASCADE on delete)
- **Unique Constraint**: `(user_id, achievement_id, achieved_date)` - one achievement per user per achievement per day

## Important Rules

### Rule 1: One Per Day
- One achievement can be earned per user per achievement per day
- Enforced by unique constraint on `(user_id, achievement_id, achieved_date)`
- If condition is met multiple times in a day, only one record is created

### Rule 2: Automatic Creation
- Records are created automatically when achievement conditions are met
- Evaluation happens after entry creation/update or scheduled daily check
- Do not manually create records (use achievement evaluation logic)

### Rule 3: Date Matching
- `achieved_date` should match the date of entries that triggered the achievement
- Example: If achievement is for "All prayers in mosque on 2024-01-15", achieved_date = '2024-01-15'

## Example Data

### User Earns "All Prayers in Mosque" Achievement
```sql
INSERT INTO user_achievements (
    user_achievement_id,
    user_id,
    achievement_id,
    achieved_date
) VALUES (
    'ff0e8400-e29b-41d4-a716-446655440001',
    '550e8400-e29b-41d4-a716-446655440000',  -- User ID
    'ee0e8400-e29b-41d4-a716-446655440001',  -- "All Prayers in Mosque" achievement_id
    '2024-01-15'  -- Date when all prayers were in mosque
);
```

### User Earns "All Prayers Except Fajr in Mosque" Achievement
```sql
INSERT INTO user_achievements (
    user_achievement_id,
    user_id,
    achievement_id,
    achieved_date
) VALUES (
    'ff0e8400-e29b-41d4-a716-446655440002',
    '550e8400-e29b-41d4-a716-446655440000',  -- User ID
    'ee0e8400-e29b-41d4-a716-446655440002',  -- "All Prayers Except Fajr in Mosque" achievement_id
    '2024-01-16'  -- Date when condition was met
);
```

### Multiple Users Earn Same Achievement
```sql
-- User A earns achievement
INSERT INTO user_achievements (
    user_achievement_id,
    user_id,
    achievement_id,
    achieved_date
) VALUES (
    'ff0e8400-e29b-41d4-a716-446655440003',
    '550e8400-e29b-41d4-a716-446655440000',  -- User A
    'ee0e8400-e29b-41d4-a716-446655440001',  -- Achievement
    '2024-01-15'
);

-- User B earns same achievement
INSERT INTO user_achievements (
    user_achievement_id,
    user_id,
    achievement_id,
    achieved_date
) VALUES (
    'ff0e8400-e29b-41d4-a716-446655440004',
    '550e8400-e29b-41d4-a716-446655440999',  -- User B
    'ee0e8400-e29b-41d4-a716-446655440001',  -- Same achievement
    '2024-01-15'
);
```

## Usage Notes

1. **Automatic Creation**: Records are created by achievement evaluation logic, not manually
2. **Unique Constraint**: Prevents duplicate achievements for same user/achievement/date
3. **Date Matching**: achieved_date should match the date of entries that triggered achievement
4. **Query Performance**: Use indexes for user-based and achievement-based queries
5. **Statistics**: Use this table for achievement statistics and leaderboards

## Business Rules

1. **One Per Day**: One achievement per user per achievement per day (enforced by unique constraint)
2. **Automatic**: Created automatically when conditions are met
3. **Date Matching**: achieved_date matches entry dates that triggered achievement
4. **Cascade Delete**: Deleting user or achievement deletes related user achievements

## Query Examples

### Get All Achievements for User
```sql
SELECT 
    ua.achieved_date,
    a.name,
    a.description
FROM user_achievements ua
JOIN achievements a ON ua.achievement_id = a.achievement_id
WHERE ua.user_id = '550e8400-e29b-41d4-a716-446655440000'
ORDER BY ua.achieved_date DESC;
```

### Get Achievement Statistics
```sql
SELECT 
    a.name,
    COUNT(DISTINCT ua.user_id) as users_earned,
    COUNT(*) as total_earnings
FROM achievements a
LEFT JOIN user_achievements ua ON a.achievement_id = ua.achievement_id
WHERE a.is_active = true
GROUP BY a.achievement_id, a.name
ORDER BY users_earned DESC;
```

### Get Recent Achievements
```sql
SELECT 
    u.username,
    a.name,
    ua.achieved_date
FROM user_achievements ua
JOIN users u ON ua.user_id = u.user_id
JOIN achievements a ON ua.achievement_id = a.achievement_id
WHERE ua.achieved_date >= CURRENT_DATE - INTERVAL '7 days'
ORDER BY ua.achieved_date DESC, ua.created_at DESC;
```

