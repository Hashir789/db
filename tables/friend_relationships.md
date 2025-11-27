# friend_relationships Table

## Overview
The `friend_relationships` table manages friend and follow connections between users. It tracks relationship type (friend vs follow) and status (pending, accepted, rejected, blocked). **Note**: Deed-level permissions are managed separately in the `friend_deed_permissions` table, not in this table.

## Purpose
- Manage friend and follow connections between users
- Track relationship type (mutual friendship vs one-way following)
- Track relationship status (pending, accepted, rejected, blocked)
- **Note**: Deed-level permissions (read/write) are managed in `friend_deed_permissions` table

## Schema

```sql
CREATE TABLE friend_relationships (
    relationship_id UUID PRIMARY KEY,
    requester_user_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    receiver_user_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    relationship_type ENUM('friend', 'follow') NOT NULL,
    status ENUM('pending', 'accepted', 'rejected', 'blocked') NOT NULL DEFAULT 'pending',
    accepted_at TIMESTAMP,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP,
    CONSTRAINT check_no_self_reference CHECK (requester_user_id != receiver_user_id),
    CONSTRAINT unique_relationship UNIQUE (requester_user_id, receiver_user_id, relationship_type)
);

CREATE INDEX idx_friend_relationships_requester ON friend_relationships(requester_user_id, status);
CREATE INDEX idx_friend_relationships_receiver ON friend_relationships(receiver_user_id, status);
CREATE INDEX idx_friend_relationships_active ON friend_relationships(requester_user_id, receiver_user_id) WHERE status = 'accepted';
```

## Fields

### `relationship_id` (UUID, Primary Key)
- **Type**: UUID (v4)
- **Purpose**: Unique identifier for each relationship
- **Characteristics**: Globally unique
- **Example**: `bb0e8400-e29b-41d4-a716-446655440001`

### `requester_user_id` (UUID, Foreign Key, Not Null)
- **Type**: UUID
- **Purpose**: The user who sent the friend request
- **Foreign Key**: `users.user_id`
- **Constraints**: NOT NULL
- **Cascade**: ON DELETE CASCADE (if requester is deleted, relationship is deleted)
- **Indexed**: Yes (for requester-based queries)
- **Usage**: Identifies who initiated the relationship

### `receiver_user_id` (UUID, Foreign Key, Not Null)
- **Type**: UUID
- **Purpose**: The user who received the friend request
- **Foreign Key**: `users.user_id`
- **Constraints**: NOT NULL
- **Cascade**: ON DELETE CASCADE (if receiver is deleted, relationship is deleted)
- **Indexed**: Yes (for receiver-based queries)
- **Usage**: Identifies who received the relationship request

