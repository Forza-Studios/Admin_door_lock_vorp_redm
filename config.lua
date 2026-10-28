Config = {}

-- VORP groups allowed to use the door prompt
Config.AdminGroups = { admin = true, superadmin = true }

-- Optional: steam identifiers always allowed
Config.AllowedSteam = {
     ['steam:110000158767928'] = true,
}

Config.Distance = 2.0        -- prompt distance to a door
Config.PairDistance = 1.5    -- doors this close to the targeted one toggle together (double doors)
Config.PromptText = 'Open / Close Door'
Config.Sound = { name = 'SELECT', set = 'HUD_SHOP_SOUNDSET' }

-- ===== Persistence (table `admin_door_status` is auto-created on resource start) =====
Config.SaveToDatabase = true

-- true  = both opened and closed/locked states are restored after a restart (full persistence)
-- false = only opened doors are restored, closed rows are still saved but not re-applied
Config.RestoreClosedDoors = true
