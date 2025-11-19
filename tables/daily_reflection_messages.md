# daily_reflection_messages Table

## Overview
The `daily_reflection_messages` table stores optional daily reflection messages for users. Each user can add one Hasanaat (good deeds) message and one Saiyyiaat (bad deeds) message per day, providing a way to reflect on all deeds of that category for the entire day.

## Purpose
- Store daily reflection messages (one Hasanaat, one Saiyyiaat per day)
- Enable users to reflect on their day's activities
- Support optional messaging (not required)
- Maintain one record per user per day

## Schema

```sql
CREATE TABLE daily_reflection_messages (
    reflection_id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    reflection_date DATE NOT NULL,
    hasanaat_message TEXT,
    saiyyiaat_message TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP
);

CREATE INDEX idx_daily_reflection_user_date ON daily_reflection_messages(user_id, reflection_date DESC);
CREATE INDEX idx_daily_reflection_date ON daily_reflection_messages(reflection_date);
```

## Fields

### `reflection_id` (UUID, Primary Key)
- **Type**: UUID (v4)
- **Purpose**: Unique identifier for each reflection message record
- **Characteristics**: Globally unique
- **Example**: `dd0e8400-e29b-41d4-a716-446655440001`

### `user_id` (UUID, Foreign Key, Not Null)
- **Type**: UUID
- **Purpose**: The user who owns this reflection message
- **Foreign Key**: `users.user_id`
- **Constraints**: NOT NULL
- **Cascade**: ON DELETE CASCADE (if user is deleted, reflection messages are deleted)
- **Indexed**: Yes (for user-based queries)
- **Usage**: Links reflection message to the user

### `reflection_date` (DATE, Not Null, Indexed)
- **Type**: DATE
- **Purpose**: The date for which this reflection message is for
- **Constraints**: Required (NOT NULL)
- **Indexed**: Yes (for date-based queries)
- **Usage**: 
  - Used for daily reflection tracking
  - Part of unique constraint (one record per user per date)
  - Enables date-range queries
- **Example**: `'2024-01-15'`

### `hasanaat_message` (TEXT, Nullable)
- **Type**: TEXT
- **Purpose**: Optional reflection message for all Hasanaat (good deeds) of the day
- **Nullable**: Yes (optional)
- **Usage**: 
  - User's reflection on all good deeds performed that day
  - Can include thoughts, gratitude, lessons learned, etc.
  - Applies to all Hasanaat entries for that date
- **Example**: `'Today I focused on my prayers and felt more connected. I also helped a neighbor which made me feel good.'`

### `saiyyiaat_message` (TEXT, Nullable)
- **Type**: TEXT
- **Purpose**: Optional reflection message for all Saiyyiaat (bad deeds) of the day
- **Nullable**: Yes (optional)
- **Usage**: 
  - User's reflection on all bad deeds committed that day
  - Can include remorse, lessons learned, plans for improvement, etc.
  - Applies to all Saiyyiaat entries for that date
- **Example**: `'I need to work on controlling my anger. I said something hurtful today and I regret it.'`

### `created_at` (TIMESTAMP)
- **Type**: TIMESTAMP
- **Purpose**: Records when the reflection message was created
- **Default**: CURRENT_TIMESTAMP
- **Usage**: Track creation time

### `updated_at` (TIMESTAMP)
- **Type**: TIMESTAMP
- **Purpose**: Tracks when the reflection message was last modified
- **Nullable**: Yes (null if never updated)
- **Usage**: Track modification time

## Indexes

```sql
CREATE INDEX idx_daily_reflection_user_date ON daily_reflection_messages(user_id, reflection_date DESC);
CREATE INDEX idx_daily_reflection_date ON daily_reflection_messages(reflection_date);
```

## Relationships

The `daily_reflection_messages` table is referenced by:

1. **users** (reflection message owner)
   - `daily_reflection_messages.user_id` → `users.user_id`
   - One user can have many reflection messages (one per day)
   - CASCADE DELETE: If user is deleted, reflection messages are deleted

## Constraints

- **Primary Key**: `reflection_id` (unique, not null)
- **Foreign Key**: `user_id` → `users.user_id` (NOT NULL, CASCADE on delete)
- **Unique Constraint**: `(user_id, reflection_date)` - one set of messages per user per day
- **Application-Level Constraint**: At least one of `hasanaat_message` or `saiyyiaat_message` should be provided (enforced at application level, not database level to allow flexibility)

## Important Rules

