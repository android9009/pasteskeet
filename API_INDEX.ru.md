# Полный каталог Lua и FFI

Здесь перечислены **225 функция игрового API** и **21 функция встроенного
FFI**, объявленные в текущих IDE-файлах, а также поля структур и модулей.
В стандартных библиотеках Lua есть дополнительные функции; они не входят
в этот счётчик расширений. Начинающему автору сначала стоит прочитать
[AUTHORING.ru.md](AUTHORING.ru.md).

Это индекс сигнатур, аргументов, результатов и ограничений из
[api.lua](api.lua) и [ffi.lua](ffi.lua). Подробные русские объяснения,
разрешённые фазы и примеры находятся в [README.ru.md](README.ru.md),
[EXTENSIONS.ru.md](EXTENSIONS.ru.md), [FFI.ru.md](FFI.ru.md) и специализированных
руководствах. Наличие имени в списке не означает, что его можно вызвать
в любом callback или с любым типом данных.

## Как читать сигнатуры

| Обозначение | Значение |
|---|---|
| `---@param name type` | Имя и допустимый тип аргумента |
| `name?` / `type?` | Необязательный аргумент / возможное `nil` |
| `---@return type` | Тип результата; несколько строк — несколько результатов |
| `---@overload` | Дополнительная форма вызова |
| `integer` / `number` | Целое / число, с отдельными ограничениями диапазона |
| `boolean` / `string` | Логическое значение / строка |
| `Vector3` | Таблица `{x=...,y=...,z=...}` |
| `Color` | Массив `{r,g,b,a}` из четырёх целых чисел 0–255 |
| `Type[]` | Массив Lua с индексами от 1 |
| `{field: type}` | Таблица с именованными полями |
| `CData`, `CType`, `CLibrary` | Объекты FFI; не обычные Lua-таблицы |
| `fun(...)` | Callback / функция с указанными аргументами |

Комментарии под сигнатурами сохранены в форме IDE-аннотаций, включая
ограничения размера, фазы вызова и возможные ошибки. Для отсутствующих
результатов проверяй `nil` до использования. `render` и геометрия `ui`
требуют `paint`; `cmd` требует командного callback, а отдельные операции
имеют дополнительные ограничения.

## Где искать по задаче

- UI, события, сущности, настройки, хранение и консоль: [README.ru.md](README.ru.md).
- Графика, звук, ошибки ресурсов и статистика: [EXTENSIONS.ru.md](EXTENSIONS.ru.md).
- Движение: [MOVEMENT.ru.md](MOVEMENT.ru.md).
- Рейджбот: [RAGEBOT.ru.md](RAGEBOT.ru.md).
- Материалы и модели: [CHAMS.ru.md](CHAMS.ru.md), [MODELS.ru.md](MODELS.ru.md).
- Нативные библиотеки и память: [FFI.ru.md](FFI.ru.md).

## Поля вне списка функций

`api.version` — версия API, сейчас 2; `api.lua` — версия языка;
`api.script` — имя загруженного Lua-файла. Поля доступны для чтения
из скрипта; не используй собственную запись в них как изменение версии движка.
`ffi.C`, `ffi.os`, `ffi.arch`, `ffi.nullptr` описаны в руководстве FFI.
Глобальная таблица `buttons` содержит маски кнопок команды игрока;
не заменяй её собственными VK или номерами мыши.

## Стандартный Lua

Доступны базовые функции, `math`, `string`, `table`, `utf8` и их обычные
операции: например `assert`, `error`, `type`, `tostring`, `tonumber`,
`pairs`, `ipairs`, `math.floor`, `string.format`, `table.insert`.
`print` направлен в журнал скита. `math` также содержит расширения ниже.
`io`, `os`, `package`, `debug`, `coroutine`, `load`, `loadfile`, `dofile`,
`collectgarbage`, `pcall`, `xpcall` не предоставлены. Вместо обычного `pcall`
используется ограниченный `api.protect`; `require` принимает только `ffi`/`cffi`.
FFI отдельно позволяет вызвать нативные аналоги операций ОС.

## Skeet Lua API

### `api`

#### `api.protect(fn, limits)`

```lua
---Catch ordinary errors and budget exhaustion. Allocation failures remain fatal.
---No rollback of settings, draws, UI or other side effects. fn receives no arguments; use a closure.
---@param fn fun(): ...
---@param limits? {instructions?: integer, time_ms?: number} Defaults 1000000 / 25 ms; maxima 20000000 / 250 ms; parent limits apply.
---@return boolean ok
---@return string? error Exact 'budget_exceeded' for budget failure; ordinary errors have a traceback; nil on success.
---@return ... results All fn results including nils on success; LuaBudgetError as third result on budget failure.
```

[api.lua](api.lua)

#### `api.budget()`

```lua
---Snapshot; querying consumes a host API call.
---@return LuaBudget budget
```

`api.error_codes.budget_exceeded` = `"budget_exceeded"`. Типы `LuaBudget` и `LuaBudgetError`, иерархия, учёт combat.hitchance и примеры: [BUDGETS.ru.md](BUDGETS.ru.md), [api.lua](api.lua).

### `audio`

#### `audio.preload(basename)`

```lua
---Prepare once at top level during script loading. No playback is started.
---@param basename string MP3/WAV basename in muzon, or sounds/<basename>.mp3/.wav. Encoded file <=64 MiB; decoded PCM <=128 MiB.
---@return boolean ok
---@return string? error
```

[api.lua](api.lua)

#### `audio.play(basename, loop)`

```lua
---Prepared play uses retained PCM/voice. The first unprepared play loads synchronously.
---@param basename string MP3/WAV basename under %LOCALAPPDATA%/skeet/muzon, or sounds/<basename>.mp3/.wav under %LOCALAPPDATA%/skeet/sounds.
---@param loop? boolean Repeat until stopped.
---@return boolean ok
---@return string? error
```

