-- Change this to a compiled model material mounted in the game's resources.
-- Paths are virtual: no drive letter, game/csgo prefix, URL or parent traversal.
local material_path = "materials/models/weapons/v_models/rif_ak47/ak47.vmat_c"
local material, load_error = chams.load_material(material_path)
if not material then
    error("Cannot load chams material: " .. tostring(load_error) .. " (" .. material_path .. ")")
end

local enabled = ui.create("checkbox", "path_chams_enabled", "Material from game path", false)
local target = ui.create("combo", "path_chams_target", "Material target", 1,
    {"Enemy", "Local player", "Hands", "Firstperson weapon", "Thirdperson attachments"})
local tint = ui.create("color", "path_chams_color", "Material tint", {255, 255, 255, 255})
local targets = {"enemy", "local", "arms", "weapon", "attachments"}
local current

local function release()
    if current then chams.set(current, nil); current = nil end
end

events.on("paint", function()
    if not ui.get(enabled) then release(); return end
    local selected = targets[ui.get(target)]
    if selected ~= current then release(); current = selected end
    chams.set(current, material, ui.get(tint))
end)
events.on("shutdown", release)
