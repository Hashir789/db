# Database Tables Documentation

This directory contains detailed documentation for all 14 database tables in the Kitaab platform.

## Table List

### Core Tables

1. **[users.md](users.md)** - User accounts and profiles
   - Authentication credentials
   - Profile information
   - Account status and activity tracking

2. **[deeds.md](deeds.md)** - Deed definitions (default and custom)
   - System default deeds (Namaz, Lie)
   - User-created custom deeds
   - Category (Hasanaat/Saiyyiaat) and measurement type

3. **[sub_deeds.md](sub_deeds.md)** - Sub-deeds under parent deeds
   - Hierarchical organization (e.g., Fajr, Zuhr under Namaz)
   - Display order and visibility control

4. **[scale_definitions.md](scale_definitions.md)** - Scale values for scale-based deeds
   - Predefined scale options (Yes/No, Excellent/Good, etc.)
   - Numeric values for analytics

### Entry Tables

5. **[entries.md](entries.md)** - Daily deed entries
   - User's daily deed logging
   - Scale-based or count-based values
   - Entry rules (deeds with/without sub-deeds)

6. **[sub_entry_values.md](sub_entry_values.md)** - Entry values for sub-deeds
   - Values for individual sub-deeds
   - Used when deed has sub-deeds

### Reflection & Social Tables

7. **[daily_reflection_messages.md](daily_reflection_messages.md)** - Daily reflection messages
   - One Hasanaat message per day
   - One Saiyyiaat message per day
   - Optional daily reflections

8. **[friend_relationships.md](friend_relationships.md)** - Friend/parent-child connections
   - Permission levels (read_only, write_only, read_write)
   - Relationship status tracking

9. **[activity_logs.md](activity_logs.md)** - Audit trail for entry modifications
   - Who made changes (owner or friend)
   - Before/after snapshots
   - Action types (created, updated, deleted)

### Achievement & Demerit Tables

10. **[achievements.md](achievements.md)** - Achievement definitions
    - System-wide and custom achievements
    - Flexible JSONB condition configurations

11. **[user_achievements.md](user_achievements.md)** - User achievement earnings
    - When users earn achievements
    - Achievement history

12. **[demerits.md](demerits.md)** - Demerit definitions
    - System-wide and custom demerits
    - Flexible JSONB condition configurations

13. **[user_demerits.md](user_demerits.md)** - User demerit earnings
    - When users earn demerits
    - Demerit history

### Configuration Tables

14. **[user_default_deeds.md](user_default_deeds.md)** - User's default deeds
    - Tracks which default deeds user opted-in to
    - Optional during onboarding
    - Add/remove anytime

## Quick Reference

### Entry Rules
- **Deed with sub-deeds**: Create entries only for sub-deeds (via `sub_entry_values`)
- **Deed without sub-deeds**: Create entries directly for the deed (via `entries`)

### Default Deeds
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

