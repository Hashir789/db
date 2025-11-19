# users Table

## Overview
The `users` table is the central table that stores all user account information and profile data. It serves as the foundation for authentication, user identification, and personalization features in the Kitaab platform.

## Purpose
- Store user authentication credentials (email, password hash)
- Maintain user profile information (username, full name)
- Track user activity (last login, account status)
- Support timezone-aware date handling
- Enable soft delete functionality (is_active flag)

## Schema

```sql
CREATE TABLE users (
    user_id UUID PRIMARY KEY,
    email VARCHAR UNIQUE NOT NULL,
    password_hash VARCHAR NOT NULL,
    username VARCHAR UNIQUE NOT NULL,
    full_name VARCHAR,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP,
    last_login TIMESTAMP,
    is_active BOOLEAN NOT NULL DEFAULT true,
    timezone VARCHAR NOT NULL DEFAULT 'UTC'
);
```

## Fields

### `user_id` (UUID, Primary Key)
- **Type**: UUID (v4)
- **Purpose**: Unique identifier for each user
- **Characteristics**: 
  - Globally unique across all systems
  - Non-sequential for security (prevents enumeration attacks)
  - Used as foreign key in all related tables
- **Example**: `550e8400-e29b-41d4-a716-446655440000`

### `email` (VARCHAR, Unique, Indexed)
- **Type**: VARCHAR
- **Purpose**: User's email address for authentication and communication
- **Constraints**: 
  - Must be unique (no duplicate emails)
  - Indexed for fast lookups during login
- **Usage**: Primary identifier for user login
- **Example**: `user@example.com`

### `password_hash` (VARCHAR, Encrypted)
- **Type**: VARCHAR
- **Purpose**: Securely stored password hash
- **Security**: 
  - Never stores plaintext passwords
  - Should use bcrypt, argon2, or similar hashing algorithm
  - Minimum 10 rounds recommended
- **Note**: This field is encrypted/hashed at the application level before storage

### `username` (VARCHAR, Unique, Indexed)
- **Type**: VARCHAR
- **Purpose**: Unique username for display and identification
- **Constraints**: 
  - Must be unique across all users
  - Indexed for fast lookups
- **Usage**: Displayed in UI, used for friend searches
- **Example**: `john_doe`

### `full_name` (VARCHAR)
- **Type**: VARCHAR
- **Purpose**: User's full name for display
- **Constraints**: None (multiple users can have the same name)
- **Nullable**: Yes
- **Usage**: Displayed in profile and friend views
- **Example**: `John Doe`

### `created_at` (TIMESTAMP, Indexed)
- **Type**: TIMESTAMP
- **Purpose**: Records when the user account was created
- **Indexed**: Yes (for queries filtering by registration date)
- **Usage**: 
  - Analytics (new user registrations)
  - Account age calculations
  - Sorting users by registration date

### `updated_at` (TIMESTAMP)
- **Type**: TIMESTAMP
- **Purpose**: Tracks when user profile information was last modified
- **Auto-update**: Should be updated automatically on any profile change
- **Usage**: Track profile activity

### `last_login` (TIMESTAMP)
- **Type**: TIMESTAMP
- **Purpose**: Records the timestamp of the user's last successful login
- **Nullable**: Yes (null if user has never logged in)
- **Usage**: 
  - Security monitoring
  - Identify inactive accounts
  - Activity tracking

### `is_active` (BOOLEAN, Default: true)
- **Type**: BOOLEAN
- **Purpose**: Soft delete flag for account status
- **Values**:
  - `true`: Active account (can log in and use the platform)
  - `false`: Deactivated/suspended account
- **Default**: `true`
- **Usage**: 
  - Soft delete (preserves data for potential reactivation)
  - Account suspension
  - Filter active users in queries

### `timezone` (VARCHAR, Default: 'UTC')
- **Type**: VARCHAR
- **Purpose**: User's timezone preference
- **Default**: `'UTC'`
- **Usage**: 
  - Convert timestamps to user's local time for display
  - Calculate entry dates based on user's timezone
  - Display dates/times in user's preferred format
- **Example**: `'America/New_York'`, `'Asia/Karachi'`, `'UTC'`

## Indexes

```sql
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_username ON users(username);
CREATE INDEX idx_users_is_active ON users(is_active) WHERE is_active = true;
CREATE INDEX idx_users_created_at ON users(created_at);
```

## Relationships

The `users` table is referenced by:

1. **deeds** (user-created custom deeds)
   - `deeds.user_id` → `users.user_id`
   - One user can create many custom deeds

2. **entries** (daily deed entries)
   - `entries.user_id` → `users.user_id`
   - One user can have many entries

3. **user_default_deeds** (default deeds opted-in)
   - `user_default_deeds.user_id` → `users.user_id`
   - One user can opt-in to many default deeds

4. **friend_relationships** (as requester and receiver)
   - `friend_relationships.requester_user_id` → `users.user_id`
   - `friend_relationships.receiver_user_id` → `users.user_id`
   - One user can have many friend relationships

5. **daily_reflection_messages** (daily reflection messages)
   - `daily_reflection_messages.user_id` → `users.user_id`
   - One user can have many daily reflection messages

6. **achievements** (custom user-specific achievements)
   - `achievements.user_id` → `users.user_id` (nullable)
   - One user can create many custom achievements

7. **demerits** (custom user-specific demerits)
   - `demerits.user_id` → `users.user_id` (nullable)
   - One user can create many custom demerits

8. **user_achievements** (earned achievements)
   - `user_achievements.user_id` → `users.user_id`
   - One user can earn many achievements

9. **user_demerits** (earned demerits)
   - `user_demerits.user_id` → `users.user_id`
   - One user can earn many demerits

10. **activity_logs** (who made changes)
    - `activity_logs.user_id` → `users.user_id`
    - One user can have many activity log entries

## Constraints

- **Primary Key**: `user_id` (unique, not null)
- **Unique Constraints**: 
  - `email` (one email per account)
  - `username` (one username per account)
- **Foreign Key Constraints**: None (this is the root table)

## Example Data

```sql
INSERT INTO users (
    user_id,
    email,
    password_hash,
    username,
    full_name,
    timezone,
    is_active
) VALUES (
    '550e8400-e29b-41d4-a716-446655440000',
    'john@example.com',
    '$2b$10$rK8...',  -- bcrypt hash
    'john_doe',
    'John Doe',
    'America/New_York',
    true
);
```

## Usage Notes

1. **Authentication**: Email and password_hash are used for login
2. **Soft Delete**: Use `is_active = false` instead of deleting records
3. **Timezone**: Always convert timestamps to user's timezone for display
4. **Last Login**: Update this field on every successful login
5. **Updated At**: Automatically update on any profile modification

## Security Considerations

- **Password Storage**: Never store plaintext passwords
- **Email Validation**: Validate email format at application level
- **Username Validation**: Enforce username rules (length, characters)
- **Rate Limiting**: Implement rate limiting for login attempts
- **Account Lockout**: Consider account lockout after failed login attempts