[api.lua](api.lua)

#### `audio.volume(percent)`

```lua
---@param percent number Finite; clamped to 0..100. Per-script volume, also accepted before playback.
---@return boolean ok
```

[api.lua](api.lua)

#### `audio.stop()`

```lua
---Stop playback but retain prepared sounds until script unload.
```

[api.lua](api.lua)

### `chams`

#### `chams.targets()`

```lua
---@return string[] targets enemy, enemy_invisible, team, team_invisible, local, arms, weapon, attachments.
```

[api.lua](api.lua)

#### `chams.builtin_material(name)`

```lua
---@param name string "bloom", "glow" or "flat". Load phase only.
---@return integer? handle Script-local handle with visible and ignorez variants.
---@return string? error "material_unavailable" on native failure.
```

[api.lua](api.lua)

#### `chams.load_material(visible_path, ignorez_path)`

```lua
---@param visible_path string Virtual materials/.../*.vmat or .vmat_c resource path. Load phase only.
---@param ignorez_path string? Optional separately authored ignorez material path.
---@return integer? handle Script-local handle; no ignorez variant unless explicitly provided.
---@return string? error Missing resource/interface errors; invalid arguments raise a Lua error.
```

[api.lua](api.lua)

#### `chams.create_material(brightness, tint)`

```lua
---@param brightness number 0.1..8. Only allowed while the script loads.
---@param tint Color RGB baked into a new solidcolor material; alpha is ignored.
---@return integer handle Script-local handle, valid until the script is unloaded.
```

[api.lua](api.lua)

#### `chams.set(target, handle, color)`

```lua
---@param target string One of chams.targets().
---attachments: local owned inventory weapons in thirdperson, including held and holstered pistol/knife models.
---@param handle integer? Script-local material handle; nil releases this target.
---@param color Color? Render RGBA; required unless handle is nil.
```

[api.lua](api.lua)

### `client`

#### `client.log(...)`

```lua
---@param ... any
```

[api.lua](api.lua)

#### `client.log_level(level, ...)`

```lua
---@param level 'debug'|'info'|'warning'|'error'
---@param ... any
```

[api.lua](api.lua)

#### `client.stats()`

```lua
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
```

[api.lua](api.lua)

#### `client.time()`

```lua
---@return number seconds Monotonic, not game time.
```

[api.lua](api.lua)

#### `client.key_down(vk)`

```lua
---@param vk integer
---@return boolean
```

[api.lua](api.lua)

#### `client.screen_size()`

```lua
---@return integer width
---@return integer height
```

[api.lua](api.lua)

#### `client.frametime()`

```lua
---@return number seconds
```

[api.lua](api.lua)

#### `client.unload()`

```lua
---Deferred self-unload after the current callback returns.
```

[api.lua](api.lua)

### `cmd`

#### `cmd.get()`

```lua
---In finalize_command, angles is the staged AA pose; movement remains in its original frame.
---@return CommandSnapshot
```

[api.lua](api.lua)

#### `cmd.set_angles(angles, visible)`

```lua
---In finalize_command, requests an AA pose without changing attack history or the camera.
---Airborne commands use a fixed 180-degree AA pose and synchronize non-shot input history.
---Attack/use commands retain their aim. Use create_move/pre_rage for custom aiming.
---@param angles Vector3
---@param visible? boolean
```

[api.lua](api.lua)

#### `cmd.set_shot_angles(angles)`

```lua
---Commit shot angles to base and every input-history entry; suppress AA pose
---for this command. Requires ragebot.claim_command() in pre_rage.
---@param angles Vector3
```

[api.lua](api.lua)

#### `cmd.set_movement(forward, side, up)`

```lua
---@param forward number -1..1
---@param side number -1..1, positive is right.
---@param up? number -1..1
```

[api.lua](api.lua)

#### `cmd.set_button(mask, pressed)`

```lua
---@param mask integer
---@param pressed boolean
```

[api.lua](api.lua)

#### `cmd.set_button_state(mask, held, changed, scroll)`

```lua
---Explicitly set held/changed/scroll bits for a button mask. Command callbacks only.
---Attack bits of an already formed native rage shot are preserved in late callbacks.
---@param mask integer
---@param held boolean
---@param changed boolean
---@param scroll boolean
```

[api.lua](api.lua)

#### `cmd.set_attack_start(index)`

```lua
---Mark the current (or a supplied zero-based) input-history entry as primary attack start.
---Returns false in late callbacks after a native rage shot is formed.
---@param index? integer
---@return boolean ok
```

[api.lua](api.lua)

#### `cmd.add_subtick(when, forward_delta, side_delta, button, pressed)`

```lua
---Append an analog/button subtick step before finalization. At most 64 steps per command.
---@param when number 0..1 exclusive
---@param forward_delta number -2..2
---@param side_delta number -2..2
---@param button? integer
---@param pressed? boolean
---@return boolean ok
```

[api.lua](api.lua)

#### `cmd.clear_subticks()`

```lua
---Discard current subtick movement steps before rebuilding them.
---No effect after a native rage shot is formed.
```

[api.lua](api.lua)

#### `cmd.set_history_ticks(player_tick, render_tick, player_fraction, render_fraction)`

```lua
---Set player/render ticks for every input-history entry; command callbacks only.
---No effect in late callbacks after a native rage shot is formed.
---@param player_tick integer
---@param render_tick integer
---@param player_fraction? number 0..1 exclusive
---@param render_fraction? number 0..1 exclusive
```

[api.lua](api.lua)

### `combat`

#### `combat.context()`

```lua
---@return {valid: boolean, weapon_type: integer, item_id: integer, tick: integer, time: number, spread: number, inaccuracy: number, scoped: boolean, range: number, eye: Vector3}
```

[api.lua](api.lua)

