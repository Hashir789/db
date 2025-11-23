# user_demerits Table

## Overview
The `user_demerits` table tracks when users earn demerits. It records which demerit was earned, by which user, and on which date. This table is populated automatically when demerit conditions are met.

## Purpose
- Track user demerit earnings
- Record demerit dates
- Support demerit history and statistics
- Enable demerit display and notifications

## Schema

```sql
CREATE TABLE user_demerits (
    user_demerit_id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    demerit_id UUID NOT NULL REFERENCES demerits(demerit_id) ON DELETE CASCADE,
    demerit_date DATE NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_user_demerits_user_date ON user_demerits(user_id, demerit_date DESC);
CREATE INDEX idx_user_demerits_demerit ON user_demerits(demerit_id, demerit_date DESC);
```

## Fields

### `user_demerit_id` (UUID, Primary Key)
- **Type**: UUID (v4)
- **Purpose**: Unique identifier for each user demerit record
- **Characteristics**: Globally unique
- **Example**: `220e8400-e29b-41d4-a716-446655440001`

### `user_id` (UUID, Foreign Key, Not Null)
- **Type**: UUID
- **Purpose**: The user who earned the demerit
- **Foreign Key**: `users.user_id`
- **Constraints**: NOT NULL
- **Cascade**: ON DELETE CASCADE (if user is deleted, user demerits are deleted)
- **Indexed**: Yes (for user-based queries)
- **Usage**: Links demerit to the user who earned it

### `demerit_id` (UUID, Foreign Key, Not Null)
- **Type**: UUID
- **Purpose**: References the demerit that was earned
- **Foreign Key**: `demerits.demerit_id`
- **Constraints**: NOT NULL
- **Cascade**: ON DELETE CASCADE (if demerit is deleted, user demerits are deleted)
- **Indexed**: Yes (for demerit-based queries)
- **Usage**: Links to the demerit definition

### `demerit_date` (DATE, Not Null, Indexed)
- **Type**: DATE
- **Purpose**: The date on which the demerit was earned
- **Constraints**: Required (NOT NULL)
- **Indexed**: Yes (for date-based queries)
- **Usage**: 
  - Records when demerit was earned
  - Part of unique constraint (one demerit per user per demerit per day)
  - Enables date-range queries and statistics
- **Example**: `'2024-01-15'`

### `created_at` (TIMESTAMP)
- **Type**: TIMESTAMP
- **Purpose**: Records when the user demerit record was created
- **Default**: CURRENT_TIMESTAMP
- **Usage**: Track creation time (usually same as demerit_date, but can differ if evaluated later)

## Indexes

```sql
CREATE INDEX idx_user_demerits_user_date ON user_demerits(user_id, demerit_date DESC);
CREATE INDEX idx_user_demerits_demerit ON user_demerits(demerit_id, demerit_date DESC);
```

## Relationships

The `user_demerits` table is referenced by:

1. **users** (user who earned demerit)
   - `user_demerits.user_id` → `users.user_id`
   - One user can earn many demerits
   - CASCADE DELETE: If user is deleted, user demerits are deleted

2. **demerits** (demerit definition)
   - `user_demerits.demerit_id` → `demerits.demerit_id`
   - One demerit can be earned by many users
   - CASCADE DELETE: If demerit is deleted, user demerits are deleted

## Constraints

- **Primary Key**: `user_demerit_id` (unique, not null)
- **Foreign Keys**: 
  - `user_id` → `users.user_id` (NOT NULL, CASCADE on delete)
  - `demerit_id` → `demerits.demerit_id` (NOT NULL, CASCADE on delete)
- **Unique Constraint**: `(user_id, demerit_id, demerit_date)` - one demerit per user per demerit per day

## Important Rules

### Rule 1: One Per Day
- One demerit can be earned per user per demerit per day
- Enforced by unique constraint on `(user_id, demerit_id, demerit_date)`
- If condition is met multiple times in a day, only one record is created

### Rule 2: Automatic Creation
- Records are created automatically when demerit conditions are met
- Evaluation happens after entry creation/update or scheduled daily check
- Do not manually create records (use demerit evaluation logic)

### Rule 3: Date Matching
- `demerit_date` should match the date of entries that triggered the demerit
- Example: If demerit is for "All prayers late/not prayed on 2024-01-15", demerit_date = '2024-01-15'

