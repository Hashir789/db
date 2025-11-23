# friend_relationships Table

## Overview
The `friend_relationships` table manages friend/parent-child connections between users. It tracks permission levels (read-only, write-only, or read-write) and relationship status (pending, accepted, rejected, blocked).

## Purpose
- Manage friend connections between users
- Track permission levels for friend access
- Support parent-child relationships
- Control access to user entries
- Track relationship status and history

## Schema

```sql
CREATE TABLE friend_relationships (
    relationship_id UUID PRIMARY KEY,
    requester_user_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    receiver_user_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    permission_type ENUM('read_only', 'write_only', 'read_write') NOT NULL,
    status ENUM('pending', 'accepted', 'rejected', 'blocked') NOT NULL DEFAULT 'pending',
    accepted_at TIMESTAMP,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP
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

### `permission_type` (ENUM, Not Null)
- **Type**: ENUM('read_only', 'write_only', 'read_write')
- **Purpose**: Defines what the requester can do with receiver's entries
- **Values**:
  - `'read_only'`: Can only view receiver's entries (no modifications)
  - `'write_only'`: Can only create/update receiver's entries (cannot view)
  - `'read_write'`: Can both view and create/update receiver's entries
- **Usage**: 
  - Set by receiver when accepting request
  - Enforced at application level for entry access
  - Can be updated after relationship is established

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

### Rule 1: Bidirectional Relationships
- Relationships are unidirectional (requester → receiver)
- For bidirectional friendship, create two separate records:
  - User A → User B (requester: A, receiver: B)
  - User B → User A (requester: B, receiver: A)

### Rule 2: Permission Enforcement
- `permission_type` is enforced at application level
- Friends with `read_only` can only query/view entries
- Friends with `write_only` can only create/update entries (cannot view)
- Friends with `read_write` can do both

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
    permission_type,
    status,
    accepted_at
) VALUES (
    'bb0e8400-e29b-41d4-a716-446655440001',
    '550e8400-e29b-41d4-a716-446655440000',  -- User A (requester)
    '550e8400-e29b-41d4-a716-446655440999',  -- User B (receiver)
    'read_write',  -- Default permission (can be changed by receiver)
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
    permission_type = 'read_write',  -- Receiver can set this
    accepted_at = CURRENT_TIMESTAMP,
    updated_at = CURRENT_TIMESTAMP
WHERE relationship_id = 'bb0e8400-e29b-41d4-a716-446655440001';
```

### Parent-Child Relationship
```sql
-- Parent (requester) → Child (receiver) with read_write
INSERT INTO friend_relationships (
    relationship_id,
    requester_user_id,
    receiver_user_id,
    permission_type,
    status,
    accepted_at
) VALUES (
    'bb0e8400-e29b-41d4-a716-446655440002',
    '550e8400-e29b-41d4-a716-446655440888',  -- Parent
    '550e8400-e29b-41d4-a716-446655440999',  -- Child
    'read_write',  -- Parent can view and manage child's entries
    'accepted',
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

1. **Permission Check**: Always check `permission_type` before allowing friend to access entries
2. **Status Check**: Only allow access when `status = 'accepted'`
3. **Bidirectional**: Create two records for bidirectional friendship
4. **Permission Updates**: Receiver can update `permission_type` after acceptance
5. **Blocking**: Either party can block the relationship
6. **Audit Trail**: Track permission changes via `updated_at` and activity logs

## Business Rules

1. **Unique Relationship**: One relationship record per (requester, receiver) pair
2. **Self-Reference**: Cannot create relationship with yourself (enforced at application level)
3. **Permission Control**: Receiver sets permission when accepting (can be changed later)
4. **Status Management**: Only `accepted` relationships allow entry access
5. **Cascade Delete**: Deleting a user deletes all their relationships


