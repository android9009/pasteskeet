---@meta
-- IDE declarations only. Do not run this file as a game script.
-- Native FFI declarations are in ffi.lua; developer guide: FFI.ru.md.

---@class Vector3
---@field x number
---@field y number
---@field z number

---@alias Color integer[] RGBA, exactly four channels in 0..255.
---@alias EventName 'paint'|'create_move'|'pre_rage'|'post_rage'|'pre_legit'|'post_legit'|'post_move'|'finalize_command'|'frame_stage'|'game_event'|'shutdown'|'rage_targets'|'rage_scan'|'rage_select'|'rage_fire'|'rage_shot'

---@class PlayerSnapshot
---@field id integer Controller index; 0 aliases local player.
---@field name string
---@field health integer
---@field alive boolean
---@field team integer
---@field enemy boolean
---@field origin Vector3
---@field velocity Vector3
---@field flags integer
---@field armor integer
---@field scoped boolean Local/client-known zoom state; false when unavailable.

---@class SettingDescriptor
---@field category string
---@field name string
---@field type string
---@field count integer
---@field writable boolean

---@class CommandSnapshot
---@field number integer
---@field tick integer
---@field buttons integer
---@field buttons_changed integer
---@field buttons_scroll integer
---@field history_count integer
---@field forward number
---@field side number
---@field up number
---@field angles Vector3

---@class GameEvent
---@field name string
---@field userid integer? Controller index; 0 is the local player, nil if absent/unresolved.
---@field attacker integer? Controller index; 0 is the local player, nil if absent/unresolved.
---@field position Vector3? Present for bullet_impact only.
---@field dmg_health integer? player_hurt: health damage reported by the event.
---@field damage integer? Alias of dmg_health.
---@field dmg_armor integer? player_hurt: armor damage reported by the event.
---@field health integer? player_hurt: remaining health.
---@field armor integer? player_hurt: remaining armor.
---@field hitgroup integer? player_hurt: native hitgroup, not a bone/hitbox index.
---@field weapon string? player_hurt: event weapon name, copied before the event expires.

---@class RageShotEvent
---@field id integer Unique within the current DLL session.
---@field status 'command'|'fired'|'hit'|'miss'|'unconfirmed'
---@field command_number integer
---@field command_tick integer
---@field target_id integer Intended controller index.
---@field record_tick integer
---@field hitbox integer Actual scanned hitbox index.
---@field requested_hitbox integer
---@field expected_damage number
---@field hitchance number Percentage 0..100.
---@field forced boolean
---@field no_spread boolean
---@field victim_id integer? On hit; equals the intended target in this API version.
---@field reason string? On miss/unconfirmed, e.g. no_hurt_event/no_weapon_fire/session_reset/overflow.

---@class LuaBudget
---@field instructions_remaining integer Effective current scope; approximate in steps of 1000.
---@field time_remaining_ms number Effective current scope; wall time, minimum 0.
---@field native_work_remaining integer Host API/conversion work; direct FFI calls are not API-counted.
---@field dispatch_instructions_remaining integer Shared dispatch remainder.
---@field dispatch_time_remaining_ms number Shared dispatch remainder.
---@field protect_depth integer Current nested protect depth.
---@field recovering boolean Dispatch exhausted; finish this callback now.
---@field retryable boolean Parent has not exhausted its budget; does not promise a task will fit.
---@class LuaBudgetError
---@field kind 'instructions'|'time'|'native_work'
---@field scope 'protect'|'dispatch'
---@field retryable boolean False when dispatch is exhausted.
api = { version = 2, lua = 'Lua 5.5', script = '', error_codes = { budget_exceeded = 'budget_exceeded' } }
---Catch ordinary errors and budget exhaustion. Allocation failures remain fatal.
---No rollback of settings, draws, UI or other side effects. fn receives no arguments; use a closure.
---@param fn fun(): ...
---@param limits? {instructions?: integer, time_ms?: number} Defaults 1000000 / 25 ms; maxima 20000000 / 250 ms; parent limits apply.
---@return boolean ok
---@return string? error Exact 'budget_exceeded' for budget failure; ordinary errors have a traceback; nil on success.
---@return ... results All fn results including nils on success; LuaBudgetError as third result on budget failure.
function api.protect(fn, limits) end
---Budget snapshot; querying it consumes a host API call. Finish callback when recovering=true.
---@return LuaBudget budget
function api.budget() end
buttons = { attack=1, jump=2, duck=4, forward=8, back=16, use=32,
    moveleft=512, moveright=1024, attack2=2048, reload=8192, speed=65536,
    zoom=17179869184, score=8589934592, inspect=34359738368 }