#### `combat.weapon_state()`

```lua
---@return {item_id: integer, is_revolver: boolean, client_tick: integer, tick_base: integer, ready_tick: integer, next_primary_tick: integer, next_secondary_tick: integer, ammo: integer, reloading: boolean, can_start_primary: boolean, postponed_primary_ready: boolean}?
```

[api.lua](api.lua)

#### `combat.spread_correction(aim, tick, hidden_shot)`

```lua
---Return native spread correction for the supplied aim/tick, or nil if no solution.
---@param aim Vector3
---@param tick? integer
---@param hidden_shot? boolean
---@return Vector3?
```

[api.lua](api.lua)

#### `combat.spread_sample(angles, tick)`

```lua
---Sample the current weapon's native spread for an exact command angle/tick.
---@param angles Vector3
---@param tick? integer
---@return {seed: integer, x: number, y: number}?
```

[api.lua](api.lua)

#### `combat.damage(target_id, world_point, record_tick)`

```lua
---@param target_id integer
---@param world_point Vector3
---@return {damage: number, hitbox: integer, hitgroup: integer, penetrated: boolean}?
---@param record_tick? integer Must still be an available non-future record.
```

[api.lua](api.lua)

#### `combat.can_shoot(ignore_next_attack)`

```lua
---@return boolean
---@param ignore_next_attack? boolean Still checks reload/ammo; useful while an R8 cock is already held.
```

[api.lua](api.lua)

#### `combat.aim_punch()`

```lua
---@return Vector3?
```

[api.lua](api.lua)

#### `combat.records(target_id)`

```lua
---@param target_id integer
---@return {tick: integer, time: number, origin: Vector3, velocity: Vector3, ducked: boolean, extrapolated: boolean}[]
```

[api.lua](api.lua)

#### `combat.hitboxes(id, record_tick)`

```lua
---Command callbacks only. nil if the record expired; latest record if tick omitted.
---@param id integer
---@param record_tick? integer
---@return {tick: integer, time: number, hitboxes: table[]}?
```

[api.lua](api.lua)

#### `combat.hitchance(id, point, hitbox, record_tick)`

```lua
---Head probability excludes samples that first hit another hitbox of the target; no per-sample world traces.
---@param id integer
---@param point Vector3
---@param hitbox integer 0..18
---@param record_tick? integer
---@return number? percentage 0..100
```

[api.lua](api.lua)

### `console`

#### `console.exec(command)`

```lua
---Queue game console commands for a following game frame-stage; true means queued.
---@param command string 1..1024 bytes; NUL forbidden. Game command batches are allowed.
---@return boolean accepted
---@return string? reason console_unavailable, queue_full, rate_limited or script_stopping.
```

[api.lua](api.lua)

#### `console.print(text)`

```lua
---Queue literal text in the game console, with a trailing newline. Percent signs are literal.
---@param text string Up to 2048 bytes; NUL forbidden.
---@return boolean accepted
---@return string? reason
```

[api.lua](api.lua)

#### `console.say(text, team_only)`

```lua
---Queue a single quoted say/say_team command, without command injection.
---@param text string 1..200 UTF-8 bytes; controls, quotes, backslashes and semicolons forbidden.
---@param team_only? boolean Defaults to false.
---@return boolean accepted
---@return string? reason
```

[api.lua](api.lua)

#### `console.clear_pending()`

```lua
---Cancel this script's queued requests; requests already handed to the engine are unaffected.
---@return integer removed
```

[api.lua](api.lua)

### `entity`

#### `entity.local_player()`

```lua
---@return PlayerSnapshot?
```

[api.lua](api.lua)

#### `entity.players(enemies_only)`

```lua
---@param enemies_only? boolean
---@return PlayerSnapshot[]
```

[api.lua](api.lua)

#### `entity.get(id)`

```lua
---@param id integer
---@return PlayerSnapshot?
```

[api.lua](api.lua)

#### `entity.bone(id, bone_index)`

```lua
---@param id integer
---@param bone_index integer 0..127
---@return Vector3?
```

[api.lua](api.lua)

#### `entity.bounds(id)`

```lua
---@param id integer
---@return {x: number, y: number, w: number, h: number}?
```

[api.lua](api.lua)

#### `entity.items()`

```lua
---@return {id: integer, class_hash: integer, origin: Vector3}[]
```

[api.lua](api.lua)

#### `entity.weapon(id)`

```lua
---@param id integer
---@return {item_id: integer, ammo: integer, reloading: boolean}?
```

[api.lua](api.lua)

### `events`

#### `events.on(name, callback)`

```lua
---@param name EventName
---@param callback fun(event: table): table?
---@overload fun(name: 'rage_scan', callback: fun(context: RageScan): {points: RagePoint[]}?): integer
---@overload fun(name: 'rage_select', callback: fun(context: RageSelection): {index: integer}?): integer
---@overload fun(name: 'game_event', callback: fun(event: GameEvent)): integer
---@overload fun(name: 'rage_shot', callback: fun(event: RageShotEvent)): integer
---@return integer subscription
```

[api.lua](api.lua)

#### `events.off(id)`

```lua
---@param id integer
---@return boolean removed
```

[api.lua](api.lua)

### `math`

#### `math.calc_angle(src, dst)`

```lua
---@param src Vector3
---@param dst Vector3
---@return Vector3 angles Degrees.
```

[api.lua](api.lua)

#### `math.calc_fov(src, dst)`

```lua
---@param src Vector3
---@param dst Vector3
---@return number degrees
```

[api.lua](api.lua)

#### `math.normalize_angle(degrees)`

```lua
---@param degrees number
---@return number degrees -180..180
```

[api.lua](api.lua)

#### `math.vector_angles(forward)`

```lua
---@param forward Vector3
---@return Vector3 angles
```

[api.lua](api.lua)