### `relationship_type` (ENUM, Not Null)
- **Type**: ENUM('friend', 'follow')
- **Purpose**: Defines the type of relationship
- **Values**:
  - `'friend'`: Mutual friendship (requires acceptance from receiver)
  - `'follow'`: One-way following (approval optional, depends on receiver's settings)
- **Usage**: 
  - Determines relationship behavior and acceptance requirements
  - **Note**: Deed-level permissions are managed separately in `friend_deed_permissions` table

### `status` (ENUM, Default: 'pending', Indexed)
- **Type**: ENUM('pending', 'accepted', 'rejected', 'blocked')
- **Purpose**: Current status of the relationship
- **Values**:
  - `'pending'`: Friend request sent but not yet responded to
  - `'accepted'`: Friend request accepted, relationship active
  - `'rejected'`: Friend request rejected by receiver
  - `'blocked'`: Relationship blocked (by either party)
- **Default**: `'pending'`
- **Indexed**: Yes (for status-based queries)
- **Usage**: 
  - Track relationship lifecycle
  - Filter active relationships (status = 'accepted')
  - Prevent duplicate requests

### `accepted_at` (TIMESTAMP, Nullable)
- **Type**: TIMESTAMP
- **Purpose**: Records when the relationship was accepted
- **Nullable**: Yes (null if not yet accepted)
- **Usage**: 
  - Track when relationship became active
  - Used for relationship history/analytics
  - Only set when status changes to 'accepted'

### `created_at` (TIMESTAMP, Indexed)
- **Type**: TIMESTAMP
- **Purpose**: Records when the relationship was created (request sent)
- **Default**: CURRENT_TIMESTAMP
- **Indexed**: Yes (for chronological queries)
- **Usage**: Track when friend request was sent

### `updated_at` (TIMESTAMP)
- **Type**: TIMESTAMP
- **Purpose**: Tracks when relationship details were last modified
- **Nullable**: Yes (null if never updated)
- **Usage**: Track modifications to permission_type or status

## Indexes

```sql
CREATE INDEX idx_friend_relationships_requester ON friend_relationships(requester_user_id, status);
CREATE INDEX idx_friend_relationships_receiver ON friend_relationships(receiver_user_id, status);
CREATE INDEX idx_friend_relationships_active ON friend_relationships(requester_user_id, receiver_user_id) WHERE status = 'accepted';
```

## Relationships

The `friend_relationships` table references:

1. **users** (requester)
   - `friend_relationships.requester_user_id` → `users.user_id`
   - One user can send many friend requests
   - CASCADE DELETE: If requester is deleted, relationships are deleted

2. **users** (receiver)
   - `friend_relationships.receiver_user_id` → `users.user_id`
   - One user can receive many friend requests
   - CASCADE DELETE: If receiver is deleted, relationships are deleted

## Constraints

- **Primary Key**: `relationship_id` (unique, not null)
- **Foreign Keys**: 
  - `requester_user_id` → `users.user_id` (NOT NULL, CASCADE on delete)
  - `receiver_user_id` → `users.user_id` (NOT NULL, CASCADE on delete)
- **Unique Constraint**: `(requester_user_id, receiver_user_id)` - one relationship per pair
- **Check Constraint**: `requester_user_id != receiver_user_id` (enforced at application level)

## Important Rules

### Rule 1: Relationship Types
- **Friend**: Mutual friendship requiring acceptance from receiver
- **Follow**: One-way following (approval may be optional based on receiver's settings)
- Relationships are unidirectional (requester → receiver)
- For bidirectional friendship, create two separate records:
  - User A → User B (requester: A, receiver: B, type: 'friend')
  - User B → User A (requester: B, receiver: A, type: 'friend')

### Rule 2: Deed-Level Permissions
- **Permissions are NOT stored in this table**
- Deed-level permissions are managed in `friend_deed_permissions` table
- Multiple friends/followers can have **read** access per deed
- Only one friend/follower can have **write** access per deed (enforced at application level)
- Permissions are independent of relationship type (friend vs follow)

### Rule 3: Status Transitions
- `pending` → `accepted` (when receiver accepts)
- `pending` → `rejected` (when receiver rejects)
- Any status → `blocked` (when either party blocks)
- `accepted` → `blocked` (when relationship is blocked after acceptance)

## Example Data

### Pending Friend Request
```sql
INSERT INTO friend_relationships (
    relationship_id,
    requester_user_id,
    receiver_user_id,
    relationship_type,
    status,
    accepted_at
) VALUES (
    'bb0e8400-e29b-41d4-a716-446655440001',
    '550e8400-e29b-41d4-a716-446655440000',  -- User A (requester)
    '550e8400-e29b-41d4-a716-446655440999',  -- User B (receiver)
    'friend',  -- Mutual friendship
    'pending',
    NULL  -- Not yet accepted
);
```

### Accepted Friend Relationship
```sql
-- Update to accepted
UPDATE friend_relationships
SET 
    status = 'accepted',
    accepted_at = CURRENT_TIMESTAMP,
    updated_at = CURRENT_TIMESTAMP
WHERE relationship_id = 'bb0e8400-e29b-41d4-a716-446655440001';

-- After acceptance, receiver can set deed-level permissions in friend_deed_permissions table
```

### Follow Relationship
```sql
-- User A follows User B (one-way)
INSERT INTO friend_relationships (
    relationship_id,
    requester_user_id,
    receiver_user_id,
    relationship_type,
    status,
    accepted_at
) VALUES (
    'bb0e8400-e29b-41d4-a716-446655440003',
    '550e8400-e29b-41d4-a716-446655440000',  -- User A (requester/follower)
    '550e8400-e29b-41d4-a716-446655440999',  -- User B (receiver/followed)
    'follow',  -- One-way following
    'accepted',  -- May be auto-accepted based on User B's settings
    CURRENT_TIMESTAMP
);
```

### Rejected Friend Request
```sql
UPDATE friend_relationships
SET 
    status = 'rejected',
    updated_at = CURRENT_TIMESTAMP
WHERE relationship_id = 'bb0e8400-e29b-41d4-a716-446655440001';
```

### Blocked Relationship
```sql
UPDATE friend_relationships
SET 
    status = 'blocked',
    updated_at = CURRENT_TIMESTAMP
WHERE relationship_id = 'bb0e8400-e29b-41d4-a716-446655440001';
```

## Usage Notes

1. **Deed-Level Permissions**: Check `friend_deed_permissions` table for read/write permissions, not this table
2. **Status Check**: Only allow access when `status = 'accepted'`
3. **Bidirectional**: Create two records for bidirectional friendship
4. **Relationship Type**: `friend` requires acceptance, `follow` may be auto-accepted
5. **Blocking**: Either party can block the relationship
6. **Audit Trail**: Track relationship changes via `updated_at`

## Business Rules

1. **Unique Relationship**: One relationship record per (requester, receiver, relationship_type) combination
2. **Self-Reference**: Cannot create relationship with yourself (enforced via check constraint)
3. **Deed-Level Permissions**: Permissions are managed in `friend_deed_permissions` table, not here
4. **Status Management**: Only `accepted` relationships allow entry access (with proper permissions)
5. **Cascade Delete**: Deleting a user deletes all their relationships
6. **Permission Independence**: Deed-level permissions are independent of relationship type (friend vs follow)