events = {}
---@param name EventName
---@param callback fun(event: table): table?
---@overload fun(name: 'rage_scan', callback: fun(context: RageScan): {points: RagePoint[]}?): integer
---@overload fun(name: 'rage_select', callback: fun(context: RageSelection): {index: integer}?): integer
---@overload fun(name: 'game_event', callback: fun(event: GameEvent)): integer
---@overload fun(name: 'rage_shot', callback: fun(event: RageShotEvent)): integer
---@return integer subscription
function events.on(name, callback) end
---@param id integer
---@return boolean removed
function events.off(id) end

settings = {}
---@param category_filter? string
---@return SettingDescriptor[]
function settings.list(category_filter) end
---@param category string
---@param name string
---@return any value
function settings.get(category, name) end
---@param category string
---@param name string
---@param value any
function settings.set(category, name, value) end
---@param category string
---@param name string
---@param value any Pass nil to release this script's override.
function settings.override(category, name, value) end
---@param category string
---@param name string
---@param key? integer Windows virtual key, 0..255.
---@param mode? integer 0 toggle, 1 hold_on, 2 hold_off.
---@return {key: integer, mode: integer, active: boolean}
function settings.bind(category, name, key, mode) end
---@class BindSnapshot
---@field category string
---@field name string
---@field key integer Windows virtual key.
---@field mode integer 0 toggle, 1 hold_on, 2 hold_off.
---@field active boolean Whether the bind is active.
---@field value boolean Current setting value.
---@return BindSnapshot[] Native bound settings plus active scripts' Lua checkbox binds; includes inactive binds.
function settings.binds() end

client = {}
---@param ... any
function client.log(...) end
---@param level 'debug'|'info'|'warning'|'error'
---@param ... any
function client.log_level(level, ...) end
---@class ExecutionStats
---@field phase string
---@field instructions integer Approximate; sampled every 1000 Lua instructions.
---@field api_calls integer Native API entries, including this stats call.
---@field native_work integer API entries plus table conversion work.
---@field time_ms number Elapsed execution time excluding credited audio waits; not CPU/GPU time.
---@field memory_bytes integer Lua allocator usage; excludes graphics caches and native allocations.
---@class ScriptStats: ExecutionStats
---@field invocations integer Completed load/event dispatches since enabling this instance (all handlers together).
---@field protected_errors integer Ordinary errors and budget failures caught by api.protect since enabling.
---@field last ExecutionStats? Previous completed invocation; nil before the first one.
---@field budget LuaBudget Current budget snapshot.
---@return ScriptStats
function client.stats() end
---@return number seconds Monotonic, not game time.
function client.time() end
---@param vk integer
---@return boolean
function client.key_down(vk) end
---@return integer width
---@return integer height
function client.screen_size() end
---@return number seconds
function client.frametime() end

console = {}
---Queue game console commands for a following game frame-stage; true means queued.
---@param command string 1..1024 bytes; NUL forbidden. Game command batches are allowed.
---@return boolean accepted
---@return string? reason console_unavailable, queue_full, rate_limited or script_stopping.
function console.exec(command) end
---Queue literal text in the game console, with a trailing newline. Percent signs are literal.
---@param text string Up to 2048 bytes; NUL forbidden.
---@return boolean accepted
---@return string? reason
function console.print(text) end
---Queue a single quoted say/say_team command, without command injection.
---@param text string 1..200 UTF-8 bytes; controls, quotes, backslashes and semicolons forbidden.
---@param team_only? boolean Defaults to false.
---@return boolean accepted
---@return string? reason
function console.say(text, team_only) end
---Cancel this script's queued requests; requests already handed to the engine are unaffected.
---@return integer removed
function console.clear_pending() end