#### `math.angle_vectors(angles)`

```lua
---@param angles Vector3
---@return Vector3 forward
---@return Vector3 right
---@return Vector3 up
```

[api.lua](api.lua)

### `models`

#### `models.list()`

```lua
---@return CustomModel[] models Up to 512 compiled models found under CS2 game/csgo/characters/models.
```

[api.lua](api.lua)

#### `models.set(id)`

```lua
---@param id string ID returned by models.list().
---@return string path Virtual model path; this script's choice overrides the built-in agent changer while enabled.
```

[api.lua](api.lua)

#### `models.clear()`

```lua
---Release this script's choice. The next Lua choice, built-in agent or native model is applied on a game frame.
```

[api.lua](api.lua)

#### `models.current()`

```lua
---@return string? path This script's current virtual model path, or nil.
```

[api.lua](api.lua)

#### `models.status()`

```lua
---@return 'idle'|'ready'|'error' status Ready confirms file existence, not engine rendering.
---@return string? message Error detail when status is error.
```

[api.lua](api.lua)

### `movement`

#### `movement.claim(feature)`

```lua
---Claim native bhop or both native strafers for the current command; create_move only.
---@param feature 'bhop'|'strafe'
```

[api.lua](api.lua)

#### `movement.context()`

```lua
---@return {flags: integer, on_ground: boolean, velocity: Vector3, predicted_velocity: Vector3, origin: Vector3, surface_friction: number, stamina: number, move_type: integer, forward: number, side: number, buttons: integer}
```

[api.lua](api.lua)

### `ragebot`

#### `ragebot.pattern(kind, count, rings, phase)`

```lua
---Pure geometry. phase is in radians. Rings are interleaved from inner to outer.
---@param kind 'rings'|'spiral'
---@param count integer 1..128
---@param rings? integer 1..32, default 4; ignored for spiral.
---@param phase? number Radians, default 0.
---@return Vector2[]
```

[api.lua](api.lua)

#### `ragebot.multipoints(hitbox, offsets, scale)`

```lua
---Only in rage_scan; maps offsets onto the current record's hitbox silhouette.
---@param hitbox integer 0..18
---@param offsets Vector2[] At most 128 points in the unit disk.
---@param scale? number 0..100, default 100.
---@return RagePoint[]
```

[api.lua](api.lua)

#### `ragebot.hitchance(index)`

```lua
---Only in rage_select; at most 32 total HC queries per script/command.
---@param index integer 1-based index into this callback's hits.
---@return number percentage 0..100, geometric; not a second penetration test.
```

[api.lua](api.lua)

#### `ragebot.claim_command()`

```lua
---Only in pre_rage. Skips the native ragebot for THIS command; renew each command.
---Use cmd APIs to implement a complete custom command strategy. Other features still run.
```

[api.lua](api.lua)

### `render`

#### `render.text(x, y, text, color, font)`

```lua
---@param x number
---@param y number
---@param text string
---@param color Color
---@param font? integer Handle obtained by this script in paint.
```

[api.lua](api.lua)

#### `render.line(x1, y1, x2, y2, color, thickness)`

```lua
---@param x1 number
---@param y1 number
---@param x2 number
---@param y2 number
---@param color Color
---@param thickness? number
```

[api.lua](api.lua)

#### `render.rect(x, y, width, height, color, filled)`

```lua
---@param x number
---@param y number
---@param width number
---@param height number
---@param color Color
---@param filled? boolean
```

[api.lua](api.lua)

#### `render.circle(x, y, radius, color, filled)`

```lua
---@param x number
---@param y number
---@param radius number
---@param color Color
---@param filled? boolean
```

[api.lua](api.lua)

#### `render.measure_text(text, font)`

```lua
---@param text string
---@return number width
---@return number height
---@param font? integer Custom fonts require paint.
```

[api.lua](api.lua)

#### `render.world_to_screen(world)`

```lua
---@param world Vector3
---@return number? x
---@return number? y
---@return boolean? on_screen
```

[api.lua](api.lua)

#### `render.frame_count()`

```lua
---@return integer count Number of scripting paint passes since DLL initialization.
```

[api.lua](api.lua)

#### `render.frame_time()`

```lua
---@return number seconds
```

[api.lua](api.lua)

#### `render.screen_size()`

```lua
---@return integer width
---@return integer height
```

[api.lua](api.lua)

#### `render.rect_filled_fade(x, y, w, h, tl, tr, br, bl)`

```lua
---@param x number
---@param y number
---@param w number
---@param h number
---@param tl Color
---@param tr Color
---@param br Color
---@param bl Color
```

[api.lua](api.lua)

#### `render.poly_line(points, color, thickness, closed)`

```lua
---@param points Vector2[] 2..256 points.
---@param color Color
---@param thickness? number 0.1..100, default 1.
---@param closed? boolean Default false.
```

[api.lua](api.lua)

#### `render.polygon(points, color)`

```lua
---@param points Vector2[] 3..256 vertices; simple polygon without holes.
---@param color Color
```

[api.lua](api.lua)

#### `render.concave_polygon(points, color)`

```lua
---@param points Vector2[] Same contract as polygon.
---@param color Color
```

[api.lua](api.lua)

#### `render.arc(x, y, radius, start_angle, end_angle, color, thickness, segments)`

```lua
---@param x number
---@param y number
---@param radius number
---@param start_angle number Radians.
---@param end_angle number Radians.
---@param color Color
---@param thickness? number Default 1.
---@param segments? integer 2..256, default 64.
```

[api.lua](api.lua)

#### `render.push_clip_rect(x, y, width, height)`

```lua
---@param x number
---@param y number
---@param width number
---@param height number
```

[api.lua](api.lua)

#### `render.pop_clip_rect()`

[api.lua](api.lua)

#### `render.circle_fade(x, y, radius, inside, outside)`

