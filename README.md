# Admin_door_lock_vorp_redm

Admin-only door open/close prompt for RedM (VORP).

## Persistence

Door states are stored in the database so they survive server restarts.

The table is created automatically when the resource starts (no manual SQL import needed):

```sql
CREATE TABLE IF NOT EXISTS `admin_door_status` (
    `door_hash` BIGINT NOT NULL,
    `model_name` VARCHAR(64) DEFAULT NULL,
    `loc_x` DOUBLE NOT NULL DEFAULT 0,
    `loc_y` DOUBLE NOT NULL DEFAULT 0,
    `loc_z` DOUBLE NOT NULL DEFAULT 0,
    `status` TINYINT(1) NOT NULL DEFAULT 0 COMMENT '1 = open, 0 = closed/locked',
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`door_hash`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

- Every open/close action upserts the door hash, its model, its location and the new status.
- On resource start all saved states are loaded and re-applied to every player.
- Requires `oxmysql`. `door_hashes.lua` is now a `shared_script` so the server can resolve door coords.

Config options (`config.lua`):

| Option | Default | Description |
| --- | --- | --- |
| `Config.SaveToDatabase` | `true` | Persist door states in `admin_door_status` |
| `Config.RestoreClosedDoors` | `true` | Also restore closed/locked doors after a restart. Set to `false` if only opened doors should persist |