audio = {}
---Prepare once at top level during script loading. No playback is started.
---@param basename string MP3/WAV basename in muzon, or sounds/<basename>.mp3/.wav. Encoded file <=64 MiB; decoded PCM <=128 MiB.
---@return boolean ok
---@return string? error
function audio.preload(basename) end
---Prepared play uses retained PCM/voice. The first unprepared play loads synchronously.
---@param basename string MP3/WAV basename under %LOCALAPPDATA%/skeet/muzon, or sounds/<basename>.mp3/.wav under %LOCALAPPDATA%/skeet/sounds.
---@param loop? boolean Repeat until stopped.
---@return boolean ok
---@return string? error
function audio.play(basename, loop) end
---@param percent number Finite; clamped to 0..100. Per-script volume, also accepted before playback.
---@return boolean ok
function audio.volume(percent) end
---Stop playback but retain prepared sounds until script unload.
function audio.stop() end

cmd = {}
---In finalize_command, angles is the staged AA pose; movement remains in its original frame.
---@return CommandSnapshot
function cmd.get() end
---In finalize_command, requests an AA pose without changing attack history or the camera.
---Airborne commands use a fixed 180-degree AA pose and synchronize non-shot input history.
---Attack/use commands retain their aim. Use create_move/pre_rage for custom aiming.
---@param angles Vector3
---@param visible? boolean
function cmd.set_angles(angles, visible) end
---Commit shot angles to base and every input-history entry; suppress AA pose
---for this command. Requires ragebot.claim_command() in pre_rage.
---@param angles Vector3
function cmd.set_shot_angles(angles) end
---@param forward number -1..1
---@param side number -1..1, positive is right.
---@param up? number -1..1
function cmd.set_movement(forward, side, up) end
---@param mask integer
---@param pressed boolean
function cmd.set_button(mask, pressed) end
---Explicitly set held/changed/scroll bits for a button mask. Command callbacks only.
---Attack bits of an already formed native rage shot are preserved in late callbacks.
---@param mask integer
---@param held boolean
---@param changed boolean
---@param scroll boolean
function cmd.set_button_state(mask, held, changed, scroll) end
---Mark the current (or a supplied zero-based) input-history entry as primary attack start.
---Returns false in late callbacks after a native rage shot is formed.
---@param index? integer
---@return boolean ok
function cmd.set_attack_start(index) end
---Append an analog/button subtick step before finalization. At most 64 steps per command.
---@param when number 0..1 exclusive
---@param forward_delta number -2..2
---@param side_delta number -2..2
---@param button? integer
---@param pressed? boolean
---@return boolean ok
function cmd.add_subtick(when, forward_delta, side_delta, button, pressed) end
---Discard current subtick movement steps before rebuilding them.
---No effect after a native rage shot is formed.
function cmd.clear_subticks() end
---Set player/render ticks for every input-history entry; command callbacks only.
---No effect in late callbacks after a native rage shot is formed.
---@param player_tick integer
---@param render_tick integer
---@param player_fraction? number 0..1 exclusive
---@param render_fraction? number 0..1 exclusive
function cmd.set_history_ticks(player_tick, render_tick, player_fraction, render_fraction) end

movement = {}
---Claim native bhop or both native strafers for the current command; create_move only.
---@param feature 'bhop'|'strafe'
function movement.claim(feature) end
---@return {flags: integer, on_ground: boolean, velocity: Vector3, predicted_velocity: Vector3, origin: Vector3, surface_friction: number, stamina: number, move_type: integer, forward: number, side: number, buttons: integer}
function movement.context() end