```lua
---@param x number
---@param y number
---@param radius number
---@param inside Color
---@param outside Color
```

[api.lua](api.lua)

#### `render.circle_3d(position, radius, color, normal)`

```lua
---@param position Vector3
---@param radius number
---@param color Color
---@param normal? Vector3 Default {x=0,y=0,z=1}.
```

[api.lua](api.lua)

#### `render.circle_filled_3d(position, radius, color, normal)`

```lua
---@param position Vector3
---@param radius number
---@param color Color
---@param normal? Vector3
```

[api.lua](api.lua)

#### `render.circle_fade_3d(position, radius, inside, outside, normal)`

```lua
---@param position Vector3
---@param radius number
---@param inside Color
---@param outside Color
---@param normal? Vector3
```

[api.lua](api.lua)

#### `render.setup_texture(basename)`

```lua
---@param basename string File under config_dir/resources/<basename>, or skeetles/name.png under config_dir/skeetles; at most 4 MiB.
---@return integer? texture Handle; nil on missing/unsupported image.
---@return string? error Resource failure code; nil on success.
```

[api.lua](api.lua)

#### `render.setup_texture_from_memory(bytes)`

```lua
---@param bytes string Binary encoded image, at most 4 MiB.
---@return integer? texture
---@return string? error Resource failure code; nil on success.
```

[api.lua](api.lua)

#### `render.setup_texture_rgba(bytes, width, height)`

```lua
---@param bytes string Raw RGBA bytes; exactly width*height*4.
---@param width integer 1..4096, total pixels at most 1048576.
---@param height integer 1..4096
---@return integer? texture
---@return string? error Resource failure code; nil on success.
```

[api.lua](api.lua)

#### `render.create_texture_rgba(width, height)`

```lua
---@param width integer 1..4096; total pixels <=1048576.
---@param height integer
---@return integer? texture Mutable, private to this script; retained/reused after unload.
---@return string? error
```

[api.lua](api.lua)

#### `render.update_texture_rgba(texture, bytes)`

```lua
---@param texture integer Handle from render.create_texture_rgba.
---@param bytes string Exactly width*height*4 RGBA bytes; call before drawing this frame.
---@return boolean? success
---@return string? error
```

[api.lua](api.lua)

#### `render.update_texture_pixels(texture, bytes, format, pitch)`

```lua
---@param texture integer Handle from render.create_texture_rgba.
---@param bytes string Pixel bytes, <=4 MiB; at least pitch*(height-1)+row_bytes, at most pitch*height.
---@param format 'rgba8'|'bgra8'|'bgrx8'|'rgb565'|'rgb555' 16-bit formats use little-endian words.
---@param pitch? integer Bytes per source row; default tightly packed; >=width*bytes_per_pixel.
---@return boolean? success
---@return string? error Resource error; invalid arguments raise a Lua error.
```

[api.lua](api.lua)

#### `render.texture_size(texture)`

```lua
---@param texture integer Handle returned to this script.
---@return integer width Original pixel width.
---@return integer height Original pixel height.
```

[api.lua](api.lua)

#### `render.texture(texture, x, y, width, height, tint, rounding)`

```lua
---@param texture integer Handle returned to this script.
---@param x number
---@param y number
---@param width number
---@param height number
---@param tint? Color Default white.
---@param rounding? number Default 0.
```

[api.lua](api.lua)

#### `render.texture_rotated(texture, center_x, center_y, width, height, angle, tint)`

```lua
---@param texture integer Handle returned to this script.
---@param center_x number Rotation center in screen pixels.
---@param center_y number Rotation center in screen pixels.
---@param width number Drawn width.
---@param height number Drawn height.
---@param angle number Clockwise rotation in radians.
---@param tint? Color Default white.
```

[api.lua](api.lua)

#### `render.setup_font(basename, size)`

```lua
---@param basename string TTF/OTF under config_dir/resources/<basename>, or fonts/<basename> under config_dir/fonts.
---@param size number 6..96 pixels.
---@return integer? font
---@return string? error Resource failure code; nil on success.
```

[api.lua](api.lua)

#### `render.builtin_font(target, font)`

```lua
---Override built-in ESP labels, keybinds or watermark with a font loaded by this script.
---Call in paint; pass nil to release this script's override.
---@param target 'esp'|'keybinds'|'watermark'
---@param font? integer
```

[api.lua](api.lua)

### `settings`

#### `settings.weapon_profiles()`

```lua
---@return WeaponProfile[]
function settings.weapon_profiles() end
```

Доступно при загрузке скрипта. Все 34 огнестрельных оружия в порядке меню.
Поля `WeaponProfile`: `item_id: integer`, `key: string`, `name: string`,
`legacy_group: string`, `rage_category: string`, `legit_category: string`.
Категории можно передавать в `get/set/override/bind`; подробности и совместимость —
[WEAPON_PROFILES.ru.md](WEAPON_PROFILES.ru.md).

#### `settings.list(category_filter)`

```lua
---@param category_filter? string
---@return SettingDescriptor[]
```

[api.lua](api.lua)

#### `settings.get(category, name)`

```lua
---@param category string
---@param name string
---@return any value
```

[api.lua](api.lua)

#### `settings.set(category, name, value)`

```lua
---@param category string
---@param name string
---@param value any
```

[api.lua](api.lua)

#### `settings.override(category, name, value)`

```lua
---@param category string
---@param name string
---@param value any Pass nil to release this script's override.
```

[api.lua](api.lua)

#### `settings.bind(category, name, key, mode)`

```lua
---@param category string
---@param name string
---@param key? integer Windows virtual key, 0..255.
---@param mode? integer 0 toggle, 1 hold_on, 2 hold_off.
---@return {key: integer, mode: integer, active: boolean}
```

[api.lua](api.lua)

#### `settings.binds()`

