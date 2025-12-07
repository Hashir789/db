# Kitaab Database Architecture Plan

## Table of Contents
1. [Overview](#overview)
2. [Core Workflow](#core-workflow)
3. [Entity-Relationship Model](#entity-relationship-model)
4. [Database Schema Design](#database-schema-design)
5. [Data Flow & Workflows](#data-flow--workflows)
6. [Database Strategies](#database-strategies)
7. [Indexing Strategy](#indexing-strategy)
8. [Security Considerations](#security-considerations)
9. [Scalability & Performance](#scalability--performance)
10. [Migration & Backup Strategy](#migration--backup-strategy)

---

## Overview

Kitaab is a spiritual self-accountability platform that allows Muslims to track their good deeds (Hasanaat) and bad deeds (Saiyyiaat) throughout their lifetime. The database must support:

- **Dual deed categories**: Hasanaat and Saiyyiaat
- **Flexible measurement systems**: Scale-based (Yes/No, custom scales) and count-based
- **Hierarchical structures**: Deed items with level-based nesting
- **Entry rules**: Entries are created directly for the deed item being tracked
- **Daily logging**: Chronological entries with daily reflection messages (one Hasanaat message, one Saiyyiaat message per day)
- **Time-range analytics**: Daily, weekly, monthly, yearly, and custom date ranges
- **Hide functionality**: Two types - hide from input forms and graphs, or hide from graphs only
- **Merits/Demerits system**: Time-based evaluations of user behavior (positive rewards or negative penalties) with AND/OR logic
- **Targets system**: User-defined, time-bounded goals spanning multiple deeds
- **Social features**: Mutual friendship and one-way following with deed-level permissions (multiple read, one write per deed)
- **Deed ownership**: All deeds have user_id (owned by the user who created them)
- **High scalability**: Support for millions of users

---

## Core Workflow

### User Registration & Onboarding
1. User registers and completes profile setup
2. User can create their own deeds
3. System initializes user's first day entry structure

### Daily Deed Logging Workflow
1. **Entry Creation**: User selects date (default: today)
2. **Deed Selection**: Choose from Hasanaat or Saiyyiaat section (can select parent or child deed)
3. **Measurement Input**:
   - **Scale-based**: Select from predefined scale (e.g., Yes/No, Excellent/Good/Average)
   - **Count-based**: Enter numeric value
4. **Validation**: Ensure measure type consistency (child deeds inherit from parent)
5. **Daily Reflection Messages**: User can optionally add:
   - One Hasanaat reflection message (for all hasanaat deeds of the day)
   - One Saiyyiaat reflection message (for all saiyyiaat deeds of the day)
6. **Save**: Entry stored with timestamp and metadata
7. **Friend/Follower Edits**: If edited by friend/follower, `edited_by_user_id` is set; owner can revert within 30 days

### Deed Creation Workflow
1. User navigates to create a new deed
2. Selects category (Hasanaat or Saiyyiaat)
3. Defines deed name and description
4. Chooses measure type (Scale-based or Count-based)
5. **If Scale-based**: Defines scale values
6. **If Count-based**: System sets up numeric input
7. Optionally adds sub-deeds (with same measure type constraint)
8. Deed saved and becomes available for logging

### Analytics & Review Workflow
1. User selects time range (daily/weekly/monthly/yearly/custom)
2. System queries entries for selected period
3. Aggregates data by deed, sub-deed, and category
4. Calculates trends (improvement/decline)
5. Generates visualizations (charts, graphs)
6. Computes balance between Hasanaat and Saiyyiaat

### Social Features Workflow
1. **Friend/Follow Request**: User A sends friend request or follows User B
2. **Request Handling**: User B can accept, reject, or block (approval optional for follow model)
3. **Deed-Level Permissions**: User B assigns permissions per deed:
   - **Read**: Multiple friends/followers can have read access
   - **Write**: Only one friend/follower can have write access per deed
4. **Entry Access**: Friend/follower can view/edit entries based on permissions
5. **Edit Tracking**: Friend/follower edits create new entry rows with `edited_by_user_id` set
6. **Revert Window**: Owner can revert friend/follower changes within 30 days

---

## Entity-Relationship Model

### Core Entities

#### 1. **Users**
- Primary entity representing platform users
- Stores authentication and profile information

#### 2. **Deed**
- Represents deed definitions (owned by users)
- Contains category type (Hasanaat/Saiyyiaat) and measure type (scale/count)
- All deeds have `user_id NOT NULL` (owned by the creating user)

#### 3. **Deed_Items**
- Represents deed items/sub-deeds that belong to a deed
- Contains name, description, level, hide_type, and display_order
- References parent deed via `deed_id`

#### 4. **Entries**
- Daily logging records for deed items
- Links user, deed_item, and date
- Stores measurement values
- Tracks friend/follower edits via `edited_by_user_id`
- Full history maintained in entries table (no separate activity_logs)

#### 5. **Scale_Definitions**
- Defines custom scales for scale-based deeds with versioning support
- Example: Excellent, Good, Average, Poor
- Supports soft versioning: old scale values are preserved when updated
- Historical entries maintain references to inactive scale values
- Only active scale values appear in new input options

#### 5. **Friend_Relationships**
- Manages mutual friendship and one-way following
- Tracks relationship type (friend/follow) and status (pending/accepted/rejected/blocked)

#### 6. **Friend_Deed_Permissions**
- Deed-level permissions for friends/followers
- Multiple friends/followers can have read access per deed
- Only one friend/follower can have write access per deed

#### 7. **Daily_Reflection_Messages**
- Stores optional daily reflection messages
- One Hasanaat message and one Saiyyiaat message per user per day

#### 8. **Merits**
- Defines time-based evaluation rules (positive rewards or negative penalties)
- Each merit has a duration window, logical type (AND/OR), and category (positive/negative)
- System-evaluated performance tracking over defined time periods

#### 9. **Merit_Items**
- Conditions attached to each merit/demerit
- Links to specific deeds with count or scale requirements
- Only one condition type per item (count-based or scale-based)

#### 10. **Targets**
- User-defined goals with time bounds (start_date, end_date)
- Can span multiple deeds
- Represents personal objectives users set for themselves

#### 11. **Target_Items**
- Conditions for each target tied to specific deeds
- Uses count or scale requirements (only one per item)
- Defines what must be achieved for the target

---

## Database Schema Design

### Tables Overview

| # | Table Name | Primary Purpose | Key Fields Count |
|---|-----------|----------------|------------------|
| 1 | `users` | User accounts and authentication | 9 fields |
| 2 | `deed` | Deed definitions (Hasanaat/Saiyyiaat) | 4 fields |
| 3 | `deed_items` | Deed items/sub-deeds | 8 fields |
| 4 | `scale_definitions` | Scale values for scale-based deeds with versioning | 9 fields |
| 5 | `entries` | Daily logging records for deeds | 8 fields |
| 6 | `friend_relationships` | Friend and follow relationships between users | 7 fields |
| 7 | `friend_deed_permissions` | Deed-level permissions for friends/followers | 6 fields |
| 8 | `daily_reflection_messages` | Daily reflection messages (Hasanaat/Saiyyiaat) | 6 fields |
| 9 | `merits` | Time-based evaluation rules (positive/negative) | 8 fields |
| 10 | `merit_items` | Conditions for each merit tied to specific deeds | 5 fields |
| 11 | `targets` | User-defined, time-bounded goals | 8 fields |
| 12 | `target_items` | Conditions for each target tied to specific deeds | 5 fields |

**Total Tables**: 12

### Table Specifications

#### **users**
```sql
- user_id (UUID, Primary Key)
- email (VARCHAR, Unique, Indexed)
- password_hash (VARCHAR, Encrypted)
- username (VARCHAR, Unique, Indexed)
- full_name (VARCHAR)
- created_at (TIMESTAMP, Indexed)
- updated_at (TIMESTAMP)
- last_login (TIMESTAMP)
- is_active (BOOLEAN, Default: true)
- timezone (VARCHAR, Default: 'UTC')
```

#### **deed**
```sql
- deed_id (UUID, Primary Key)
- user_id (UUID, Foreign Key → users.user_id, Not Null, Indexed)
  -- Owner of the deed (the user who created it)
- category_type (ENUM: 'hasanaat', 'saiyyiaat', Not Null, Indexed)
- measure_type (ENUM: 'scale', 'count', Not Null)
```

**Notes**: 
- All deeds have `user_id NOT NULL` (owned by the creating user)
- Defines the deed category and measurement type
- Deed items belong to a deed via `deed_id` foreign key

#### **deed_items**
```sql
- deed_item_id (UUID, Primary Key)
- deed_id (UUID, Foreign Key → deed.deed_id, ON DELETE CASCADE, Not Null, Indexed)
  -- The deed this item belongs to
- name (VARCHAR, Not Null)
- description (TEXT, Nullable)
- level (INTEGER, Not Null, Default: 0)
  -- Level/nesting depth of the item
- hide_type (ENUM: 'none', 'hide_from_all', 'hide_from_graphs', Default: 'none')
  -- 'hide_from_all': Hidden from input forms and graphs
  -- 'hide_from_graphs': Visible in input forms but hidden in graphs only
  -- 'none': Visible everywhere
- display_order (INTEGER, Default: 0)
- is_active (BOOLEAN, Default: true)
- created_at (TIMESTAMP)
- updated_at (TIMESTAMP)
```

**Notes**: 
- Deed items belong to a deed and represent sub-deeds/items
- `level` indicates nesting depth (0 for top-level items)
- All items inherit `category_type` and `measure_type` from parent deed


#### **scale_definitions**
```sql
- scale_id (UUID, Primary Key)
- deed_id (UUID, Foreign Key → deed.deed_id, ON DELETE CASCADE, Indexed)
- scale_value (VARCHAR, Not Null)  -- e.g., "Yes", "No", "Excellent", "Good"
- numeric_value (INTEGER, Nullable)  -- For ordering/analytics (e.g., Yes=1, No=0)
- display_order (INTEGER, Not Null)
- is_active (BOOLEAN, Default: true, Indexed)
- created_at (TIMESTAMP, Not Null, Default: CURRENT_TIMESTAMP, Indexed)
- deactivated_at (TIMESTAMP, Nullable)  -- When this scale value was deactivated
- version (INTEGER, Not Null, Default: 1)  -- Version number for this scale value
```

**Usage**: For scale-based deeds. Stores possible scale values and their ordering with versioning support.

**Versioning Behavior**:
- When scale values are updated for a deed, old values are preserved with `is_active = false` and `deactivated_at` set
- New scale values are created with `is_active = true` and incremented `version`
- Historical entries continue to reference old inactive scale values correctly
- Only active scale values (`is_active = true`) appear in new input options
- Prevents duplicate active scale values per deed via unique constraint

**Constraints**:
- Unique constraint on `(deed_id, scale_value, is_active)` where `is_active = true` - prevents duplicate active scales
- `deactivated_at` must be NULL when `is_active = true`
- `deactivated_at` must be set when `is_active = false` (enforced via trigger)

#### **entries**
```sql
- entry_id (UUID, Primary Key)
- user_id (UUID, Foreign Key → users.user_id, ON DELETE CASCADE, Indexed)
  -- Owner of the entry (deed owner)
- deed_item_id (UUID, Foreign Key → deed_items.deed_item_id, ON DELETE CASCADE, Indexed)
  -- The deed item being tracked
- entry_date (DATE, Not Null, Indexed)
- measure_value (VARCHAR, Nullable)  -- For scale-based: stores scale_value
- count_value (INTEGER, Nullable)  -- For count-based: stores numeric count
- edited_by_user_id (UUID, Foreign Key → users.user_id, Nullable)
  -- NULL for owner's entry, set when friend/follower edits
  -- Creates new entry row when friend/follower edits (old value remains)
- created_at (TIMESTAMP, Indexed)
- updated_at (TIMESTAMP)
```

**Constraints**:
- **Check Constraint**: `(measure_value IS NOT NULL AND count_value IS NULL) OR (count_value IS NOT NULL AND measure_value IS NULL)` - ensures measure type consistency
- **Check Constraint**: `measure_value` must exist in `scale_definitions` for the deed (if scale-based) - enforced via trigger
  - For new entries: Only active scale values are allowed
  - For existing entries: Historical inactive scale values are allowed if entry was created when scale was active
- **Unique Constraint**: `(user_id, deed_item_id, entry_date, edited_by_user_id)` - one entry per user per deed item per date per editor
- **Revert Window Constraint**: Friend/follower edits can only be reverted within 30 days (enforced via trigger/application logic)
- **Entry Rule**: Entries are created directly for the deed item being tracked
- **History**: Full edit history maintained in entries table (no separate activity_logs needed)
- **Scale Versioning**: Historical entries preserve references to inactive scale values for data integrity


#### **friend_relationships**
```sql
- relationship_id (UUID, Primary Key)
- requester_user_id (UUID, Foreign Key → users.user_id, ON DELETE CASCADE, Indexed)
- receiver_user_id (UUID, Foreign Key → users.user_id, ON DELETE CASCADE, Indexed)
- relationship_type (ENUM: 'friend', 'follow', Not Null)
  -- 'friend': Mutual friendship (requires acceptance)
  -- 'follow': One-way following (approval optional)
- status (ENUM: 'pending', 'accepted', 'rejected', 'blocked', Default: 'pending', Indexed)
- accepted_at (TIMESTAMP, Nullable)
- created_at (TIMESTAMP, Indexed)
- updated_at (TIMESTAMP)
```

**Constraints**: 
- Unique constraint on `(requester_user_id, receiver_user_id, relationship_type)`
- Check constraint: `requester_user_id != receiver_user_id`
- **Note**: Deed-level permissions are managed in `friend_deed_permissions` table

#### **friend_deed_permissions**
```sql
- permission_id (UUID, Primary Key)
- relationship_id (UUID, Foreign Key → friend_relationships.relationship_id, ON DELETE CASCADE, Indexed)
- deed_id (UUID, Foreign Key → deed.deed_id, ON DELETE CASCADE, Indexed)
- permission_type (ENUM: 'read', 'write', Not Null)
- is_active (BOOLEAN, Default: true)
- created_at (TIMESTAMP)
- updated_at (TIMESTAMP)
```

**Constraints**:
- Unique constraint on `(relationship_id, deed_id, permission_type)` for write permissions
- Multiple read permissions allowed per deed
- Only one write permission allowed per deed (enforced at application level)
- **Note**: Deed-level permissions allow fine-grained access control

#### **daily_reflection_messages**
```sql
- reflection_id (UUID, Primary Key)
- user_id (UUID, Foreign Key → users.user_id, ON DELETE CASCADE, Indexed)
- reflection_date (DATE, Not Null, Indexed)
- hasanaat_message (TEXT, Nullable)  -- One optional message for all hasanaat deeds of the day
- saiyyiaat_message (TEXT, Nullable)  -- One optional message for all saiyyiaat deeds of the day
- created_at (TIMESTAMP)
- updated_at (TIMESTAMP)
```

**Constraints**:
- Unique constraint on `(user_id, reflection_date)` - one set of messages per user per day
- At least one of `hasanaat_message` or `saiyyiaat_message` should be provided (enforced at application level)

#### **merits**
```sql
- merit_id (UUID, Primary Key)
- title (VARCHAR, Not Null)  -- Short name for display in UI
- description (TEXT, Nullable)  -- Explains what it checks and why it matters
- merit_duration (INTEGER, Not Null)  -- Number of days the evaluation covers
- merit_type (ENUM: 'AND', 'OR', Not Null)  -- Logical rule
  -- 'AND': All linked deeds must satisfy their rules
  -- 'OR': Any one linked deed satisfying its rule is enough
- merit_category (ENUM: 'positive', 'negative', Not Null)  -- Whether it's positive (achievement-style) or negative (demerit-style)
- is_active (BOOLEAN, Default: true)
- created_at (TIMESTAMP)
- updated_at (TIMESTAMP)
```

**Usage**: Defines time-based evaluation rules. Example: "Perfect Prayer Week" = merit_duration=7, merit_type='AND', merit_category='positive' (all prayers must be on time for 7 days)

#### **merit_items**
```sql
- merit_item_id (UUID, Primary Key)
- merit_id (UUID, Foreign Key → merits.merit_id, ON DELETE CASCADE, Indexed)
- deed_item_id (UUID, Foreign Key → deed_items.deed_item_id, ON DELETE CASCADE, Indexed)
- merit_items_count (INTEGER, Nullable)  -- Required number of times (only for count-type deeds)
- scale_id (UUID, Foreign Key → scale_definitions.scale_id, Nullable)  -- Required scale value (only for scale-type deeds)
- created_at (TIMESTAMP)
```

**Constraints**:
- Check constraint: Only one of `merit_items_count` or `scale_id` can be set (not both, not neither)
- **Logic**: Only one condition type per item - count-based deeds use `merit_items_count`, scale-based deeds use `scale_id`
- **Scale Versioning**: `scale_id` references a specific scale definition. If the scale is later deactivated, the merit_item continues to reference it correctly (historical integrity preserved)

**Usage**: Defines conditions for each merit. Each item belongs to exactly one deed and specifies either a count requirement or a scale requirement.

#### **targets**
```sql
- target_id (UUID, Primary Key)
- user_id (UUID, Foreign Key → users.user_id, ON DELETE CASCADE, Indexed)
- title (VARCHAR, Not Null)  -- Name of the target
- description (TEXT, Nullable)  -- Explanation of the goal
- start_date (DATE, Not Null, Indexed)  -- When the target starts
- end_date (DATE, Not Null, Indexed)  -- When the target ends
- is_active (BOOLEAN, Default: true)
- created_at (TIMESTAMP)
- updated_at (TIMESTAMP)
```

**Usage**: User-defined, time-bounded goals. Example: "Pray 5 times daily for 30 days" = start_date='2024-01-01', end_date='2024-01-30'

**Constraints**:
- Check constraint: `end_date >= start_date`
- Unique constraint on `(user_id, title, start_date)` - one target per user per title per start date

#### **target_items**
```sql
- target_item_id (UUID, Primary Key)
- target_id (UUID, Foreign Key → targets.target_id, ON DELETE CASCADE, Indexed)
- deed_item_id (UUID, Foreign Key → deed_items.deed_item_id, ON DELETE CASCADE, Indexed)
- target_items_count (INTEGER, Nullable)  -- Required count (if count-based)
- scale_id (UUID, Foreign Key → scale_definitions.scale_id, Nullable)  -- Required scale (if scale-based)
- created_at (TIMESTAMP)
```

**Constraints**:
- Check constraint: Only one of `target_items_count` or `scale_id` can be set (not both, not neither)
- **Logic**: Only one condition type per item - count-based deeds use `target_items_count`, scale-based deeds use `scale_id`
- **Scale Versioning**: `scale_id` references a specific scale definition. If the scale is later deactivated, the target_item continues to reference it correctly (historical integrity preserved)

**Usage**: Defines conditions for each target. Each item belongs to exactly one deed and specifies either a count requirement or a scale requirement.

### Relationships Summary

```
users (1) ────< (M) deed
users (1) ────< (M) entries
users (1) ────< (M) friend_relationships (as requester)
users (1) ────< (M) friend_relationships (as receiver)
users (1) ────< (M) daily_reflection_messages
users (1) ────< (M) targets (user-defined goals)

deed (1) ────< (M) deed_items
deed (1) ────< (M) scale_definitions
deed (1) ────< (M) friend_deed_permissions

deed_items (1) ────< (M) entries
deed_items (1) ────< (M) merit_items (conditions for merits)
deed_items (1) ────< (M) target_items (conditions for targets)

friend_relationships (1) ────< (M) friend_deed_permissions

merits (1) ────< (M) merit_items (conditions per merit)
targets (1) ────< (M) target_items (conditions per target)

scale_definitions (1) ────< (M) merit_items (scale requirements)
scale_definitions (1) ────< (M) target_items (scale requirements)
```

---

## Data Flow & Workflows

### 1. User Registration Flow
```
1. User submits registration → Create user record
2. User completes profile setup
3. User can create their own deeds
4. System initializes user's first day entry structure
```

### 2. Daily Entry Creation Flow
```
1. User selects date and deed (can be parent or child deed)
2. System validates:
   - Deed item exists and belongs to a deed owned by the user
   - Deed is not hidden from input (hide_type != 'hide_from_all')
   - User has permission (owner or friend/follower with write permission)
3. If scale-based:
   - User selects from scale_definitions for that deed
   - Store value in entries.measure_value
4. If count-based:
   - User enters numeric value
   - Store value in entries.count_value
5. **Friend/Follower Edit Handling**:
   - If edited by friend/follower: Set edited_by_user_id, create new entry row
   - Old entry remains intact (full history maintained)
   - Owner can revert within 30 days
6. Create entry record
7. **Daily Reflection Messages** (optional):
   - User can add/update daily_reflection_messages for the date
   - One hasanaat_message and/or one saiyyiaat_message per day
8. **Merit/Demerit Evaluation** (background process):
   - Evaluate merit conditions based on entries within the merit_duration window
   - Check if all (AND) or any (OR) linked deeds satisfy their conditions
   - Track positive merits (rewards) and negative merits (penalties)
   - Create merit evaluation records if conditions met
```

### 3. Deed Creation Flow
```
1. User creates a deed:
   - Provide category_type (hasanaat/saiyyiaat)
   - Provide measure_type (scale/count)
   - Create deed record with user_id (NOT NULL)
2. User creates deed items:
   - Add name, description
   - Set level (0 for top-level items)
   - Set hide_type and display_order
   - Create deed_items records linked to deed_id
3. If scale-based:
   - User defines scale values
   - Create scale_definitions records linked to deed_id with:
     * is_active = true
     * created_at = CURRENT_TIMESTAMP
     * deactivated_at = NULL
     * version = 1
4. If count-based:
   - No scale_definitions needed
5. Deed and items now available for logging
```

### 3a. Scale Values Update Flow (Versioning)
```
1. User updates scale values for an existing scale-based deed
2. System preserves existing scale values:
   - Set is_active = false for old scale values
   - Set deactivated_at = CURRENT_TIMESTAMP for old scale values
   - Keep old scale values in database (for historical entries)
3. System creates new scale values:
   - Create new scale_definitions records with:
     * is_active = true
     * created_at = CURRENT_TIMESTAMP
     * deactivated_at = NULL
     * version = MAX(version) + 1 for this deed
4. Historical entries remain valid:
   - Old entries continue to reference inactive scale values
   - Validation allows inactive scales if entry was created before deactivation
5. New entries can only use active scale values
6. Analytics can query across all versions or filter by active status
```

### 4. Analytics Query Flow
```
1. User selects time range and optional filters (category, deed, etc.)
2. System constructs query:
   - Filter entries by user_id, entry_date range
   - Join with deeds for category filtering
   - **Filter out hidden items**:
     * Exclude deeds/sub-deeds where hide_type = 'hide_from_all' (from all views)
     * Exclude deeds/sub-deeds where hide_type = 'hide_from_graphs' (from graphs only)
   - Aggregate by deed_id, deed_item_id
3. Calculate metrics:
   - Total entries per deed (respecting hide_type rules)
   - Average/trend for scale-based (using numeric_value from scale_definitions)
   - Sum/total for count-based
   - Hasanaat vs Saiyyiaat balance
   - Trend analysis (improvement/decline)
   - Include merit evaluations and target progress for the time range
4. Return aggregated data for visualization
```

### 5. Merit/Demerit Evaluation Flow
```
1. Trigger: After daily entry creation/update or scheduled daily check
2. For each active merit (system-wide):
   - Get merit_duration (evaluation window in days)
   - Get merit_type (AND/OR logic) and merit_category (positive/negative)
   - Query all merit_items for this merit
3. For each merit_item:
   - Determine deed type (count-based or scale-based)
   - If count-based: Check if deed has required merit_items_count within the time window
   - If scale-based: Check if deed has required scale_id value within the time window
4. Apply merit_type logic:
   - **AND**: All linked deeds must satisfy their rules
   - **OR**: Any one linked deed satisfying its rule is enough
5. If condition met:
   - Create merit evaluation record
   - Notify user (optional)
6. Example evaluations:
   - "Perfect Prayer Week" (AND, positive, 7 days): All 5 prayers must be on time for 7 consecutive days
   - "Any Prayer Missed" (OR, negative, 1 day): If any prayer is missed in a day, demerit is earned
```

### 6. Target Progress Tracking Flow
```
1. Trigger: After daily entry creation/update or scheduled daily check
2. For each active target for the user:
   - Check if current date is within target's start_date and end_date range
   - Get all target_items for this target
3. For each target_item:
   - Determine deed type (count-based or scale-based)
   - If count-based: Check progress toward target_items_count
   - If scale-based: Check if deed has required scale_id value
4. Calculate overall target progress:
   - Track progress for each target_item
   - Display progress percentage and remaining requirements
5. If target completed:
   - Mark target as completed
   - Notify user (optional)
6. Example targets:
   - "Pray 5 times daily for 30 days": 30-day target with 5 target_items (one per prayer)
   - "Read Quran daily": 7-day target with count requirement
```

### 7. Daily Reflection Messages Flow
```
1. User navigates to daily entry view for a date
2. System checks for existing daily_reflection_messages for that date
3. User can:
   - Add hasanaat_message (for all hasanaat deeds of the day)
   - Add saiyyiaat_message (for all saiyyiaat deeds of the day)
   - Update existing messages
4. Save to daily_reflection_messages table (one record per user per day)
```

### 8. Friend/Follow Access Flow
```
1. Friend/follower navigates to user's entries
2. System checks friend_relationships:
   - Status = 'accepted'
   - Relationship_type = 'friend' or 'follow'
3. System checks friend_deed_permissions:
   - For read: Check if friend/follower has read permission for the deed
   - For write: Check if friend/follower has write permission for the deed
   - Only one friend/follower can have write permission per deed
4. Query entries with user's user_id (deed owner)
5. For write operations:
   - Create new entry row with edited_by_user_id = friend/follower's user_id
   - Old entry remains intact (full history)
   - Owner can revert within 30 days
6. History tracking: All edits maintained in entries table via edited_by_user_id
```

---

## Database Strategies

### 1. **Database Selection**
**Recommended: PostgreSQL**
- **Rationale**:
  - Robust support for complex relationships and constraints
  - JSONB for flexible activity logging
  - Excellent indexing capabilities
  - ACID compliance for data integrity
  - Strong support for UUID primary keys
  - Mature replication and scaling options
  - Rich ecosystem for analytics queries

**Alternative Considerations**:
- **MySQL/MariaDB**: Good option but less flexible JSON support
- **MongoDB**: Not ideal due to relational nature of data (user-deed-entry relationships)
- **TimescaleDB** (PostgreSQL extension): Consider for time-series analytics if entry volume is extremely high

### 2. **Primary Key Strategy**
- **UUID (v4)**: Use universally unique identifiers
- **Benefits**:
  - Globally unique, no collisions across distributed systems
  - Security: Not sequential, harder to guess/enumerate
  - Suitable for multi-database or sharding scenarios
- **Trade-off**: Slightly larger storage and indexing overhead (acceptable for modern systems)

### 3. **Soft Delete Strategy**
- **Approach**: Use `is_active` flags instead of hard deletes
- **Rationale**:
  - Preserves historical data for analytics
  - Allows recovery of accidentally deleted entries
  - Maintains referential integrity for audit trails
- **Implementation**: All queries filter by `is_active = true` unless viewing deleted items

### 4. **Date/Time Handling**
- **Entry Dates**: Store as DATE type (timezone-agnostic)
- **Timestamps**: Store as TIMESTAMP WITH TIME ZONE
- **User Timezone**: Store in users table, convert during queries/display
- **Rationale**: Users may travel or reside in different timezones; dates should remain consistent

### 5. **Data Validation Strategy**
- **Application Layer**: Primary validation (UX, business logic)
- **Database Layer**: Constraints and triggers for data integrity
  - **Check Constraints**: 
    - Measure type consistency: `(measure_value IS NOT NULL AND count_value IS NULL) OR (count_value IS NOT NULL AND measure_value IS NULL)`
    - Self-reference prevention: `requester_user_id != receiver_user_id` in friend_relationships
  - **Foreign Key Constraints**: All foreign keys with appropriate CASCADE rules
  - **Unique Constraints**: 
    - `(user_id, deed_id, entry_date, edited_by_user_id)` on entries
    - `(user_id, reflection_date)` on daily_reflection_messages
    - `(requester_user_id, receiver_user_id, relationship_type)` on friend_relationships
  - **Triggers**:
    - Validate `measure_value` exists in `scale_definitions` for scale-based deeds
    - Validate child deeds inherit `measure_type` from parent
    - Enforce 30-day revert window for friend/follower edits
    - Auto-update `updated_at` timestamps

### 6. **Deed Management**
- **Strategy**: All deeds have `user_id NOT NULL` (owned by the creating user)
- **Structure**: Deed contains category_type and measure_type; deed_items contain the actual items/sub-deeds
- **Ownership**: Each deed is owned by the user who created it (`user_id = creating user's ID`)
- **Creation**: Users create their own deeds and deed items
- **Benefits**: 
  - Simple ownership model
  - Clear separation between deed definition and items
  - Level-based nesting via `level` field
  - Consistent queries across all deeds
  - Users have full control over their deeds

### 7. **Self-Referencing Deeds Structure**
- **Strategy**: Single `deeds` table with `parent_deed_id` for unlimited nesting
- **Benefits**:
  - Removed `sub_deeds` and `sub_entry_values` tables (2 tables eliminated)
  - Simpler schema, easier maintenance
  - Fully flexible for any number of sub-deeds
  - Less joins in queries
  - Unlimited nesting support
- **Implementation**:
  - `parent_deed_id = NULL` → main deed
  - `parent_deed_id ≠ NULL` → child deed (sub-deed)
  - Child deeds inherit `measure_type` from parent
  - Entries created directly for the deed being tracked (parent or child)

### 8. **Measure Type Consistency**
- **Enforcement**:
  - Database constraint: Check that entry matches deed.measure_type
  - Application logic: Validate before insert/update
  - Child deeds: Inherit from parent deed (no separate measure_type column)

### 9. **Hide Type Management**
- **Two Types**:
  - `hide_from_all`: Hidden from both input forms AND graphs (e.g., Ramadan Fasts when not in Ramadan)
  - `hide_from_graphs`: Visible in input forms but hidden in graphs only
- **Enforcement**:
  - Application logic: Filter deeds/sub-deeds based on hide_type when displaying input forms and graphs
  - Analytics queries: Exclude items with hide_type = 'hide_from_all' or 'hide_from_graphs' based on context
  - Dynamic updates: hide_type can be updated based on conditions (e.g., date-based logic for Ramadan Fasts)

### 10. **Scale Definitions Versioning**
- **Storage**: Versioning fields in `scale_definitions` table (`is_active`, `created_at`, `deactivated_at`, `version`)
- **Versioning Strategy**: Soft versioning with historical preservation
  - When scale values are updated, old values are marked `is_active = false` and `deactivated_at` is set
  - New scale values are created with `is_active = true` and incremented `version`
  - Historical entries preserve references to inactive scale values
- **Data Integrity**:
  - Unique constraint prevents duplicate active scale values per deed
  - Validation trigger ensures new entries only use active scales
  - Historical entries can reference inactive scales if they were active when entry was created
- **Query Performance**:
  - Index on `(deed_id, is_active)` for filtering active scales
  - Index on `(deed_id, scale_value)` for lookups
  - Partial unique index on active scales only
- **Usage**:
  - Application queries filter by `is_active = true` for input forms
  - Historical queries include inactive scales for data integrity
  - Analytics can aggregate across all versions or filter by active status
- **Benefits**:
  - Preserves historical data integrity
  - Allows scale evolution without breaking old entries
  - Maintains referential integrity for analytics
  - Supports audit trails of scale changes

### 11. **Daily Reflection Messages**
- **Storage**: Two TEXT fields in `daily_reflection_messages` table (hasanaat_message, saiyyiaat_message)
- **Constraint**: One record per user per day (unique constraint on user_id, reflection_date)
- **Usage**: One optional message for all hasanaat deeds of the day, one optional message for all saiyyiaat deeds of the day
- **Indexing**: Consider full-text search index if search functionality needed
- **Encoding**: UTF-8 to support multilingual content

### 12. **Merits/Demerits System**
- **Storage**: Separate tables for merits and merit_items (replaces JSONB-based approach)
- **Time-Based Evaluation**: Each merit has `merit_duration` (number of days) defining the evaluation window
- **Logical Rules**:
  - **AND**: All linked deeds must satisfy their rules (merit_type = 'AND')
  - **OR**: Any one linked deed satisfying its rule is enough (merit_type = 'OR')
- **Categories**:
  - **Positive**: Achievement-style rewards (merit_category = 'positive')
  - **Negative**: Demerit-style penalties (merit_category = 'negative')
- **Evaluation**:
  - Triggered after entry creation/update or scheduled daily check
  - Evaluates entries within the merit_duration window
  - Checks each merit_item condition (count or scale requirement)
  - Applies AND/OR logic based on merit_type
- **Examples**:
  - "Perfect Prayer Week" (AND, positive, 7 days): All 5 prayers on time for 7 consecutive days
  - "Any Prayer Missed" (OR, negative, 1 day): If any prayer is missed, demerit is earned

### 13. **Targets System**
- **Storage**: Separate tables for targets and target_items
- **User-Defined Goals**: Each target is created by a user with start_date and end_date
- **Time-Bounded**: Targets have explicit date ranges defining when they are active
- **Multi-Deed Support**: Targets can span multiple deeds via target_items
- **Progress Tracking**:
  - Track progress for each target_item (count or scale requirement)
  - Calculate overall target completion percentage
  - Display remaining requirements
- **Examples**:
  - "Pray 5 times daily for 30 days": 30-day target with 5 target_items
  - "Read Quran daily": 7-day target with count requirement

### 14. **Friend/Follow Relationships and Permissions**
- **Relationship Types**:
  - `friend`: Mutual friendship (requires acceptance)
  - `follow`: One-way following (approval optional)
- **Deed-Level Permissions**:
  - Stored in `friend_deed_permissions` table
  - **Read**: Multiple friends/followers can have read access per deed
  - **Write**: Only one friend/follower can have write access per deed (enforced at application level)
  - Fine-grained control per deed/sub-deed
  - Permissions are independent of relationship type (friend vs follow)
- **Edit Tracking**:
  - Friend/follower edits tracked via `edited_by_user_id` in entries table
  - Creates new entry row when friend/follower edits (old value remains)
  - Full history maintained in entries table (no separate activity_logs needed)
- **Revert Window**: 
  - Owner can revert friend/follower changes within 30 days
  - Enforced via application logic: `WHERE created_at >= CURRENT_TIMESTAMP - INTERVAL '30 days'`
  - Database trigger can prevent reverts after 30 days
- **Benefits**: Simple, flexible, scalable design with full edit history

---

## Database Constraints & Triggers

### Check Constraints

```sql
-- Entries: Measure type consistency
ALTER TABLE entries ADD CONSTRAINT check_measure_type 
  CHECK (
    (measure_value IS NOT NULL AND count_value IS NULL) OR
    (count_value IS NOT NULL AND measure_value IS NULL)
  );

-- Friend relationships: Prevent self-reference
ALTER TABLE friend_relationships ADD CONSTRAINT check_no_self_reference
  CHECK (requester_user_id != receiver_user_id);

-- Scale definitions: deactivated_at must be NULL when active, set when inactive
ALTER TABLE scale_definitions ADD CONSTRAINT check_scale_deactivation
  CHECK (
    (is_active = true AND deactivated_at IS NULL) OR
    (is_active = false AND deactivated_at IS NOT NULL)
  );

```

### Unique Constraints

```sql
-- Entries: One entry per user per deed per date per editor
ALTER TABLE entries ADD CONSTRAINT unique_entry_per_editor
  UNIQUE (user_id, deed_id, entry_date, edited_by_user_id);

-- Daily reflection messages: One per user per day
ALTER TABLE daily_reflection_messages ADD CONSTRAINT unique_reflection_per_day
  UNIQUE (user_id, reflection_date);

-- Friend relationships: One relationship per pair per type
ALTER TABLE friend_relationships ADD CONSTRAINT unique_relationship
  UNIQUE (requester_user_id, receiver_user_id, relationship_type);

-- Friend deed permissions: One write permission per deed
-- (Enforced at application level, but can add partial unique index)
CREATE UNIQUE INDEX idx_friend_deed_permissions_one_write
  ON friend_deed_permissions(deed_id, permission_type)
  WHERE permission_type = 'write' AND is_active = true;

-- Merit items: Only one condition type per item (count or scale, not both)
ALTER TABLE merit_items ADD CONSTRAINT check_merit_item_condition
  CHECK (
    (merit_items_count IS NOT NULL AND scale_id IS NULL) OR
    (merit_items_count IS NULL AND scale_id IS NOT NULL)
  );

-- Scale definitions: Prevent duplicate active scale values per deed
CREATE UNIQUE INDEX idx_scale_definitions_unique_active
  ON scale_definitions(deed_id, scale_value)
  WHERE is_active = true;

-- Target items: Only one condition type per item (count or scale, not both)
ALTER TABLE target_items ADD CONSTRAINT check_target_item_condition
  CHECK (
    (target_items_count IS NOT NULL AND scale_id IS NULL) OR
    (target_items_count IS NULL AND scale_id IS NOT NULL)
  );

-- Targets: End date must be after start date
ALTER TABLE targets ADD CONSTRAINT check_target_date_range
  CHECK (end_date >= start_date);

-- Targets: One target per user per title per start date
ALTER TABLE targets ADD CONSTRAINT unique_target_per_user
  UNIQUE (user_id, title, start_date);
```

### Database Triggers

```sql
-- Trigger: Validate measure_value exists in scale_definitions
-- Allows active scales for new entries, and historical inactive scales for existing entries
CREATE OR REPLACE FUNCTION validate_measure_value()
RETURNS TRIGGER AS $$
DECLARE
  scale_exists BOOLEAN;
  scale_was_active BOOLEAN;
BEGIN
  IF NEW.measure_value IS NOT NULL THEN
    -- Check if scale exists (active or inactive)
    SELECT EXISTS (
      SELECT 1 FROM scale_definitions sd
      JOIN deed_items di ON sd.deed_id = di.deed_id
      WHERE di.deed_item_id = NEW.deed_item_id
        AND sd.scale_value = NEW.measure_value
    ) INTO scale_exists;
    
    IF NOT scale_exists THEN
      RAISE EXCEPTION 'measure_value % does not exist in scale_definitions for deed_item %', 
        NEW.measure_value, NEW.deed_item_id;
    END IF;
    
    -- For new entries (INSERT), only allow active scales
    IF TG_OP = 'INSERT' THEN
      SELECT EXISTS (
        SELECT 1 FROM scale_definitions sd
        JOIN deed_items di ON sd.deed_id = di.deed_id
        WHERE di.deed_item_id = NEW.deed_item_id
          AND sd.scale_value = NEW.measure_value
          AND sd.is_active = true
      ) INTO scale_was_active;
      
      IF NOT scale_was_active THEN
        RAISE EXCEPTION 'measure_value % is not active for deed_item %. Only active scale values can be used for new entries.', 
          NEW.measure_value, NEW.deed_item_id;
      END IF;
    END IF;
    
    -- For updates, allow if:
    -- 1. Scale is currently active, OR
    -- 2. Scale was active when the original entry was created (preserve historical data)
    IF TG_OP = 'UPDATE' THEN
      SELECT EXISTS (
        SELECT 1 FROM scale_definitions sd
        JOIN deed_items di ON sd.deed_id = di.deed_id
        WHERE di.deed_item_id = NEW.deed_item_id
          AND sd.scale_value = NEW.measure_value
          AND (
            sd.is_active = true
            OR (
              sd.is_active = false
              AND sd.deactivated_at IS NOT NULL
              AND OLD.created_at <= sd.deactivated_at
            )
          )
      ) INTO scale_was_active;
      
      IF NOT scale_was_active THEN
        RAISE EXCEPTION 'measure_value % is not valid for deed_item %. Cannot update to an inactive scale that was not active when entry was created.', 
          NEW.measure_value, NEW.deed_item_id;
      END IF;
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_validate_measure_value
  BEFORE INSERT OR UPDATE ON entries
  FOR EACH ROW
  WHEN (NEW.measure_value IS NOT NULL)
  EXECUTE FUNCTION validate_measure_value();

-- Trigger: Automatically set deactivated_at when scale is deactivated
CREATE OR REPLACE FUNCTION set_scale_deactivated_at()
RETURNS TRIGGER AS $$
BEGIN
  -- When is_active changes from true to false, set deactivated_at
  IF OLD.is_active = true AND NEW.is_active = false THEN
    NEW.deactivated_at = CURRENT_TIMESTAMP;
  END IF;
  
  -- When is_active is set to true, ensure deactivated_at is NULL
  IF NEW.is_active = true THEN
    NEW.deactivated_at = NULL;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_set_scale_deactivated_at
  BEFORE UPDATE ON scale_definitions
  FOR EACH ROW
  WHEN (OLD.is_active IS DISTINCT FROM NEW.is_active)
  EXECUTE FUNCTION set_scale_deactivated_at();

-- Trigger: Validate deed items inherit measure_type from parent deed
CREATE OR REPLACE FUNCTION validate_deed_item_measure_type()
RETURNS TRIGGER AS $$
DECLARE
  parent_measure_type VARCHAR;
BEGIN
    SELECT measure_type INTO parent_measure_type
  FROM deed
  WHERE deed_id = NEW.deed_id;
  
  -- Deed items inherit measure_type from parent deed (enforced at application level)
  -- This trigger ensures consistency
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_validate_deed_item_measure_type
  BEFORE INSERT OR UPDATE ON deed_items
  FOR EACH ROW
  EXECUTE FUNCTION validate_deed_item_measure_type();

-- Trigger: Auto-update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = CURRENT_TIMESTAMP;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply to all tables with updated_at
CREATE TRIGGER trigger_update_deeds_updated_at
  BEFORE UPDATE ON deeds
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER trigger_update_entries_updated_at
  BEFORE UPDATE ON entries
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER trigger_update_friend_relationships_updated_at
  BEFORE UPDATE ON friend_relationships
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at();

-- Trigger: Enforce 30-day revert window for friend/follower edits
CREATE OR REPLACE FUNCTION check_revert_window()
RETURNS TRIGGER AS $$
BEGIN
  -- This trigger prevents reverts after 30 days
  -- Called when owner tries to delete friend/follower entry
  IF OLD.edited_by_user_id IS NOT NULL THEN
    IF OLD.created_at < CURRENT_TIMESTAMP - INTERVAL '30 days' THEN
      RAISE EXCEPTION 'Cannot revert entry after 30 days. Entry created at %', OLD.created_at;
    END IF;
  END IF;
  RETURN OLD;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_check_revert_window
  BEFORE DELETE ON entries
  FOR EACH ROW
  WHEN (OLD.edited_by_user_id IS NOT NULL)
  EXECUTE FUNCTION check_revert_window();

```

---

## Indexing Strategy

### Critical Indexes

#### **High-Frequency Query Indexes**
```sql
-- User authentication and lookup
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_username ON users(username);
CREATE INDEX idx_users_is_active ON users(is_active) WHERE is_active = true;

-- Entry queries (most frequent operations)
CREATE INDEX idx_entries_user_date ON entries(user_id, entry_date DESC);
CREATE INDEX idx_entries_deed_item_date ON entries(deed_item_id, entry_date DESC);
CREATE INDEX idx_entries_user_deed_item_date ON entries(user_id, deed_item_id, entry_date);
CREATE INDEX idx_entries_date_range ON entries(entry_date) WHERE entry_date >= CURRENT_DATE - INTERVAL '1 year';

-- Deed lookups
CREATE INDEX idx_deed_user_category ON deed(user_id, category_type);
CREATE INDEX idx_deed_items_deed ON deed_items(deed_id, is_active);
CREATE INDEX idx_deed_items_active ON deed_items(deed_id, is_active) WHERE is_active = true;

-- Deed items lookups
CREATE INDEX idx_deed_items_level ON deed_items(deed_id, level, is_active);
CREATE INDEX idx_deed_items_hide_type ON deed_items(hide_type, is_active);

-- Friend relationships
CREATE INDEX idx_friend_relationships_requester ON friend_relationships(requester_user_id, status);
CREATE INDEX idx_friend_relationships_receiver ON friend_relationships(receiver_user_id, status);
CREATE INDEX idx_friend_relationships_active ON friend_relationships(requester_user_id, receiver_user_id) WHERE status = 'accepted';

-- Friend deed permissions
CREATE INDEX idx_friend_deed_permissions_relationship ON friend_deed_permissions(relationship_id, is_active);
CREATE INDEX idx_friend_deed_permissions_deed ON friend_deed_permissions(deed_id, is_active);
CREATE INDEX idx_friend_deed_permissions_write ON friend_deed_permissions(deed_id, permission_type) WHERE permission_type = 'write';

-- Entry edit tracking (friend/follower edits)
CREATE INDEX idx_entries_edited_by ON entries(edited_by_user_id, entry_date DESC) WHERE edited_by_user_id IS NOT NULL;
CREATE INDEX idx_entries_user_date_edited ON entries(user_id, entry_date, edited_by_user_id);

-- Scale definitions (for validation and versioning)
CREATE INDEX idx_scale_definitions_deed ON scale_definitions(deed_id, is_active);
CREATE INDEX idx_scale_definitions_deed_value ON scale_definitions(deed_id, scale_value);
CREATE INDEX idx_scale_definitions_active ON scale_definitions(deed_id, is_active) WHERE is_active = true;
CREATE INDEX idx_scale_definitions_deactivated ON scale_definitions(deed_id, deactivated_at) WHERE is_active = false;

-- Daily reflection messages
CREATE INDEX idx_daily_reflection_user_date ON daily_reflection_messages(user_id, reflection_date DESC);
CREATE INDEX idx_daily_reflection_date ON daily_reflection_messages(reflection_date);
-- Full-text search index for reflection messages (if search functionality needed)
CREATE INDEX idx_daily_reflection_hasanaat_fts ON daily_reflection_messages USING gin(to_tsvector('english', hasanaat_message)) WHERE hasanaat_message IS NOT NULL;
CREATE INDEX idx_daily_reflection_saiyyiaat_fts ON daily_reflection_messages USING gin(to_tsvector('english', saiyyiaat_message)) WHERE saiyyiaat_message IS NOT NULL;

-- Merits and merit items
CREATE INDEX idx_merits_active ON merits(is_active) WHERE is_active = true;
CREATE INDEX idx_merits_category ON merits(merit_category, is_active) WHERE is_active = true;
CREATE INDEX idx_merit_items_merit ON merit_items(merit_id, deed_id);
CREATE INDEX idx_merit_items_deed ON merit_items(deed_id);
CREATE INDEX idx_merit_items_scale ON merit_items(scale_id) WHERE scale_id IS NOT NULL;

-- Targets and target items
CREATE INDEX idx_targets_user ON targets(user_id, is_active) WHERE is_active = true;
CREATE INDEX idx_targets_date_range ON targets(start_date, end_date) WHERE is_active = true;
CREATE INDEX idx_targets_user_date ON targets(user_id, start_date DESC, end_date DESC);
CREATE INDEX idx_target_items_target ON target_items(target_id, deed_id);
CREATE INDEX idx_target_items_deed ON target_items(deed_id);
CREATE INDEX idx_target_items_scale ON target_items(scale_id) WHERE scale_id IS NOT NULL;

-- Hide type filtering (for analytics)
CREATE INDEX idx_deeds_hide_type ON deeds(hide_type, is_active);
```

#### **Composite Indexes for Analytics**
```sql
-- Time-range analytics with category filtering
CREATE INDEX idx_entries_analytics ON entries(user_id, entry_date, deed_id) 
  INCLUDE (measure_value, count_value);

-- Monthly/yearly aggregations
CREATE INDEX idx_entries_date_trunc ON entries(user_id, DATE_TRUNC('month', entry_date), category);
```

#### **Partial Indexes (Conditional)**
```sql
-- Only index active records (saves space, improves performance)
CREATE INDEX idx_deeds_active ON deeds(user_id) WHERE is_active = true;
CREATE INDEX idx_deeds_parent_active ON deeds(parent_deed_id) WHERE is_active = true AND parent_deed_id IS NOT NULL;
```

### Index Maintenance
- **Monitoring**: Track index usage and query performance
- **Rebuilding**: Periodic REINDEX for high-write tables (entries)
- **Statistics**: Keep PostgreSQL statistics updated (AUTO_VACUUM enabled)

---

## Security Considerations

### 1. **Data Encryption**
- **At Rest**: Database-level encryption (PostgreSQL TDE or filesystem encryption)
- **In Transit**: TLS/SSL for all database connections
- **Sensitive Fields**: 
  - `password_hash`: Use bcrypt/argon2 (application-level)
  - Consider encrypting `reflection_message` if containing sensitive content

### 2. **Authentication & Authorization**
- **Password Storage**: Never store plaintext; use salted hashes (bcrypt minimum 10 rounds)
- **Token Management**: JWT or session-based (stored in application, not database)
- **Database Users**: Principle of least privilege
  - Application user: Read/write to application tables only
  - Read-only user: For analytics/reporting (separate connection pool)
  - No direct user access to database

### 3. **SQL Injection Prevention**
- **Parameterized Queries**: All queries use prepared statements
- **ORM/Query Builder**: Use parameterized ORM methods
- **Input Validation**: Validate at application layer before database

### 4. **Access Control**
- **Row-Level Security (PostgreSQL RLS)**:
  - Policy: Users can only access their own entries
  - Exception: Friends/followers with accepted relationships and deed-level permissions
- **Implementation**:
```sql
-- Example RLS policy (conceptual)
CREATE POLICY user_entries_policy ON entries
  FOR ALL
  TO application_user
  USING (
    user_id = current_user_id() 
    OR EXISTS (
      SELECT 1 FROM friend_relationships fr
      JOIN friend_deed_permissions fdp ON fr.relationship_id = fdp.relationship_id
      WHERE fdp.deed_id = entries.deed_id
        AND fdp.is_active = true
        AND fr.status = 'accepted'
        AND (
          (fr.requester_user_id = current_user_id() AND fr.receiver_user_id = entries.user_id)
          OR (fr.receiver_user_id = current_user_id() AND fr.requester_user_id = entries.user_id)
        )
    )
  );
```

### 5. **Data Privacy**
- **GDPR Compliance**: 
  - User data export capability
  - Right to deletion (soft delete, then hard delete after retention period)
- **PII Minimization**: Store only necessary personal information
- **Audit Trails**: Activity logs for compliance and security monitoring

### 6. **Backup Security**
- **Encrypted Backups**: All database backups encrypted
- **Access Control**: Backup storage with restricted access
- **Retention Policy**: Define retention periods per regulations

---

## Scalability & Performance

### 1. **Horizontal Scaling Strategies**

#### **Read Replicas**
- **Primary Database**: Handles all writes
- **Read Replicas**: Handle read queries (analytics, reporting, friend views)
- **Connection Routing**: Application routes read queries to replicas

#### **Sharding Strategy** (Future consideration)
- **Shard Key**: `user_id` (ensures user data stays on same shard)
- **Benefits**: Distributes load across multiple database instances
- **Challenges**: Cross-shard queries for friend relationships (consider separate relationship service)

#### **Partitioning** (PostgreSQL)
- **Table**: `entries` (highest write volume)
- **Strategy**: Range partitioning by `entry_date`
  - Partition by month or year
  - Example: `entries_2024_01`, `entries_2024_02`, etc.
- **Implementation**:
  ```sql
  -- Create partitioned table
  CREATE TABLE entries (
      entry_id UUID NOT NULL,
      user_id UUID NOT NULL,
      deed_id UUID NOT NULL,
      entry_date DATE NOT NULL,
      measure_value VARCHAR,
      count_value INTEGER,
      edited_by_user_id UUID,
      created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
      updated_at TIMESTAMP,
      PRIMARY KEY (entry_id, entry_date)
  ) PARTITION BY RANGE (entry_date);
  
  -- Create monthly partitions
  CREATE TABLE entries_2024_01 PARTITION OF entries
      FOR VALUES FROM ('2024-01-01') TO ('2024-02-01');
  CREATE TABLE entries_2024_02 PARTITION OF entries
      FOR VALUES FROM ('2024-02-01') TO ('2024-03-01');
  -- ... continue for each month
  
  -- Auto-create future partitions via scheduled job
  -- Archive old partitions (move to cold storage after 2+ years)
  ```
- **Partition Management**:
  - **Retention**: Keep active partitions for 2 years, archive older data
  - **Auto-creation**: Scheduled job creates next month's partition
  - **Maintenance**: Monthly partition pruning and archival
- **Benefits**: 
  - Faster queries on date ranges (partition pruning)
  - Easier archival of old data
  - Improved maintenance (drop old partitions)
  - Better index performance per partition

### 2. **Caching Strategy**

#### **Application-Level Caching**
- **Redis/Memcached**: 
  - User sessions
  - Frequently accessed deeds
  - Friend relationship cache
  - Recent entries (last 7 days per user)
- **Cache Invalidation**: 
  - TTL-based for static data
  - Event-based for dynamic data (new entries, friend updates)

#### **Database Query Caching**
- **Materialized Views**: For aggregated analytics
  - Monthly summaries per user
  - Hasanaat/Saiyyiaat balance per user
  - Refresh strategy: Incremental updates or scheduled refresh

### 3. **Query Optimization**

#### **Pagination**
- **Cursor-Based Pagination**: For entry lists (more efficient than OFFSET/LIMIT)
- **Implementation**: Use `entry_id` or `(entry_date, entry_id)` as cursor

#### **Aggregation Optimization**
- **Pre-computed Aggregates**: Store daily/monthly summaries
  - Table: `entry_summaries` (user_id, date, hasanaat_count, saiyyiaat_count, etc.)
  - Updated via triggers or background jobs
  - Speeds up analytics queries significantly

#### **Batch Operations**
- **Bulk Inserts**: For initial data migration or bulk imports
- **Batch Updates**: For friend relationship updates

### 4. **Connection Pooling**
- **PgBouncer or pgpool-II**: Manage database connections
- **Pool Size**: Based on expected concurrent users (start with 20-50 connections per instance)
- **Read/Write Separation**: Separate pools for primary and replicas

### 5. **Monitoring & Performance Metrics**
- **Key Metrics**:
  - Query response times (p50, p95, p99)
  - Database connection pool utilization
  - Slow query logs (queries > 100ms)
  - Index usage statistics
  - Cache hit rates
- **Tools**: 
  - PostgreSQL `pg_stat_statements` extension
  - Application Performance Monitoring (APM) tools
  - Database monitoring tools (pgAdmin, Datadog, etc.)

### 6. **Data Archival Strategy**
- **Archival Policy**: Entries older than X years (configurable)
- **Process**: 
  - Move to cold storage (separate archive database or object storage)
  - Maintain references in main database
  - Allow users to request archived data retrieval
- **Benefits**: Reduces active database size, improves query performance

---

## Migration & Backup Strategy

### 1. **Schema Migration**
- **Tool**: Use migration framework (e.g., Alembic, Flyway, or custom scripts)
- **Version Control**: All schema changes tracked in version control
- **Strategy**: 
  - Backward-compatible changes when possible
  - Zero-downtime migrations for large changes
  - Rollback plan for each migration

### 2. **Data Migration**
- **Initial Load**: 
  - Seed data for testing/development
- **User Data Import**: If users want to import historical data, provide import API with validation

### 3. **Backup Strategy**

#### **Backup Types**
- **Full Backups**: Daily (during low-traffic hours)
- **Incremental Backups**: Every 6 hours
- **WAL Archiving**: Continuous Write-Ahead Log archiving (Point-in-Time Recovery)

#### **Backup Retention**
- **Daily Backups**: 30 days
- **Weekly Backups**: 12 weeks
- **Monthly Backups**: 12 months
- **Yearly Backups**: 7 years (for compliance)

#### **Disaster Recovery**
- **RTO (Recovery Time Objective)**: < 4 hours
- **RPO (Recovery Point Objective)**: < 1 hour
- **Testing**: Quarterly DR drills

### 4. **Replication**
- **Primary-Secondary Setup**: 
  - Synchronous replication for critical data (users, entries)
  - Asynchronous replication for less critical data (activity logs)
- **Failover**: Automated failover mechanism with monitoring

---

## Additional Considerations

### 1. **Multi-tenancy** (If needed for organizations)
- **Strategy**: Add `organization_id` to users and entries tables
- **Isolation**: Row-level security policies per organization
- **Consideration**: May require separate schema or database per tenant for strict isolation

### 2. **Internationalization**
- **Character Encoding**: UTF-8 (Unicode) for all text fields
- **Date Formatting**: Application-level (database stores standard formats)
- **Locale Support**: Store user preferences in users table

### 3. **Analytics Database** (Optional for Advanced Analytics)
- **Consider**: Separate read-only database or data warehouse
- **ETL Process**: Extract entries data, transform for analytics, load into warehouse
- **Tools**: Consider PostgreSQL + TimescaleDB extension or separate analytics database (BigQuery, Redshift)

### 4. **Full-Text Search** (Future Enhancement)
- **Use Case**: Search reflection messages or deed names
- **Implementation**: PostgreSQL full-text search (tsvector/tsquery) or Elasticsearch integration

---

## Summary

This database architecture plan provides a robust, scalable foundation for Kitaab that:

✅ **Supports core functionality**: 
   - Daily logging with self-referencing deeds (unlimited nesting)
   - User-created deeds (all deeds have user_id)
   - Daily reflection messages (one Hasanaat, one Saiyyiaat per day)
   - Deeds with flexible measurement systems
   - Analytics with hide type filtering
   - Merits/Demerits system with time-based evaluations (AND/OR logic, positive/negative categories)
   - Targets system for user-defined, time-bounded goals
   - Social features: mutual friendship and one-way following with deed-level permissions

✅ **Ensures data integrity**: 
   - Constraints, relationships, validation rules
   - Self-referencing deeds structure (simplified schema)
   - Ownership model (all deeds have user_id, owned by creating user)
   - Hide type management for conditional visibility
   - Unique constraints for daily reflection messages
   - Full edit history in entries table (no separate activity_logs)

✅ **Optimizes performance**: 
   - Strategic indexing (simplified schema reduces joins)
   - Caching, partitioning
   - Hide type indexes for efficient filtering
   - Self-referencing structure reduces table complexity

✅ **Maintains security**: 
   - Encryption, access control, audit trails

✅ **Scales horizontally**: 
   - Read replicas, sharding considerations, connection pooling

✅ **Enables maintainability**: 
   - Clear schema, migration strategy, monitoring

The design balances flexibility (deeds, scales, merits/demerits with time-based evaluation, targets with multi-deed support, unlimited nesting) with structure (uniform ownership model, deed-level permissions, 30-day revert window) while maintaining performance and security standards required for a platform serving millions of users.

**Key Simplifications**:
- ✅ **Self-referencing deeds**: Unlimited nesting with `parent_deed_id`
- ✅ **Simple ownership**: All deeds have `user_id NOT NULL` (owned by creating user)
- ✅ **Deed-level permissions**: Multiple read, one write per deed
- ✅ **Full history**: Edit tracking in entries table (no separate activity_logs)
- ✅ **Friend/Follow model**: Supports both mutual friendship and one-way following

---

**Next Steps** (Implementation Phase):
1. Set up PostgreSQL database instance
2. Create initial schema with all tables and constraints (12 tables total)
3. Create database migration scripts
4. Set up indexing and connection pooling
5. Configure backup and replication
6. Implement security policies (RLS, encryption)
7. Set up monitoring and alerting

**Schema Summary**:
- **Total Tables**: 12
- **Core Tables**: `users`, `deed`, `deed_items`, `entries`, `scale_definitions`, `daily_reflection_messages`
- **Social Tables**: `friend_relationships`, `friend_deed_permissions`
- **Evaluation Tables**: `merits`, `merit_items`, `targets`, `target_items`
- **Key Features**: 
  - Self-referencing deeds structure (unlimited nesting via `parent_deed_id`)
  - Simple ownership model (all deeds have `user_id NOT NULL`, owned by creating user)
  - Time-based merit evaluation with AND/OR logic
  - User-defined targets with date ranges
  - Deed-level permissions for friends/followers