entity = {}
---@return PlayerSnapshot?
function entity.local_player() end
---@param enemies_only? boolean
---@return PlayerSnapshot[]
function entity.players(enemies_only) end
---@param id integer
---@return PlayerSnapshot?
function entity.get(id) end
---@param id integer
---@param bone_index integer 0..127
---@return Vector3?
function entity.bone(id, bone_index) end
---@param id integer
---@return {x: number, y: number, w: number, h: number}?
function entity.bounds(id) end
---@return {id: integer, class_hash: integer, origin: Vector3}[]
function entity.items() end
---@param id integer
---@return {item_id: integer, ammo: integer, reloading: boolean}?
function entity.weapon(id) end

combat = {}
---@return {valid: boolean, weapon_type: integer, item_id: integer, tick: integer, time: number, spread: number, inaccuracy: number, scoped: boolean, range: number, eye: Vector3}
function combat.context() end
---@return {item_id: integer, is_revolver: boolean, client_tick: integer, tick_base: integer, ready_tick: integer, next_primary_tick: integer, next_secondary_tick: integer, ammo: integer, reloading: boolean, can_start_primary: boolean, postponed_primary_ready: boolean}?
function combat.weapon_state() end
---Return native spread correction for the supplied aim/tick, or nil if no solution.
---@param aim Vector3
---@param tick? integer
---@param hidden_shot? boolean
---@return Vector3?
function combat.spread_correction(aim, tick, hidden_shot) end
---Sample the current weapon's native spread for an exact command angle/tick.
---@param angles Vector3
---@param tick? integer
---@return {seed: integer, x: number, y: number}?
function combat.spread_sample(angles, tick) end
---@param target_id integer
---@param world_point Vector3
---@return {damage: number, hitbox: integer, hitgroup: integer, penetrated: boolean}?
---@param record_tick? integer Must still be an available non-future record.
function combat.damage(target_id, world_point, record_tick) end
---@return boolean
---@param ignore_next_attack? boolean Still checks reload/ammo; useful while an R8 cock is already held.
function combat.can_shoot(ignore_next_attack) end
---@return Vector3?
function combat.aim_punch() end
---@param target_id integer
---@return {tick: integer, time: number, origin: Vector3, velocity: Vector3, ducked: boolean, extrapolated: boolean}[]
function combat.records(target_id) end

trace = {}
---@param start Vector3
---@param finish Vector3
---@param skip_player_id? integer
---@return {fraction: number, end_pos: Vector3, normal: Vector3, all_solid: boolean}
function trace.line(start, finish, skip_player_id) end

render = {}
---@param x number
---@param y number
---@param text string
---@param color Color
---@param font? integer Handle obtained by this script in paint.
function render.text(x, y, text, color, font) end
---@param x1 number
---@param y1 number
---@param x2 number
---@param y2 number
---@param color Color
---@param thickness? number
function render.line(x1, y1, x2, y2, color, thickness) end
---@param x number
---@param y number
---@param width number
---@param height number
---@param color Color
---@param filled? boolean
function render.rect(x, y, width, height, color, filled) end
---@param x number
---@param y number
---@param radius number
---@param color Color
---@param filled? boolean
function render.circle(x, y, radius, color, filled) end
---@param text string
---@return number width
---@return number height
---@param font? integer Custom fonts require paint.
function render.measure_text(text, font) end
---@param world Vector3
---@return number? x
---@return number? y
---@return boolean? on_screen
function render.world_to_screen(world) end

ui = {}
---@param kind 'checkbox'|'slider'|'combo'|'color'|'text'
---@param id string
---@param label string
---@param default any
---@param min_or_options? number|string[]|{key: integer, mode: integer} Checkbox accepts optional bind table (key 0..255; mode 0 toggle, 1 hold_on, 2 hold_off).
---@param max? number
---@return string id
function ui.create(kind, id, label, default, min_or_options, max) end
---@param id string
---@return any
function ui.get(id) end
---@param id string
---@param value any
function ui.set(id, value) end
---@param id string Checkbox control id.
---@param key? integer Windows VK 0..255; 0 removes the key.
---@param mode? integer 0 toggle, 1 hold_on, 2 hold_off.
---@return {key: integer, mode: integer, active: boolean} bind
function ui.bind(id, key, mode) end