```lua
---@class BindSnapshot
---@field category string
---@field name string
---@field key integer Windows virtual key.
---@field mode integer 0 toggle, 1 hold_on, 2 hold_off.
---@field active boolean Whether the bind is active.
---@field value boolean Current setting value.
---@return BindSnapshot[] Native bound settings plus active scripts' Lua checkbox binds; includes inactive binds.
```

[api.lua](api.lua)

### `storage`

#### `storage.get(key, default)`

```lua
---@param key string
---@param default? any
---@return any
```

[api.lua](api.lua)

#### `storage.set(key, value)`

```lua
---@param key string
---@param value any Pass nil to remove the key. Persisted on unload.
```

[api.lua](api.lua)

### `trace`

#### `trace.line(start, finish, skip_player_id)`

```lua
---@param start Vector3
---@param finish Vector3
---@param skip_player_id? integer
---@return {fraction: number, end_pos: Vector3, normal: Vector3, all_solid: boolean}
```

[api.lua](api.lua)

### `ui`

#### `ui.register_language(id, name, translations)`

Регистрирует/заменяет UTF-8-словарь своего скрипта и добавляет язык в Misc.
Переводится основной интерфейс Skeet и оболочка редактора; элементы `ui.create`,
код, графика и вывод Lua сохраняют язык автора.
Аргументы: строковый ASCII ID, строковое имя и таблица `English text → translation`.
Возвращает `boolean`; неверные аргументы вызывают Lua-ошибку, занятый ID/лимит — `false`.
Встроенные `en`/`zh-CN` защищены. Словарь удаляется при выгрузке/ошибке скрипта.
Доступно при загрузке и из callbacks. Лимиты и пример: [LOCALIZATION.ru.md](LOCALIZATION.ru.md).

#### `ui.unregister_language(id)`

Удаляет язык, принадлежащий вызывающему скрипту. Возвращает `boolean`.
Чужой, встроенный или отсутствующий ID возвращает `false`. Все фазы.

#### `ui.set_language_font(id, filename?, size?)`

Назначает шрифт зарегистрированному языку своего скрипта. `filename` — UTF-8
имя файла `.ttf`, `.otf`, `.ttc` или `.otc` непосредственно в `%LOCALAPPDATA%\skeet`;
без путей/подпапок. `size` — 8–24 px, по умолчанию 11. `nil` вместо файла
снимает привязку языка, открывая общий шрифт меню или стандартный fallback.
Для коллекций используется первый face.
Возвращает `success: boolean, error: string|nil`; ошибка файла/формата/владения/лимита
не меняет предыдущий шрифт. Встроенные языки и чужие ID защищены.
Доступно при загрузке и из callbacks: проверка файла выполняется на CPU,
создание GPU-шрифта — в следующем кадре меню. Шрифт применяется к основному
интерфейсу и оболочке редактора; код, логи и UI Lua сохраняют свои шрифты.
Лимиты, lifecycle и пример: [LOCALIZATION.ru.md](LOCALIZATION.ru.md).

#### `ui.set_menu_font(filename?, size?)`

Меняет стандартный шрифт меню независимо от языка: регистрация языка не нужна,
English/简体中文 продолжают работать. Файл — basename TTF/OTF/TTC/OTC в
`%LOCALAPPDATA%\skeet`; размер 8–24 px, по умолчанию 11. Возвращает `boolean, string|nil`.
`nil` снимает только привязку текущего скрипта. Последняя активная привязка выигрывает;
шрифт выбранного языка имеет приоритет над общим. Все фазы, GPU-загрузка отложенная.

#### `ui.get_menu_font()`

Возвращает `MenuFontInfo`: `language: string`, `source: "default"|"menu"|"language"`,
а при пользовательском шрифте — `filename: string` и `size: number`. Все фазы.

#### `ui.create_window(id, title, options?)`

Создаёт собственное перетаскиваемое/изменяемое окно Lua. Возвращает строковый ID.
`LuaWindowOptions`: `key?: 0..255`, `open?: boolean`, `x/y?: number`,
`width?: 180..1600`, `height?: 120..1600`; значения по умолчанию 0, true для key=0,
false для отдельной клавиши, 120/120, 320/360. До 8 окон на скрипт.
Клавиша 0 синхронизирует окно со Skeet, другая VK-клавиша переключает его отдельно.
ID/заголовок — UTF-8, 1–80/1–160 байт; ошибки аргументов вызывают Lua-ошибку.
Все фазы. Подробности ввода: [WINDOWS.ru.md](WINDOWS.ru.md).

#### `ui.attach_window(control_id, window_id?)`

Переносит элемент `ui.create` в окно того же скрипта; `nil` возвращает элемент в Config.
Возвращает nil. Неизвестный элемент/окно вызывает Lua-ошибку. Все фазы.

#### `ui.window_bind(id, key?)`

Получает или меняет привязку окна. Возвращает `{key: integer, open: boolean, follows_menu: boolean}`.
Клавиша 0 возвращает синхронизацию со Skeet. Без аргумента key — только чтение.
Повторное назначение той же клавиши не сбрасывает окно или popup. Все фазы.

#### `ui.set_window_open(id, open)`

Устанавливает состояние окна; возвращает nil. В синхронном режиме окно остаётся
скрытым при закрытом Skeet. Неизвестный ID или не-boolean вызывают Lua-ошибку. Все фазы.

#### `ui.get_window(id)`

Возвращает `LuaWindowInfo`: `id/title: string`, `key: integer`, `open/follows_menu: boolean`,
`x/y/width/height: number`. open отражает эффективную видимость; геометрия обновляется
после перетаскивания/resize. Неизвестный ID вызывает Lua-ошибку. Все фазы.

#### `ui.get_language()`

Возвращает эффективный строковый ID языка меню: `en`, `zh-CN` или пользовательский.
При недоступном сохранённом ID возвращает `en`; сохранённый выбор сохраняется. Все фазы.