## Example Data

### User Earns "All Prayers Late/Not Prayed" Demerit
```sql
INSERT INTO user_demerits (
    user_demerit_id,
    user_id,
    demerit_id,
    demerit_date
) VALUES (
    '220e8400-e29b-41d4-a716-446655440001',
    '550e8400-e29b-41d4-a716-446655440000',  -- User ID
    '110e8400-e29b-41d4-a716-446655440001',  -- "All Prayers Late/Not Prayed" demerit_id
    '2024-01-15'  -- Date when all prayers were late/not prayed
);
```

### User Earns "All Prayers Missed" Demerit
```sql
INSERT INTO user_demerits (
    user_demerit_id,
    user_id,
    demerit_id,
    demerit_date
) VALUES (
    '220e8400-e29b-41d4-a716-446655440002',
    '550e8400-e29b-41d4-a716-446655440000',  -- User ID
    '110e8400-e29b-41d4-a716-446655440002',  -- "All Prayers Missed" demerit_id
    '2024-01-16'  -- Date when all prayers were missed
);
```

### Multiple Users Earn Same Demerit
```sql
-- User A earns demerit
INSERT INTO user_demerits (
    user_demerit_id,
    user_id,
    demerit_id,
    demerit_date
) VALUES (
    '220e8400-e29b-41d4-a716-446655440003',
    '550e8400-e29b-41d4-a716-446655440000',  -- User A
    '110e8400-e29b-41d4-a716-446655440001',  -- Demerit
    '2024-01-15'
);

-- User B earns same demerit
INSERT INTO user_demerits (
    user_demerit_id,
    user_id,
    demerit_id,
    demerit_date
) VALUES (
    '220e8400-e29b-41d4-a716-446655440004',
    '550e8400-e29b-41d4-a716-446655440999',  -- User B
    '110e8400-e29b-41d4-a716-446655440001',  -- Same demerit
    '2024-01-15'
);
```

## Usage Notes

1. **Automatic Creation**: Records are created by demerit evaluation logic, not manually
2. **Unique Constraint**: Prevents duplicate demerits for same user/demerit/date
3. **Date Matching**: demerit_date should match the date of entries that triggered demerit
4. **Query Performance**: Use indexes for user-based and demerit-based queries
5. **Statistics**: Use this table for demerit statistics and improvement tracking

## Business Rules

1. **One Per Day**: One demerit per user per demerit per day (enforced by unique constraint)
2. **Automatic**: Created automatically when conditions are met
3. **Date Matching**: demerit_date matches entry dates that triggered demerit
4. **Cascade Delete**: Deleting user or demerit deletes related user demerits

## Query Examples

### Get All Demerits for User
```sql
SELECT 
    ud.demerit_date,
    d.name,
    d.description
FROM user_demerits ud
JOIN demerits d ON ud.demerit_id = d.demerit_id
WHERE ud.user_id = '550e8400-e29b-41d4-a716-446655440000'
ORDER BY ud.demerit_date DESC;
```

### Get Demerit Statistics
```sql
SELECT 
    d.name,
    COUNT(DISTINCT ud.user_id) as users_with_demerit,
    COUNT(*) as total_demerits
FROM demerits d
LEFT JOIN user_demerits ud ON d.demerit_id = ud.demerit_id
WHERE d.is_active = true
GROUP BY d.demerit_id, d.name
ORDER BY users_with_demerit DESC;
```

### Get Recent Demerits
```sql
SELECT 
    u.username,
    d.name,
    ud.demerit_date
FROM user_demerits ud
JOIN users u ON ud.user_id = u.user_id
JOIN demerits d ON ud.demerit_id = d.demerit_id
WHERE ud.demerit_date >= CURRENT_DATE - INTERVAL '7 days'
ORDER BY ud.demerit_date DESC, ud.created_at DESC;
```

### Get User's Demerit Trend
```sql
SELECT 
    DATE_TRUNC('month', demerit_date) as month,
    COUNT(*) as demerit_count
FROM user_demerits
WHERE user_id = '550e8400-e29b-41d4-a716-446655440000'
GROUP BY DATE_TRUNC('month', demerit_date)
ORDER BY month DESC;
```