---@class MenuLanguage
---@field id string
---@field name string
---@field font? string Custom font basename in %LOCALAPPDATA%/skeet
---@field font_size? number Custom menu font size in pixels

---Registers/replaces this script's UTF-8 menu dictionary. Built-ins en/zh-CN are reserved.
---Removed on script unload/error; missing entries fall back to the original English text.
---Applies only to Skeet's native interface/editor shell; Lua UI, source and logs stay literal.
---@param id string ASCII letters/digits/-/_, 1..48 bytes
---@param name string UTF-8 display name, 1..96 bytes
---@param translations table<string,string> English visible text => UTF-8 translation
---@return boolean success False for another owner's ID or registry limit
function ui.register_language(id, name, translations) end
---@param id string
---@return boolean removed Only the owning script can remove a custom dictionary
function ui.unregister_language(id) end
---Associates a local TTF/OTF/TTC/OTC file with this script's registered language.
---CPU validation happens now; GPU font creation is deferred to the next menu frame.
---nil filename removes the language font, falling back to a menu override or the default.
---Lua UI/source/logs retain their own fonts.
---@param id string This script's language ID; built-ins/other owners are protected
---@param filename? string UTF-8 basename directly in %LOCALAPPDATA%/skeet
---@param size? number 8..24 pixels, default 11; one size across the native interface
---@return boolean success
---@return string? error File/format/ownership/cache failure; previous selection is preserved
function ui.set_language_font(id, filename, size) end
---Sets this script's default menu font without changing the selected language.
---A font attached to the selected language takes priority. Latest live default override wins.
---@param filename? string Basename in %LOCALAPPDATA%/skeet; nil releases this script's override
---@param size? number 8..24 pixels, default 11
---@return boolean success
---@return string? error
function ui.set_menu_font(filename, size) end
---@class MenuFontInfo
---@field language string Effective language ID
---@field source 'default'|'menu'|'language'
---@field filename? string Custom font basename
---@field size? number Custom font size
---@return MenuFontInfo font Metadata; GPU creation is deferred
function ui.get_menu_font() end
---@class LuaWindowOptions
---@field key? integer 0 follows Skeet; 1..255 uses a separate VK toggle key
---@field open? boolean Default true for key=0; false for a separate key
---@field x? number Default 120
---@field y? number Default 120
---@field width? number 180..1600, default 320
---@field height? number 120..1600, default 360
---@class LuaWindowInfo
---@field id string
---@field title string
---@field key integer
---@field open boolean Effective visibility
---@field follows_menu boolean
---@field x number
---@field y number
---@field width number
---@field height number
---Registers an interactive, draggable/resizable script window; at most 8 per script.
---@param id string Unique script-owned UTF-8 ID, 1..80 bytes
---@param title string Script-authored UTF-8 title, 1..160 bytes
---@param options? LuaWindowOptions
---@return string id
function ui.create_window(id, title, options) end
---Moves an existing ui.create control into this script's window; nil restores Config placement.
---@param control_id string
---@param window_id? string
function ui.attach_window(control_id, window_id) end
---@param id string
---@param key? integer Query if omitted; 0 follows Skeet, 1..255 independent VK key
---@return {key: integer, open: boolean, follows_menu: boolean} bind
function ui.window_bind(id, key) end
---@param id string
---@param open boolean Follow-mode windows remain hidden while Skeet is closed
function ui.set_window_open(id, open) end
---@param id string
---@return LuaWindowInfo window
function ui.get_window(id) end
---@return string id Effective language ID; en when the saved custom ID is unavailable
function ui.get_language() end
---@param id string
---@return boolean success False for an unknown ID; selection is saved with the config
function ui.set_language(id) end
---@param text string
---@param id? string Defaults to the effective menu language
---@return string text Unknown language/key returns the original text
function ui.translate(text, id) end
---@return string[] keys Sorted English menu text, without ## suffixes
function ui.get_translation_keys() end
---@return MenuLanguage[] languages English, Chinese, then custom IDs in alphabetical order
function ui.get_languages() end

