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
- **Hierarchical structures**: Deeds with optional sub-deeds
- **Entry rules**: If deed has sub-deeds, entries can only be added to sub-deeds; if no sub-deeds, entries added directly to deed
- **Daily logging**: Chronological entries with daily reflection messages (one Hasanaat message, one Saiyyiaat message per day)
- **Time-range analytics**: Daily, weekly, monthly, yearly, and custom date ranges
- **Hide functionality**: Two types - hide from input forms and graphs, or hide from graphs only
- **Achievements and demerits**: Conditional tracking based on deed/sub-deed patterns
- **Social features**: Friend/parent-child relationships with permission-based access
- **Optional default deeds**: Users choose to accept default deeds (Namaz, Lie) during onboarding or skip them
- **High scalability**: Support for millions of users

---

## Core Workflow

### User Registration & Onboarding
1. User registers and completes profile setup
2. **Default Deed Selection**: User is presented with option to:
   - **Accept default deeds**: Namaz and Lie are added to their account
   - **Skip default deeds**: Start with custom deeds only
3. User can customize default deeds at any time (add/remove/modify)
4. System initializes user's first day entry structure

### Daily Deed Logging Workflow
1. **Entry Creation**: User selects date (default: today)
2. **Deed Selection**: Choose from Hasanaat or Saiyyiaat section
3. **Entry Constraint Check**:
   - **If deed has sub-deeds**: Only sub-deed entries are allowed (cannot add entry to parent deed)
   - **If deed has no sub-deeds**: Entry can be added directly to the deed
4. **Measurement Input**:
   - **Scale-based**: Select from predefined scale (e.g., Yes/No, Excellent/Good/Average)
   - **Count-based**: Enter numeric value
5. **Sub-deed Handling**: If deed has sub-deeds, system presents sub-deed inputs for each sub-deed
6. **Validation**: Ensure measure type consistency within deed group
7. **Daily Reflection Messages**: User can optionally add:
   - One Hasanaat reflection message (for all hasanaat deeds of the day)
   - One Saiyyiaat reflection message (for all saiyyiaat deeds of the day)
8. **Save**: Entry stored with timestamp and metadata

### Custom Deed Creation Workflow
1. User navigates to "Custom Deeds"
2. Selects category (Hasanaat or Saiyyiaat)
3. Defines deed name and description
4. Chooses measure type (Scale-based or Count-based)
5. **If Scale-based**: Defines custom scale values
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
1. **Friend Request**: User A sends friend request to User B
2. **Permission Assignment**: User B accepts and assigns permissions (read/write/both)
3. **Access**: User A can view/edit User B's entries based on permissions
4. **Activity Logging**: System tracks who made changes (owner vs. friend)

---

## Entity-Relationship Model

### Core Entities

#### 1. **Users**
- Primary entity representing platform users
- Stores authentication and profile information

#### 2. **Deeds**
- Represents both default system deeds and user-created custom deeds
- Categorized as Hasanaat or Saiyyiaat
- Contains measure type and scale definitions

#### 3. **Sub_Deeds**
- Optional child entities of Deeds
- Inherits measure type from parent deed
- Example: Fajr, Zuhr, Asr under Namaz

#### 4. **Entries**
- Daily logging records for deeds
- Links user, deed, and date
- Stores measurement values and reflection messages

#### 5. **Sub_Entry_Values**
- Stores values for sub-deeds within an entry
- Links to parent entry and specific sub-deed

#### 6. **Scale_Definitions**
- Defines custom scales for scale-based deeds
- Example: Excellent, Good, Average, Poor

#### 7. **Friend_Relationships**
- Manages parent-child/friend connections
- Stores permission levels (read/write/both)

#### 8. **Friend_Requests**
- Pending friend connection requests
- Tracks sender, receiver, and status

#### 9. **Activity_Logs**
- Audit trail for entry modifications
- Tracks who made changes (owner or friend)

#### 10. **Daily_Reflection_Messages**
- Stores optional daily reflection messages
- One Hasanaat message and one Saiyyiaat message per user per day

