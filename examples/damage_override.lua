local enabled = ui.create("checkbox", "enabled", "Weapon damage override", false)
local damage = ui.create("slider", "damage", "Minimum damage", 60, 1, 130)
local profiles = settings.weapon_profiles()
local names = {}
for i, profile in ipairs(profiles) do names[i] = profile.name end
-- Combo values are zero-based; the catalog is a normal one-based Lua array.
local weapon = ui.create("combo", "weapon", "Weapon", 0, names)
local previous

events.on("pre_rage", function()
    local profile = profiles[ui.get(weapon) + 1]
    local category = ui.get(enabled) and profile and profile.rage_category or nil
    if previous and previous ~= category then
        settings.override(previous, "min damage", nil)
    end
    if category then
        settings.override(category, "min damage", math.floor(ui.get(damage)))
    end
    previous = category
end)
-- Overrides are also released automatically on Disable/error.