#### `ui.set_language(id)`

Выбирает зарегистрированный язык. Возвращает `boolean`; неизвестный ID не меняет выбор.
Выбор сохраняется с конфигом; меню обновляется со следующего кадра. Все фазы.

#### `ui.translate(text, id?)`

Возвращает перевод строки. Необязательный ID по умолчанию равен эффективному языку меню.
Неизвестный язык или ключ возвращает исходную строку. Все фазы.

#### `ui.get_translation_keys()`

Возвращает отсортированный массив английских строк встроенного меню без `##`-суффиксов.
Ключи включают подписи и варианты выбора. Все фазы.

#### `ui.get_languages()`

Возвращает массив `MenuLanguage`: `{id: string, name: string, font?: string, font_size?: number}`.
Поля шрифта присутствуют при пользовательской привязке; имя — basename файла.
Сначала English и китайский, затем пользовательские ID по алфавиту. Все фазы.

#### `ui.create(kind, id, label, default, min_or_options, max)`

```lua
---@param kind 'checkbox'|'slider'|'combo'|'color'|'text'
---@param id string
---@param label string
---@param default any
---@param min_or_options? number|string[]|{key: integer, mode: integer} Checkbox accepts optional bind table (key 0..255; mode 0 toggle, 1 hold_on, 2 hold_off).
---@param max? number
---@return string id
```

[api.lua](api.lua)

#### `ui.get(id)`

```lua
---@param id string
---@return any
```

[api.lua](api.lua)

#### `ui.set(id, value)`

```lua
---@param id string
---@param value any
```

[api.lua](api.lua)

#### `ui.bind(id, key, mode)`

```lua
---@param id string Checkbox control id.
---@param key? integer Windows VK 0..255; 0 removes the key.
---@param mode? integer 0 toggle, 1 hold_on, 2 hold_off.
---@return {key: integer, mode: integer, active: boolean} bind
```

[api.lua](api.lua)

#### `ui.is_menu_opened()`

```lua
---paint only.
---@return boolean
```

[api.lua](api.lua)

#### `ui.get_menu_rect()`

```lua
---paint only. Screen pixels.
---@return {x: number, y: number, w: number, h: number}
```

[api.lua](api.lua)

#### `ui.mouse_state()`

```lua
---paint only. Current-frame mouse coordinates in screen pixels; clicked is a new left press, down is held.
---All paint callbacks see the same click. Drag only while the menu is open; stop on release or menu close.
---@return {x: number, y: number, down: boolean, clicked: boolean}
```

[api.lua](api.lua)

### Types / fields (api.lua)

```lua
---@class Vector3
---@field x number
---@field y number
---@field z number
```

```lua
---@alias Color integer[] RGBA, exactly four channels in 0..255.
---@alias EventName 'paint'|'create_move'|'pre_rage'|'post_rage'|'pre_legit'|'post_legit'|'post_move'|'finalize_command'|'frame_stage'|'game_event'|'shutdown'|'rage_targets'|'rage_scan'|'rage_select'|'rage_fire'|'rage_shot'
```

```lua
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
```

```lua
---@class SettingDescriptor
---@field category string
---@field name string
---@field type string
---@field count integer
---@field writable boolean
```

```lua
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
```

```lua
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
```

```lua
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
```

```lua
---@class BindSnapshot
---@field category string
---@field name string
---@field key integer Windows virtual key.
---@field mode integer 0 toggle, 1 hold_on, 2 hold_off.
---@field active boolean Whether the bind is active.
---@field value boolean Current setting value.
```

```lua
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
```

```lua
---@class CustomModel
---@field id string Relative compiled file under game/csgo/characters/models, e.g. fatality/sas/player.vmdl_c.
---@field path string Virtual CS2 path passed to the player-model setter.
```

```lua
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
```

## FFI

### `ffi`

#### `ffi.cdef(declarations, ...)`

```lua
---@param declarations string
```

[ffi.lua](ffi.lua)

#### `ffi.load(name, global)`

```lua
---@param name string UTF-8 DLL name/path on Windows.
---@param global? boolean
---@return CLibrary
```

[ffi.lua](ffi.lua)

#### `ffi.new(ctype, ...)`

```lua
---@param ctype string|CType
---@return CData
```

[ffi.lua](ffi.lua)

#### `ffi.typeof(ctype, ...)`

```lua
---@param ctype string|CType
---@return CType
```

[ffi.lua](ffi.lua)

#### `ffi.cast(ctype, value)`

```lua
---@param ctype string|CType
---@param value any
---@return CData
```

[ffi.lua](ffi.lua)

#### `ffi.metatype(ctype, metatable)`

```lua
---@param ctype string|CType
---@param metatable table
---@return CType
```

[ffi.lua](ffi.lua)

#### `ffi.addressof(value)`

```lua
---@param value CData
---@return CData pointer
```

[ffi.lua](ffi.lua)

#### `ffi.gc(value, finalizer)`

```lua
---@param value CData
---@param finalizer? fun(value: CData) nil removes finalizer.
---@return CData
```

[ffi.lua](ffi.lua)

#### `ffi.string(value, length)`

```lua
---@param value CData
---@param length? integer
---@return string
```

[ffi.lua](ffi.lua)

#### `ffi.sizeof(value, ...)`

```lua
---@param value CData|string|CType
---@return integer? nil when size is unknown.
```

[ffi.lua](ffi.lua)

#### `ffi.alignof(value)`

```lua
---@param value CData|string|CType
---@return integer
```

[ffi.lua](ffi.lua)

#### `ffi.offsetof(ctype, field)`

```lua
---@param ctype string|CType
---@param field string
---@return integer?
```

[ffi.lua](ffi.lua)

#### `ffi.copy(destination, source, length)`