#### 11. **Achievements**
- Defines achievement conditions and rules
- Tracks user achievements based on deed/sub-deed patterns

#### 12. **Demerits**
- Defines demerit conditions and rules
- Tracks user demerits based on deed/sub-deed patterns

#### 13. **User_Default_Deeds**
- Junction table linking users to default deeds
- Tracks which default deeds user opted-in during onboarding
- Users can add/remove default deeds at any time

---

## Database Schema Design

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

#### **deeds**
```sql
- deed_id (UUID, Primary Key)
- user_id (UUID, Foreign Key → users.user_id, Nullable for default deeds)
- name (VARCHAR, Not Null)
- description (TEXT, Nullable)
- category (ENUM: 'hasanaat', 'saiyyiaat', Not Null, Indexed)
- measure_type (ENUM: 'scale_based', 'count_based', Not Null)
- is_default (BOOLEAN, Default: false, Indexed)
- is_active (BOOLEAN, Default: true)
- hide_type (ENUM: 'none', 'hide_from_all', 'hide_from_graphs', Default: 'none')
  -- 'hide_from_all': Hidden from input forms and graphs
  -- 'hide_from_graphs': Visible in input forms but hidden in graphs only
  -- 'none': Visible everywhere
- created_at (TIMESTAMP)
- updated_at (TIMESTAMP)
```

**Note**: If `user_id` is NULL and `is_default` is TRUE, the deed is a system default deed available to all users.

#### **sub_deeds**
```sql
- sub_deed_id (UUID, Primary Key)
- deed_id (UUID, Foreign Key → deeds.deed_id, ON DELETE CASCADE)
- name (VARCHAR, Not Null)
- display_order (INTEGER, Default: 0)
- is_active (BOOLEAN, Default: true)
- hide_type (ENUM: 'none', 'hide_from_all', 'hide_from_graphs', Default: 'none')
  -- 'hide_from_all': Hidden from input forms and graphs (e.g., Ramadan Fasts when not in Ramadan)
  -- 'hide_from_graphs': Visible in input forms but hidden in graphs only
  -- 'none': Visible everywhere
- created_at (TIMESTAMP)
```

**Constraint**: Sub-deeds inherit measure_type from parent deed.

#### **scale_definitions**
```sql
- scale_id (UUID, Primary Key)
- deed_id (UUID, Foreign Key → deeds.deed_id, ON DELETE CASCADE)
- scale_value (VARCHAR, Not Null)  -- e.g., "Yes", "No", "Excellent", "Good"
- numeric_value (INTEGER, Nullable)  -- For ordering/analytics (e.g., Yes=1, No=0)
- display_order (INTEGER, Not Null)
- is_active (BOOLEAN, Default: true)
```

**Usage**: For scale-based deeds. Stores possible scale values and their ordering.

#### **entries**
```sql
- entry_id (UUID, Primary Key)
- user_id (UUID, Foreign Key → users.user_id, ON DELETE CASCADE, Indexed)
- deed_id (UUID, Foreign Key → deeds.deed_id, ON DELETE CASCADE, Indexed)
- entry_date (DATE, Not Null, Indexed)
- measure_value (VARCHAR, Nullable)  -- For scale-based: stores scale_value
- count_value (INTEGER, Nullable)  -- For count-based: stores numeric count
- created_by_user_id (UUID, Foreign Key → users.user_id)  -- Tracks who created (owner or friend)
- created_at (TIMESTAMP, Indexed)
- updated_at (TIMESTAMP)
- updated_by_user_id (UUID, Foreign Key → users.user_id, Nullable)
```

**Constraints**:
- For scale-based deeds: `measure_value` must be NOT NULL, `count_value` must be NULL
- For count-based deeds: `count_value` must be NOT NULL, `measure_value` must be NULL
- One entry per user per deed per date (unique constraint on `user_id, deed_id, entry_date`)
- **Entry Rule**: If deed has sub-deeds, entries can ONLY be created for sub-deeds (via sub_entry_values), NOT for the parent deed. If deed has no sub-deeds, entries can be created directly for the deed.

