# Database Tables Documentation

This directory contains detailed documentation for all 12 database tables in the Kitaab platform.

## Table List

### Core Tables

1. **[users.md](users.md)** - User accounts and profiles
   - Authentication credentials
   - Profile information
   - Account status and activity tracking

2. **[deeds.md](deeds.md)** - Deed definitions (default and custom)
   - System default deeds (Namaz, Lie)
   - User-created custom deeds
   - Self-referencing structure for hierarchical organization (parent_deed_id)
   - Category (Hasanaat/Saiyyiaat) and measurement type

3. **[scale_definitions.md](scale_definitions.md)** - Scale values for scale-based deeds
   - Predefined scale options (Yes/No, Excellent/Good, etc.)
   - Numeric values for analytics

### Entry Tables

4. **[entries.md](entries.md)** - Daily deed entries
   - User's daily deed logging
   - Scale-based or count-based values
   - Entries created directly for the deed being tracked (parent or child)
   - Friend/follower edit tracking

### Reflection & Social Tables

5. **[daily_reflection_messages.md](daily_reflection_messages.md)** - Daily reflection messages
   - One Hasanaat message per day
   - One Saiyyiaat message per day
   - Optional daily reflections

6. **[friend_relationships.md](friend_relationships.md)** - Friend and follow connections
   - Relationship types (friend vs follow)
   - Relationship status tracking
   - **Note**: Deed-level permissions managed in `friend_deed_permissions` table

7. **[friend_deed_permissions.md](friend_deed_permissions.md)** - Deed-level permissions for friends/followers
   - Read and write permissions per deed
   - Multiple read permissions, one write permission per deed

### Achievement & Demerit Tables

8. **[achievements.md](achievements.md)** - Achievement definitions
   - System-wide and custom achievements
   - Flexible JSONB condition configurations

9. **[user_achievements.md](user_achievements.md)** - User achievement earnings
   - When users earn achievements
   - Achievement history

10. **[demerits.md](demerits.md)** - Demerit definitions
    - System-wide and custom demerits
    - Flexible JSONB condition configurations

11. **[user_demerits.md](user_demerits.md)** - User demerit earnings
    - When users earn demerits
    - Demerit history

### Configuration Tables

12. **[user_default_deeds.md](user_default_deeds.md)** - User's default deeds
    - Tracks which default deeds user opted-in to
    - Optional during onboarding
    - Add/remove anytime

## Quick Reference

### Entry Rules
- **All deeds**: Create entries directly in `entries` table for the deed being tracked (parent or child)
- **No separate sub-entry table**: The self-referencing `deeds` structure eliminates the need for `sub_entry_values`

### Default Deeds
- All deeds have `user_id NOT NULL` (uniform ownership model)
- Default deeds are owned by `SYSTEM_USER_ID` (not NULL)
- Users can choose to accept or skip default deeds during onboarding
- Users can add/remove default deeds at any time
- Tracked in `user_default_deeds` table

### Hide Types
- `hide_from_all`: Hidden from input forms and graphs
- `hide_from_graphs`: Visible in input forms but hidden in graphs only
- `none`: Visible everywhere

### Achievements & Demerits
- System-wide: `user_id = NULL` (available to all users)
- Custom: `user_id` is set (user-specific)
- Conditions stored in JSONB `condition_config` field

### Schema Simplifications
- **Removed tables**: `sub_deeds`, `sub_entry_values`, `activity_logs`
- **Self-referencing deeds**: Uses `parent_deed_id` in `deeds` table for unlimited nesting
- **Full history**: Edit tracking in `entries` table via `edited_by_user_id` (no separate activity_logs)

## Documentation Structure

Each table documentation includes:
- **Overview**: Purpose and role of the table
- **Schema**: SQL table definition
- **Fields**: Detailed explanation of each field
- **Indexes**: Index definitions and purposes
- **Relationships**: Foreign key relationships
- **Constraints**: Primary keys, foreign keys, unique constraints
- **Important Rules**: Business rules and usage guidelines
- **Example Data**: Sample INSERT statements
- **Usage Notes**: Best practices and considerations
- **Query Examples**: Common query patterns

## Related Documentation

- Main database architecture: [../README.md](../README.md)
- Entity relationships: See Relationships Summary in main README
- Data flows: See Data Flow & Workflows in main README