### Rule 1: One Record Per Day
- One record per user per date (enforced by unique constraint)
- If user wants to update messages, update the existing record
- Do not create multiple records for the same date

### Rule 2: Optional Messages
- Both `hasanaat_message` and `saiyyiaat_message` are optional
- User can add only Hasanaat message, only Saiyyiaat message, or both
- At least one should be provided (enforced at application level)

### Rule 3: Daily Scope
- Messages reflect on ALL deeds of that category for the entire day
- Not per-deed messages (unlike old design where each deed had its own message)
- One Hasanaat message covers all Hasanaat entries for that date
- One Saiyyiaat message covers all Saiyyiaat entries for that date

## Example Data

### Reflection with Both Messages
```sql
INSERT INTO daily_reflection_messages (
    reflection_id,
    user_id,
    reflection_date,
    hasanaat_message,
    saiyyiaat_message
) VALUES (
    'dd0e8400-e29b-41d4-a716-446655440001',
    '550e8400-e29b-41d4-a716-446655440000',  -- User ID
    '2024-01-15',
    'Today I prayed all five prayers on time and felt a sense of peace. I also helped my neighbor carry groceries, which reminded me of the importance of community.',
    'I need to work on my patience. I got frustrated with a colleague today and said something I regret. I will apologize tomorrow and try to be more mindful.'
);
```

### Reflection with Only Hasanaat Message
```sql
INSERT INTO daily_reflection_messages (
    reflection_id,
    user_id,
    reflection_date,
    hasanaat_message,
    saiyyiaat_message
) VALUES (
    'dd0e8400-e29b-41d4-a716-446655440002',
    '550e8400-e29b-41d4-a716-446655440000',  -- User ID
    '2024-01-16',
    'Great day today! I completed all my prayers, read Quran, and spent quality time with family. Feeling grateful.',
    NULL  -- No Saiyyiaat message
);
```

### Reflection with Only Saiyyiaat Message
```sql
INSERT INTO daily_reflection_messages (
    reflection_id,
    user_id,
    reflection_date,
    hasanaat_message,
    saiyyiaat_message
) VALUES (
    'dd0e8400-e29b-41d4-a716-446655440003',
    '550e8400-e29b-41d4-a716-446655440000',  -- User ID
    '2024-01-17',
    NULL,  -- No Hasanaat message
    'I missed Fajr prayer today and felt disconnected. I also lost my temper during an argument. Need to refocus and improve tomorrow.'
);
```

### Update Existing Reflection
```sql
UPDATE daily_reflection_messages
SET 
    hasanaat_message = 'Updated: Today was even better than I thought. I also volunteered at the mosque.',
    updated_at = CURRENT_TIMESTAMP
WHERE user_id = '550e8400-e29b-41d4-a716-446655440000'
  AND reflection_date = '2024-01-15';
```

## Usage Notes

1. **Daily Scope**: Messages apply to all deeds of that category for the entire day
2. **Optional**: Both messages are optional, but at least one should be provided
3. **Update vs. Create**: Check if record exists for date before creating (use UPDATE if exists)
4. **Date Handling**: Use user's timezone to determine reflection_date
5. **Full-Text Search**: Consider adding full-text search index if searching messages is needed

## Business Rules

1. **One Per Day**: One record per user per date (enforced by unique constraint)
2. **Optional Messages**: Both messages are optional, but at least one should be provided
3. **Daily Scope**: Messages reflect on all deeds of that category for the day
4. **Update Existing**: Update existing record instead of creating duplicate
5. **Cascade Delete**: Deleting a user automatically deletes their reflection messages

## Query Examples

### Get Reflection for Specific Date
```sql
SELECT 
    hasanaat_message,
    saiyyiaat_message,
    created_at,
    updated_at
FROM daily_reflection_messages
WHERE user_id = '550e8400-e29b-41d4-a716-446655440000'
  AND reflection_date = '2024-01-15';
```

### Get All Reflections for User (Recent First)
```sql
SELECT 
    reflection_date,
    hasanaat_message,
    saiyyiaat_message,
    created_at
FROM daily_reflection_messages
WHERE user_id = '550e8400-e29b-41d4-a716-446655440000'
ORDER BY reflection_date DESC;
```

### Get Reflections with Hasanaat Messages Only
```sql
SELECT 
    reflection_date,
    hasanaat_message
FROM daily_reflection_messages
WHERE user_id = '550e8400-e29b-41d4-a716-446655440000'
  AND hasanaat_message IS NOT NULL
  AND saiyyiaat_message IS NULL
ORDER BY reflection_date DESC;
```