#### **sub_entry_values**
```sql
- sub_entry_value_id (UUID, Primary Key)
- entry_id (UUID, Foreign Key → entries.entry_id, ON DELETE CASCADE, Indexed)
- sub_deed_id (UUID, Foreign Key → sub_deeds.sub_deed_id, ON DELETE CASCADE)
- measure_value (VARCHAR, Nullable)  -- For scale-based sub-deeds
- count_value (INTEGER, Nullable)  -- For count-based sub-deeds
- created_at (TIMESTAMP)
- updated_at (TIMESTAMP)
```

**Constraints**: Same as entries - either measure_value or count_value must be set based on parent deed's measure_type.

#### **friend_relationships**
```sql
- relationship_id (UUID, Primary Key)
- requester_user_id (UUID, Foreign Key → users.user_id, ON DELETE CASCADE, Indexed)
- receiver_user_id (UUID, Foreign Key → users.user_id, ON DELETE CASCADE, Indexed)
- permission_type (ENUM: 'read_only', 'write_only', 'read_write', Not Null)
- status (ENUM: 'pending', 'accepted', 'rejected', 'blocked', Default: 'pending', Indexed)
- accepted_at (TIMESTAMP, Nullable)
- created_at (TIMESTAMP, Indexed)
- updated_at (TIMESTAMP)
```

**Constraints**: 
- Unique constraint on `(requester_user_id, receiver_user_id)`
- Check constraint: `requester_user_id != receiver_user_id`

#### **activity_logs**
```sql
- log_id (UUID, Primary Key)
- entry_id (UUID, Foreign Key → entries.entry_id, ON DELETE CASCADE, Indexed)
- user_id (UUID, Foreign Key → users.user_id)  -- Who made the change
- action_type (ENUM: 'created', 'updated', 'deleted', Not Null)
- old_values (JSONB, Nullable)  -- Snapshot before change
- new_values (JSONB, Nullable)  -- Snapshot after change
- created_at (TIMESTAMP, Indexed)
```

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

#### **achievements**
```sql
- achievement_id (UUID, Primary Key)
- user_id (UUID, Foreign Key → users.user_id, ON DELETE CASCADE, Nullable)
  -- NULL for system-wide achievements, user_id for custom achievements
- name (VARCHAR, Not Null)
- description (TEXT, Nullable)
- condition_type (ENUM: 'all_sub_deeds', 'specific_sub_deeds', 'custom', Not Null)
- condition_config (JSONB, Not Null)
  -- Stores condition rules (e.g., {"deed_id": "...", "sub_deed_ids": [...], "scale_value": "prayed_in_mosque"})
- is_active (BOOLEAN, Default: true)
- created_at (TIMESTAMP)
- updated_at (TIMESTAMP)
```

**Usage**: Defines achievement conditions. Example: "All prayers in mosque" = condition_type='all_sub_deeds', condition_config={"deed_id": "namaz_deed_id", "scale_value": "prayed_in_mosque"}

#### **user_achievements**
```sql
- user_achievement_id (UUID, Primary Key)
- user_id (UUID, Foreign Key → users.user_id, ON DELETE CASCADE, Indexed)
- achievement_id (UUID, Foreign Key → achievements.achievement_id, ON DELETE CASCADE)
- achieved_date (DATE, Not Null, Indexed)
- created_at (TIMESTAMP)
```

**Constraints**:
- Unique constraint on `(user_id, achievement_id, achieved_date)` - one achievement per user per achievement per day

#### **demerits**
```sql
- demerit_id (UUID, Primary Key)
- user_id (UUID, Foreign Key → users.user_id, ON DELETE CASCADE, Nullable)
  -- NULL for system-wide demerits, user_id for custom demerits
- name (VARCHAR, Not Null)
- description (TEXT, Nullable)
- condition_type (ENUM: 'all_sub_deeds', 'specific_sub_deeds', 'custom', Not Null)
- condition_config (JSONB, Not Null)
  -- Stores condition rules (e.g., {"deed_id": "...", "sub_deed_ids": [...], "scale_values": ["late_prayed", "not_prayed"]})
- is_active (BOOLEAN, Default: true)
- created_at (TIMESTAMP)
- updated_at (TIMESTAMP)
```