storage = {}
---@param key string
---@param default? any
---@return any
function storage.get(key, default) end
---@param key string
---@param value any Pass nil to remove the key. Persisted on unload.
function storage.set(key, value) end

---@class CustomModel
---@field id string Relative compiled file under game/csgo/characters/models, e.g. fatality/sas/player.vmdl_c.
---@field path string Virtual CS2 path passed to the player-model setter.

models = {}
---@return CustomModel[] models Up to 512 compiled models found under CS2 game/csgo/characters/models.
function models.list() end
---@param id string ID returned by models.list().
---@return string path Virtual model path; this script's choice overrides the built-in agent changer while enabled.
function models.set(id) end
---Release this script's choice. The next Lua choice, built-in agent or native model is applied on a game frame.
function models.clear() end
---@return string? path This script's current virtual model path, or nil.
function models.current() end
---@return 'idle'|'ready'|'error' status Ready confirms file existence, not engine rendering.
---@return string? message Error detail when status is error.
function models.status() end

chams = {}
---@return string[] targets enemy, enemy_invisible, team, team_invisible, local, arms, weapon, attachments.
function chams.targets() end
---@param name string "bloom", "glow" or "flat". Load phase only.
---@return integer? handle Script-local handle with visible and ignorez variants.
---@return string? error "material_unavailable" on native failure.
function chams.builtin_material(name) end
---@param visible_path string Virtual materials/.../*.vmat or .vmat_c resource path. Load phase only.
---@param ignorez_path string? Optional separately authored ignorez material path.
---@return integer? handle Script-local handle; no ignorez variant unless explicitly provided.
---@return string? error Missing resource/interface errors; invalid arguments raise a Lua error.
function chams.load_material(visible_path, ignorez_path) end
---@param brightness number 0.1..8. Only allowed while the script loads.
---@param tint Color RGB baked into a new solidcolor material; alpha is ignored.
---@return integer handle Script-local handle, valid until the script is unloaded.
function chams.create_material(brightness, tint) end
---@param target string One of chams.targets().
---attachments: local owned inventory weapons in thirdperson, including held and holstered pistol/knife models.
---@param handle integer? Script-local material handle; nil releases this target.
---@param color Color? Render RGBA; required unless handle is nil.
function chams.set(target, handle, color) end

-- API v2; full contracts and phase restrictions: EXTENSIONS.ru.md / RAGEBOT.ru.md.
---@class Vector2
---@field x number
---@field y number
---@class RageRecord
---@field tick integer
---@field time number
---@field origin Vector3
---@field velocity Vector3
---@field extrapolated boolean
---@field future boolean
---@field ducked boolean
---@class RagePoint
---@field hitbox integer 0..18; hitbox index, not bone index.
---@field position Vector3 World position.
---@field center? boolean Ordering hint.
---@class RageHitbox
---@field index integer
---@field bone integer
---@field radius number
---@field center Vector3
---@field capsule_a Vector3
---@field capsule_b Vector3
---@field extents Vector3
---@field axis_x Vector3
---@field axis_y Vector3
---@field axis_z Vector3
---@class RageScan
---@field id integer Player controller index.
---@field health integer
---@field min_damage number
---@field record RageRecord
---@field eye Vector3
---@field inaccuracy number
---@field spread number
---@field prediction boolean
---@field centers_only boolean
---@field trace_budget integer
---@field hitboxes RageHitbox[] All available geometry, including boxes disabled in menu.
---@field points RagePoint[] Native point list for this pass.
---@class RageHit
---@field id integer
---@field health integer
---@field damage number
---@field fov number
---@field hitbox integer Actual intersected hitbox.
---@field requested_hitbox integer Requested hitbox.
---@field hitgroup integer
---@field position Vector3
---@field angles Vector3
---@field eye Vector3
---@field center boolean
---@field penetrated boolean
---@field record RageRecord
---@class RageSelection
---@field hits RageHit[]
---@field inaccuracy number
---@field spread number
---@field no_spread boolean
---@field required_hitchance number Percent 0..100.
---@field allow_force boolean

ragebot = {}
---Pure geometry. phase is in radians. Rings are interleaved from inner to outer.
---@param kind 'rings'|'spiral'
---@param count integer 1..128
---@param rings? integer 1..32, default 4; ignored for spiral.
---@param phase? number Radians, default 0.
---@return Vector2[]
function ragebot.pattern(kind, count, rings, phase) end
---Only in rage_scan; maps offsets onto the current record's hitbox silhouette.
---@param hitbox integer 0..18
---@param offsets Vector2[] At most 128 points in the unit disk.
---@param scale? number 0..100, default 100.
---@return RagePoint[]
function ragebot.multipoints(hitbox, offsets, scale) end
---Only in rage_select; at most 32 total HC queries per script/command.
---@param index integer 1-based index into this callback's hits.
---@return number percentage 0..100, geometric; not a second penetration test.
function ragebot.hitchance(index) end
---Only in pre_rage. Skips the native ragebot for THIS command; renew each command.
---Use cmd APIs to implement a complete custom command strategy. Other features still run.
function ragebot.claim_command() end

---Command callbacks only. nil if the record expired; latest record if tick omitted.
---@param id integer
---@param record_tick? integer
---@return {tick: integer, time: number, hitboxes: table[]}?
function combat.hitboxes(id, record_tick) end
---Head probability excludes samples that first hit another hitbox of the target; no per-sample world traces.
---@param id integer
---@param point Vector3
---@param hitbox integer 0..18
---@param record_tick? integer
---@return number? percentage 0..100
function combat.hitchance(id, point, hitbox, record_tick) end

---Deferred self-unload after the current callback returns.
function client.unload() end
---paint only.
---@return boolean
function ui.is_menu_opened() end
---paint only. Screen pixels.
---@return {x: number, y: number, w: number, h: number}
function ui.get_menu_rect() end
---paint only. Current-frame mouse coordinates in screen pixels; clicked is a new left press, down is held.
---All paint callbacks see the same click. Drag only while the menu is open; stop on release or menu close.
---@return {x: number, y: number, down: boolean, clicked: boolean}
function ui.mouse_state() end
---@param src Vector3
---@param dst Vector3
---@return Vector3 angles Degrees.
function math.calc_angle(src, dst) end
---@param src Vector3
---@param dst Vector3
---@return number degrees
function math.calc_fov(src, dst) end
---@param degrees number
---@return number degrees -180..180
function math.normalize_angle(degrees) end
---@param forward Vector3
---@return Vector3 angles
function math.vector_angles(forward) end
---@param angles Vector3
---@return Vector3 forward
---@return Vector3 right
---@return Vector3 up
function math.angle_vectors(angles) end

-- Render additions. Drawing, resource creation and UI geometry require paint.
---@return integer count Number of scripting paint passes since DLL initialization.
function render.frame_count() end
---@return number seconds
function render.frame_time() end
---@return integer width
---@return integer height
function render.screen_size() end
---@param x number
---@param y number
---@param w number
---@param h number
---@param tl Color
---@param tr Color
---@param br Color
---@param bl Color
function render.rect_filled_fade(x, y, w, h, tl, tr, br, bl) end
---@param points Vector2[] 2..256 points.
---@param color Color
---@param thickness? number 0.1..100, default 1.
---@param closed? boolean Default false.
function render.poly_line(points, color, thickness, closed) end
---@param points Vector2[] 3..256 vertices; simple polygon without holes.
---@param color Color
function render.polygon(points, color) end
---@param points Vector2[] Same contract as polygon.
---@param color Color
function render.concave_polygon(points, color) end
---@param x number
---@param y number
---@param radius number
---@param start_angle number Radians.
---@param end_angle number Radians.
---@param color Color
---@param thickness? number Default 1.
---@param segments? integer 2..256, default 64.
function render.arc(x, y, radius, start_angle, end_angle, color, thickness, segments) end
---@param x number
---@param y number
---@param width number
---@param height number
function render.push_clip_rect(x, y, width, height) end
function render.pop_clip_rect() end
---@param x number
---@param y number
---@param radius number
---@param inside Color
---@param outside Color
function render.circle_fade(x, y, radius, inside, outside) end
---@param position Vector3
---@param radius number
---@param color Color
---@param normal? Vector3 Default {x=0,y=0,z=1}.
function render.circle_3d(position, radius, color, normal) end
---@param position Vector3
---@param radius number
---@param color Color
---@param normal? Vector3
function render.circle_filled_3d(position, radius, color, normal) end
---@param position Vector3
---@param radius number
---@param inside Color
---@param outside Color
---@param normal? Vector3
function render.circle_fade_3d(position, radius, inside, outside, normal) end
---@param basename string File under config_dir/resources/<basename>, or skeetles/name.png under config_dir/skeetles; at most 4 MiB.
---@return integer? texture Handle; nil on missing/unsupported image.
---@return string? error Resource failure code; nil on success.
function render.setup_texture(basename) end
---@param bytes string Binary encoded image, at most 4 MiB.
---@return integer? texture
---@return string? error Resource failure code; nil on success.
function render.setup_texture_from_memory(bytes) end
---@param bytes string Raw RGBA bytes; exactly width*height*4.
---@param width integer 1..4096, total pixels at most 1048576.
---@param height integer 1..4096
---@return integer? texture
---@return string? error Resource failure code; nil on success.
function render.setup_texture_rgba(bytes, width, height) end
---@param width integer 1..4096; total pixels <=1048576.
---@param height integer
---@return integer? texture Mutable, private to this script; retained/reused after unload.
---@return string? error
function render.create_texture_rgba(width, height) end
---@param texture integer Handle from render.create_texture_rgba.
---@param bytes string Exactly width*height*4 RGBA bytes; call before drawing this frame.
---@return boolean? success
---@return string? error
function render.update_texture_rgba(texture, bytes) end
---@param texture integer Handle from render.create_texture_rgba.
---@param bytes string Pixel bytes, <=4 MiB; at least pitch*(height-1)+row_bytes, at most pitch*height.
---@param format 'rgba8'|'bgra8'|'bgrx8'|'rgb565'|'rgb555' 16-bit formats use little-endian words.
---@param pitch? integer Bytes per source row; default tightly packed; >=width*bytes_per_pixel.
---@return boolean? success
---@return string? error Resource error; invalid arguments raise a Lua error.
function render.update_texture_pixels(texture, bytes, format, pitch) end
---@param texture integer Handle returned to this script.
---@return integer width Original pixel width.
---@return integer height Original pixel height.
function render.texture_size(texture) end
---@param texture integer Handle returned to this script.
---@param x number
---@param y number
---@param width number
---@param height number
---@param tint? Color Default white.
---@param rounding? number Default 0.
function render.texture(texture, x, y, width, height, tint, rounding) end
---@param texture integer Handle returned to this script.
---@param center_x number Rotation center in screen pixels.
---@param center_y number Rotation center in screen pixels.
---@param width number Drawn width.
---@param height number Drawn height.
---@param angle number Clockwise rotation in radians.
---@param tint? Color Default white.
function render.texture_rotated(texture, center_x, center_y, width, height, angle, tint) end
---@param basename string TTF/OTF under config_dir/resources/<basename>, or fonts/<basename> under config_dir/fonts.
---@param size number 6..96 pixels.
---@return integer? font
---@return string? error Resource failure code; nil on success.
function render.setup_font(basename, size) end
---Override built-in ESP labels, keybinds or watermark with a font loaded by this script.
---Call in paint; pass nil to release this script's override.
---@param target 'esp'|'keybinds'|'watermark'
---@param font? integer
function render.builtin_font(target, font) end