```lua
---@param destination CData
---@param source CData|string
---@param length? integer
```

[ffi.lua](ffi.lua)

#### `ffi.fill(destination, length, byte)`

```lua
---@param destination CData
---@param length integer
---@param byte? integer
```

[ffi.lua](ffi.lua)

#### `ffi.istype(ctype, value)`

```lua
---@param ctype string|CType
---@param value CData
---@return boolean
```

[ffi.lua](ffi.lua)

#### `ffi.abi(flag)`

```lua
---@param flag string
---@return boolean
```

[ffi.lua](ffi.lua)

#### `ffi.errno(value)`

```lua
---@param value? integer
---@return integer
```

[ffi.lua](ffi.lua)

#### `ffi.tonumber(value)`

```lua
---@param value CData|number|string
---@return number?
```

[ffi.lua](ffi.lua)

#### `ffi.toretval(value)`

```lua
---@param value CData
---@return any
```

[ffi.lua](ffi.lua)

#### `ffi.eval(literal)`

```lua
---@param literal string Numeric literal; not a C expression evaluator.
---@return CData
```

[ffi.lua](ffi.lua)

#### `ffi.type(value)`

```lua
---@param value any
---@return string 'cdata' for CData/CType, otherwise the ordinary Lua type.
```

[ffi.lua](ffi.lua)

### Types / fields (ffi.lua)

```lua
---@class CData
---@class CType
---@class CCallback: CData
---@field free fun(self: CCallback)
---@field set fun(self: CCallback, callback: function)
---@class CLibrary
---@class FFI
---@field C CLibrary
---@field os string
---@field arch string
---@field nullptr CData
```


## Native UI and additional API

See [NATIVE_UI.md](NATIVE_UI.md) for managed XUI/ImGui windows and menu themes.

- `xui.create_window(id, title, options, callback)`
- `xui.text(text, color)`
- `xui.button(label, width, height)`
- `xui.checkbox(label, value)`
- `xui.slider_float(label, value, minimum, maximum)`
- `xui.slider_int(label, value, minimum, maximum)`
- `xui.input_text(label, value, capacity, hint)`
- `xui.combo(label, selected, items, width)`
- `xui.multicombo(label, selected, items)`
- `xui.color_picker(label, color)`
- `xui.same_line(offset, spacing)`
- `xui.spacing(pixels)`
- `xui.cursor(x, y)`
- `xui.available()`
- `xui.window_rect()`
- `xui.begin_child(id, width, height, border_or_scroll)`
- `xui.end_child()`
- `xui.push_id(id)`
- `xui.pop_id()`
- `xui.push_style_color(name, color)`
- `xui.pop_style_color()`
- `xui.push_style_var(name, x, y)`
- `xui.pop_style_var()`
- `xui.push_font(font)`
- `xui.pop_font()`
- `xui.line(x, y, x2, y2, color, thickness)`
- `xui.rect(x, y, width, height, color, rounding, thickness)`
- `xui.rect_filled(x, y, width, height, color, rounding)`
- `xui.blur(x, y, width, height, color, rounding)`
- `xui.text_at(x, y, text, color, font)`
- `xui.circle(x, y, radius, color, filled, thickness)`
- `xui.image(texture, width, height)`
- `xui.begin_popup(id, width)`
- `xui.end_popup()`
- `xui.keybind(label, key)`
- `imgui.create_window(id, title, options, callback)`
- `imgui.text(text, color)`
- `imgui.button(label, width, height)`
- `imgui.checkbox(label, value)`
- `imgui.slider_float(label, value, minimum, maximum)`
- `imgui.slider_int(label, value, minimum, maximum)`
- `imgui.input_text(label, value, capacity, hint)`
- `imgui.combo(label, selected, items, width)`
- `imgui.multicombo(label, selected, items)`
- `imgui.color_picker(label, color)`
- `imgui.same_line(offset, spacing)`
- `imgui.spacing(pixels)`
- `imgui.cursor(x, y)`
- `imgui.available()`
- `imgui.window_rect()`
- `imgui.begin_child(id, width, height, border_or_scroll)`
- `imgui.end_child()`
- `imgui.push_id(id)`
- `imgui.pop_id()`
- `imgui.push_style_color(name, color)`
- `imgui.pop_style_color()`
- `imgui.push_style_var(name, x, y)`
- `imgui.pop_style_var()`
- `imgui.push_font(font)`
- `imgui.pop_font()`
- `imgui.line(x, y, x2, y2, color, thickness)`
- `imgui.rect(x, y, width, height, color, rounding, thickness)`
- `imgui.rect_filled(x, y, width, height, color, rounding)`
- `imgui.blur(x, y, width, height, color, rounding)`
- `imgui.text_at(x, y, text, color, font)`
- `imgui.circle(x, y, radius, color, filled, thickness)`
- `imgui.image(texture, width, height)`
- `imgui.selectable(label, selected)`
- `imgui.separator()`
- `imgui.item_width(width)`
- `imgui.item_state()`
- `imgui.begin_group()`
- `imgui.end_group()`
- `imgui.begin_combo(label, preview)`
- `imgui.end_combo()`
- `imgui.tree_node(label)`
- `imgui.tree_pop()`
- `imgui.begin_tab_bar(id)`
- `imgui.end_tab_bar()`
- `imgui.begin_tab_item(label)`
- `imgui.end_tab_item()`
- `imgui.open_popup(id)`
- `imgui.begin_popup(id, width)`
- `imgui.end_popup()`
- `imgui.close_popup()`
- `imgui.begin_table(id, columns)`
- `imgui.end_table()`
- `imgui.next_column()`
- `imgui.next_row()`
- `imgui.tooltip(text)`
- `ui.style_colors(backend)`
- `ui.set_style_color(backend, name, color)`
- `ui.set_blur_opacity(surface, opacity)`
- `ui.reset_theme()`