**Usage**: Defines demerit conditions. Example: "All prayers late/not prayed" = condition_type='all_sub_deeds', condition_config={"deed_id": "namaz_deed_id", "scale_values": ["late_prayed", "not_prayed"]}

#### **user_demerits**
```sql
- user_demerit_id (UUID, Primary Key)
- user_id (UUID, Foreign Key → users.user_id, ON DELETE CASCADE, Indexed)
- demerit_id (UUID, Foreign Key → demerits.demerit_id, ON DELETE CASCADE)
- demerit_date (DATE, Not Null, Indexed)
- created_at (TIMESTAMP)
```

**Constraints**:
- Unique constraint on `(user_id, demerit_id, demerit_date)` - one demerit per user per demerit per day

#### **user_default_deeds**
```sql
- user_default_deed_id (UUID, Primary Key)
- user_id (UUID, Foreign Key → users.user_id, ON DELETE CASCADE, Indexed)
- default_deed_id (UUID, Foreign Key → deeds.deed_id, ON DELETE CASCADE)
- is_active (BOOLEAN, Default: true)
- assigned_at (TIMESTAMP, Default: CURRENT_TIMESTAMP)
```

**Purpose**: Tracks which default deeds user opted-in during onboarding. Users can add/remove default deeds at any time. Useful for analytics and customization per user.

### Relationships Summary

```
users (1) ────< (M) deeds (user-created deeds)
users (1) ────< (M) entries
users (1) ────< (M) user_default_deeds
users (1) ────< (M) friend_relationships (as requester)
users (1) ────< (M) friend_relationships (as receiver)
users (1) ────< (M) daily_reflection_messages
users (1) ────< (M) achievements (custom achievements)
users (1) ────< (M) demerits (custom demerits)
users (1) ────< (M) user_achievements
users (1) ────< (M) user_demerits

deeds (1) ────< (M) sub_deeds
deeds (1) ────< (M) scale_definitions
deeds (1) ────< (M) entries
deeds (1) ────< (M) user_default_deeds (default deeds)

entries (1) ────< (M) sub_entry_values
entries (1) ────< (M) activity_logs

sub_deeds (1) ────< (M) sub_entry_values

achievements (1) ────< (M) user_achievements
demerits (1) ────< (M) user_demerits
```

---

## Data Flow & Workflows

### 1. User Registration Flow
```
1. User submits registration → Create user record
2. User completes profile setup
3. **Onboarding - Default Deed Selection**:
   - System presents option to accept default deeds (Namaz, Lie)
   - If user accepts:
     * Query default deeds (WHERE is_default = true AND name IN ('Namaz', 'Lie'))
     * For each selected default deed:
       - Create user_default_deeds record with is_active = true
       - If deed has sub-deeds, sub-deeds automatically available
   - If user skips:
     * No default deeds added (user can add them later)
4. User can customize default deeds at any time (add/remove via user_default_deeds)
```

### 2. Daily Entry Creation Flow
```
1. User selects date and deed
2. System validates:
   - Deed exists and is accessible to user (default via user_default_deeds or owned)
   - Deed is not hidden from input (hide_type != 'hide_from_all')
   - Entry doesn't already exist for date+deed (unless updating)
3. **Entry Constraint Validation**:
   - Check if deed has sub-deeds:
     * If YES: Only allow entry creation for sub-deeds (via sub_entry_values)
     * If NO: Allow entry creation directly for the deed
4. If scale-based:
   - User selects from scale_definitions for that deed/sub-deed
   - Store value in entries.measure_value or sub_entry_values.measure_value
5. If count-based:
   - User enters numeric value
   - Store value in entries.count_value or sub_entry_values.count_value
6. If deed has sub-deeds:
   - User provides values for each sub-deed (not for parent deed)
   - Create sub_entry_values records linked to entry
   - Validate measure_type consistency
7. Create entry record (or update existing)
8. **Daily Reflection Messages** (optional):
   - User can add/update daily_reflection_messages for the date
   - One hasanaat_message and/or one saiyyiaat_message per day
9. Create activity_log record (action: 'created' or 'updated')
10. **Achievement/Demerit Check** (background process):
    - Evaluate achievement conditions based on entries of the day
    - Evaluate demerit conditions based on entries of the day
    - Create user_achievements or user_demerits records if conditions met
```

