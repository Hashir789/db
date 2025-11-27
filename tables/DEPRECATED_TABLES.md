# Deprecated Tables

The following table documentation files are **deprecated** and should not be used:

1. **sub_deeds.md** - This table has been removed. The functionality is now handled by the self-referencing `parent_deed_id` field in the `deeds` table.

2. **sub_entry_values.md** - This table has been removed. Entries are now created directly in the `entries` table for the deed being tracked (parent or child).

3. **activity_logs.md** - This table has been removed. Full edit history is now maintained in the `entries` table via the `edited_by_user_id` field.

## Migration Notes

- **Old structure**: Separate `sub_deeds` and `sub_entry_values` tables
- **New structure**: Self-referencing `deeds` table with `parent_deed_id` and direct entries in `entries` table
- **Benefits**: 
  - Reduced from 14 tables to 12 tables
  - Simpler schema with fewer joins
  - Unlimited nesting support
  - Full edit history in entries table

## Current Schema

See the main [README.md](../README.md) for the current database schema design.