### 3. Custom Deed Creation Flow
```
1. User provides deed details (name, category, measure_type)
2. If scale-based:
   - User defines scale values
   - Create scale_definitions records
3. If count-based:
   - No scale_definitions needed
4. Optionally create sub_deeds (with same measure_type)
5. Create deed record with user_id
6. Deed now available for logging
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
   - Aggregate by deed_id, sub_deed_id
3. Calculate metrics:
   - Total entries per deed (respecting hide_type rules)
   - Average/trend for scale-based (using numeric_value from scale_definitions)
   - Sum/total for count-based
   - Hasanaat vs Saiyyiaat balance
   - Trend analysis (improvement/decline)
   - Include user_achievements and user_demerits for the time range
4. Return aggregated data for visualization
```

### 5. Achievement/Demerit Evaluation Flow
```
1. Trigger: After daily entry creation/update or scheduled daily check
2. For each active achievement/demerit (user-specific or system-wide):
   - Read condition_config JSONB
   - Query relevant entries for the date
   - Evaluate condition:
     * 'all_sub_deeds': Check if all sub-deeds of deed meet condition
     * 'specific_sub_deeds': Check if specified sub-deeds meet condition
     * 'custom': Execute custom logic (application-level)
3. If condition met:
   - Create user_achievements or user_demerits record
   - Notify user (optional)
4. Example evaluations:
   - "All prayers in mosque": Check if all Namaz sub-deeds have scale_value = 'prayed_in_mosque'
   - "All prayers except Fajr in mosque": Check if Zuhr, Asr, Maghrib, Isha have scale_value = 'prayed_in_mosque'
   - "All prayers late/not prayed": Check if all Namaz sub-deeds have scale_value IN ('late_prayed', 'not_prayed')
```

### 6. Daily Reflection Messages Flow
```
1. User navigates to daily entry view for a date
2. System checks for existing daily_reflection_messages for that date
3. User can:
   - Add hasanaat_message (for all hasanaat deeds of the day)
   - Add saiyyiaat_message (for all saiyyiaat deeds of the day)
   - Update existing messages
4. Save to daily_reflection_messages table (one record per user per day)
```

### 7. Friend Access Flow
```
1. Friend navigates to friend's entries
2. System checks friend_relationships:
   - Status = 'accepted'
   - Permission_type allows requested operation
3. Query entries with friend's user_id
4. For write operations:
   - Create/update entry with created_by_user_id = friend's user_id
   - Log activity with friend's user_id
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
  - Check constraints for measure_type consistency
  - Foreign key constraints with CASCADE rules
  - Unique constraints on (user_id, deed_id, entry_date)
  - Trigger to validate measure_value exists in scale_definitions

### 6. **Default Deeds Management**
- **Strategy**: System-level deeds with `user_id = NULL` and `is_default = true`
- **Assignment**: Optional during onboarding via `user_default_deeds` junction table (user chooses to accept or skip)
- **Customization**: Users can add/remove default deeds at any time via `user_default_deeds` table
- **Updates**: System-level updates to default deeds can propagate or remain versioned

### 7. **Measure Type Consistency**
- **Enforcement**:
  - Database constraint: Check that entry matches deed.measure_type
  - Application logic: Validate before insert/update
  - Sub-deeds: Inherit from parent deed (no separate measure_type column)

### 8. **Entry Constraint for Sub-Deeds**
- **Rule**: If a deed has sub-deeds, entries can ONLY be created for sub-deeds (via sub_entry_values), NOT for the parent deed
- **Enforcement**:
  - Application logic: Check if deed has sub-deeds before allowing entry creation
  - Database trigger: Prevent entry creation for deeds with sub-deeds (enforce at database level as backup)
  - Example: Namaz has sub-deeds (Fajr, Zuhr, etc.) → entries only for sub-deeds, not Namaz directly
  - Example: Lie has no sub-deeds → entries can be created directly for Lie

### 9. **Hide Type Management**
- **Two Types**:
  - `hide_from_all`: Hidden from both input forms AND graphs (e.g., Ramadan Fasts when not in Ramadan)
  - `hide_from_graphs`: Visible in input forms but hidden in graphs only
- **Enforcement**:
  - Application logic: Filter deeds/sub-deeds based on hide_type when displaying input forms and graphs
  - Analytics queries: Exclude items with hide_type = 'hide_from_all' or 'hide_from_graphs' based on context
  - Dynamic updates: hide_type can be updated based on conditions (e.g., date-based logic for Ramadan Fasts)

### 10. **Daily Reflection Messages**
- **Storage**: Two TEXT fields in `daily_reflection_messages` table (hasanaat_message, saiyyiaat_message)
- **Constraint**: One record per user per day (unique constraint on user_id, reflection_date)
- **Usage**: One optional message for all hasanaat deeds of the day, one optional message for all saiyyiaat deeds of the day
- **Indexing**: Consider full-text search index if search functionality needed
- **Encoding**: UTF-8 to support multilingual content

### 11. **Achievements and Demerits**
- **Storage**: JSONB field (condition_config) for flexible condition rules
- **Types**:
  - System-wide: user_id = NULL (available to all users)
  - Custom: user_id set (user-specific achievements/demerits)
- **Evaluation**:
  - Triggered after entry creation/update or scheduled daily check
  - Application-level logic evaluates condition_config JSONB
  - Creates user_achievements or user_demerits records when conditions met
- **Examples**:
  - All prayers in mosque (all_sub_deeds condition)
  - All prayers except Fajr in mosque (specific_sub_deeds condition)
  - All prayers late/not prayed (all_sub_deeds with multiple scale_values)

### 12. **Friend Permissions**
- **Granularity**: Three levels (read_only, write_only, read_write)
- **Enforcement**: Application-level authorization checks
- **Audit**: Track all friend actions via activity_logs

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
CREATE INDEX idx_entries_deed_date ON entries(deed_id, entry_date DESC);
CREATE INDEX idx_entries_user_deed_date ON entries(user_id, deed_id, entry_date);
CREATE INDEX idx_entries_date_range ON entries(entry_date) WHERE entry_date >= CURRENT_DATE - INTERVAL '1 year';

-- Deed lookups
CREATE INDEX idx_deeds_user_category ON deeds(user_id, category, is_active);
CREATE INDEX idx_deeds_default ON deeds(is_default) WHERE is_default = true;
CREATE INDEX idx_deeds_user_active ON deeds(user_id, is_active) WHERE is_active = true;

-- Sub-entry queries
CREATE INDEX idx_sub_entry_values_entry ON sub_entry_values(entry_id);
CREATE INDEX idx_sub_entry_values_sub_deed ON sub_entry_values(sub_deed_id);

-- Friend relationships
CREATE INDEX idx_friend_relationships_requester ON friend_relationships(requester_user_id, status);
CREATE INDEX idx_friend_relationships_receiver ON friend_relationships(receiver_user_id, status);
CREATE INDEX idx_friend_relationships_active ON friend_relationships(requester_user_id, receiver_user_id) WHERE status = 'accepted';

-- Activity logs (for audit queries)
CREATE INDEX idx_activity_logs_entry ON activity_logs(entry_id, created_at DESC);
CREATE INDEX idx_activity_logs_user_date ON activity_logs(user_id, created_at DESC);

-- Scale definitions (for validation)
CREATE INDEX idx_scale_definitions_deed ON scale_definitions(deed_id, is_active);

-- Daily reflection messages
CREATE INDEX idx_daily_reflection_user_date ON daily_reflection_messages(user_id, reflection_date DESC);
CREATE INDEX idx_daily_reflection_date ON daily_reflection_messages(reflection_date);

-- Achievements and demerits
CREATE INDEX idx_achievements_user ON achievements(user_id, is_active) WHERE user_id IS NOT NULL;
CREATE INDEX idx_achievements_system ON achievements(is_active) WHERE user_id IS NULL;
CREATE INDEX idx_demerits_user ON demerits(user_id, is_active) WHERE user_id IS NOT NULL;
CREATE INDEX idx_demerits_system ON demerits(is_active) WHERE user_id IS NULL;

-- User achievements and demerits
CREATE INDEX idx_user_achievements_user_date ON user_achievements(user_id, achieved_date DESC);
CREATE INDEX idx_user_achievements_achievement ON user_achievements(achievement_id, achieved_date DESC);
CREATE INDEX idx_user_demerits_user_date ON user_demerits(user_id, demerit_date DESC);
CREATE INDEX idx_user_demerits_demerit ON user_demerits(demerit_id, demerit_date DESC);

-- Hide type filtering (for analytics)
CREATE INDEX idx_deeds_hide_type ON deeds(hide_type, is_active);
CREATE INDEX idx_sub_deeds_hide_type ON sub_deeds(hide_type, is_active);
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
CREATE INDEX idx_entries_active ON entries(user_id, entry_date) WHERE is_active = true;
CREATE INDEX idx_deeds_active ON deeds(user_id) WHERE is_active = true;
```

### Index Maintenance
- **Monitoring**: Track index usage and query performance
- **Rebuilding**: Periodic REINDEX for high-write tables (entries, activity_logs)
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
  - Exception: Friends with accepted relationships and appropriate permissions
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
      WHERE (fr.requester_user_id = current_user_id() 
             AND fr.receiver_user_id = entries.user_id
             AND fr.status = 'accepted')
      OR (fr.receiver_user_id = current_user_id() 
          AND fr.requester_user_id = entries.user_id
          AND fr.status = 'accepted')
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
- **Benefits**: 
  - Faster queries on date ranges
  - Easier archival of old data
  - Improved maintenance (drop old partitions)

### 2. **Caching Strategy**

#### **Application-Level Caching**
- **Redis/Memcached**: 
  - User sessions
  - Frequently accessed deeds (default deeds, user's custom deeds)
  - Friend relationship cache
  - Recent entries (last 7 days per user)
- **Cache Invalidation**: 
  - TTL-based for static data (default deeds)
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
  - Bulk import scripts for default deeds
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
   - Daily logging with entry rules (sub-deed constraints)
   - Optional default deeds onboarding (user choice)
   - Daily reflection messages (one Hasanaat, one Saiyyiaat per day)
   - Custom deeds with flexible measurement systems
   - Analytics with hide type filtering
   - Achievements and demerits with conditional evaluation
   - Social features with permission-based access

✅ **Ensures data integrity**: 
   - Constraints, relationships, validation rules
   - Entry constraint validation (deeds with sub-deeds vs. without)
   - Hide type management for conditional visibility
   - Unique constraints for daily reflection messages

✅ **Optimizes performance**: 
   - Strategic indexing (including new tables: achievements, demerits, reflection messages)
   - Caching, partitioning
   - Hide type indexes for efficient filtering

✅ **Maintains security**: 
   - Encryption, access control, audit trails

✅ **Scales horizontally**: 
   - Read replicas, sharding considerations, connection pooling

✅ **Enables maintainability**: 
   - Clear schema, migration strategy, monitoring

The design balances flexibility (custom deeds, scales, achievements/demerits) with structure (optional default deeds, entry rules, hide types) while maintaining performance and security standards required for a platform serving millions of users.

---

**Next Steps** (Implementation Phase):
1. Set up PostgreSQL database instance
2. Create initial schema with all tables and constraints
3. Implement default deeds seeding
4. Create database migration scripts
5. Set up indexing and connection pooling
6. Configure backup and replication
7. Implement security policies (RLS, encryption)
8. Set up monitoring and alerting

