# Бюджеты Lua и FFI

В обновлённой сборке `api.protect` возвращает исчерпание бюджета как
`false, "budget_exceeded", info`. Код сравнивается целиком, без поиска по
traceback. То же значение доступно как `api.error_codes.budget_exceeded`.
`api.budget()` и поле `client.stats().budget` показывают остаток.
Изменение требует пользовательской пересборки скита.
`api.version` остаётся 2; для проверки наличия новых возможностей используй
`type(api.budget) == "function"` и наличие `api.error_codes`.

## Иерархия

| Уровень | Время | VM-инструкции | Native work |
|---|---|---|---|
| Загрузка | 5000 ms | 20000000 | 262144 |
| Dispatch события, все его обработчики вместе | 250 ms | 20000000 | 262144 |
| `rage_*` | Дополнительно 64 ms / 4096 вызовов на команду | Общий dispatch budget | Общий dispatch budget |
| `api.protect`, defaults | 25 ms | 1000000 | Общий счётчик dispatch |
| Явные пределы `api.protect` | > 0 .. 250 ms | 1000 .. 20000000 | Общий счётчик dispatch |

Эффективный предел вложенного вызова — минимум его запроса и остатка родителя.
`protect` не обнуляет инструкции, native work или прошедшее время dispatch.
До восьми уровней вложенности. Для `rage_*` потраченное время команды уменьшает
остаток следующего вызова. Прежние defaults 50000 / 2 ms заменены на 1000000 / 25 ms.

## Что считается

**Инструкции** — инструкции VM Lua, а не строки исходника и не инструкции CPU.
Счётчик увеличивается по 1000 на VM-hook, поэтому показатели приблизительные.
Lua-функция внутри FFI callback использует тот же счётчик. Внутренние инструкции
DLL в него не входят.

**Native work** — входы в API скита и узлы преобразования Lua-таблиц в данные API.
Вход увеличивает также `api_calls`. Запрос бюджета/статистики тоже является
API-вызовом. Это не количество трассировок или CPU-инструкций алгоритма.

`combat.hitchance` проходит через общий `guarded` wrapper: вход учитывается
в `native_work` и `api_calls`, преобразование аргументов может добавить native work.
Внутренняя проверка 256 samples не добавляет 256 единиц native work и не становится
Lua-инструкциями. Её длительность учитывается во времени. Отдельно действует
предел 32 запросов hitchance за команду, общий с `ragebot.hitchance`; его ошибка
является обычной ошибкой API, а не `budget_exceeded`. Пустые/неверные запросы
также расходуют эту квоту.

**Время** — wall time, включая прямую работу/ожидание DLL через FFI, а не CPU/GPU
профиль. Начатый native-вызов нельзя прервать посередине; превышение обнаруживается
на следующем hook/API или после возврата из `protect`, даже если hook не сработал.
Прямые вызовы cffi-lua автоматически не прибавляются к `api_calls/native_work`,
но их время учитывается; Lua callbacks внутри них добавляют VM-инструкции.
Ожидания встроенного `audio.*` получают существующий time credit; прямой `winmm`
через FFI такого исключения не получает.

## Ошибка и повтор

`info.kind`: `"instructions"`, `"time"` или `"native_work"`.
`info.scope`: `"protect"` или `"dispatch"`.
`info.retryable`: можно ли повторить в текущем dispatch; это не гарантия, что задача
поместится в остаток. При обычной ошибке сохраняется `false, traceback`.
При успехе сохраняется `true, nil, ...results`, включая промежуточные/последние nil.

```lua
local function calculate()
    local sum = 0
    for i = 1, 10000 do sum = sum + i end
    return sum
end
local ok, err, value = api.protect(calculate, {instructions = 1000})
if not ok and err == api.error_codes.budget_exceeded then
    if not value.retryable then return end
    local left = api.budget()
    if left.instructions_remaining < 200000 or left.time_remaining_ms < 5 then return end
    ok, err, value = api.protect(calculate, {instructions = 200000, time_ms = 25})
end
if ok then client.log(value) else client.log(err) end
```

После локального исчерпания родитель восстанавливается: можно продолжить,
повторить с большим пределом или отказаться. Исчерпанный внешний `protect`
не скрывается внутренним: ошибка проходит наружу до уровня с оставшимся бюджетом.

Если весь dispatch исчерпан **внутри `protect`**, возвращаются `scope = "dispatch"`
и `retryable = false`. Скрипту даётся один запас на обработку результата:
10 ms, 20000 инструкций, 256 native work сверх уже использованного.
Следует сохранить состояние и **завершить callback**. Продолжать работу можно
в следующем событии. Новые `protect` в этом состоянии не запускают переданную
функцию и возвращают ту же ошибку. Запас не пополняется повторными попытками;
его исчерпание остаётся фатальным с кодом `budget_exceeded`.

Непойманный перерасход вне `protect`, ошибки памяти/allocator и повреждение
обработчика ошибок остаются фатальными. `pcall`/`xpcall` не предоставлены.
Access violation или зависание DLL не превращаются в Lua-ошибку.
Повтор не откатывает побочные эффекты: сохраняй прогресс и обеспечивай безопасный
повтор операций изменения состояния самостоятельно.

## Остановиться заранее

| Поле `api.budget()` / `client.stats().budget` | Тип и смысл |
|---|---|
| `instructions_remaining` | integer ≥ 0; остаток эффективного scope, приблизительно по 1000 |
| `time_remaining_ms` | number ≥ 0; миллисекунды до эффективного deadline |
| `native_work_remaining` | integer ≥ 0; общий остаток API/conversion work |
| `dispatch_instructions_remaining` | integer ≥ 0; остаток общего родителя |
| `dispatch_time_remaining_ms` | number ≥ 0; время общего родителя |
| `protect_depth` | integer; текущая вложенность protect |
| `recovering` | boolean; общий бюджет пойман и действует только запас на завершение |
| `retryable` | boolean; общий бюджет ещё не исчерпан, задача не получает резерв |

```lua
local tasks, next_task = {}, 1
events.on("paint", function()
    while next_task <= #tasks do
        local left = api.budget()
        if left.recovering or left.instructions_remaining < 10000
            or left.native_work_remaining < 64 or left.time_remaining_ms < 5 then return end
        local ok, err = api.protect(tasks[next_task])
        if not ok then
            if err ~= "budget_exceeded" then client.log(err) end
            return
        end
        next_task = next_task + 1
    end
end)
```

Текущие остатки относятся к эффективному scope; `dispatch_*` — к общему родителю.
`protect_depth` показывает вложенность, `recovering` — запас на завершение.
В recovery текущие остатки равны нулю, `retryable = false`. Снимок не резервирует
ресурсы: проверяй с запасом, поскольку сам запрос и следующие операции расходуют бюджет.

Офлайн: `python -B tools/verify_lua_protect.py` выполняет реальный C++ AST с моками
часов и стека Lua. Это не компиляция и не проверка native Lua/FFI unwind в игре.
Ручные пробы: `tests/protect_budget_retry.lua`, `tests/protect_nested_budget.lua`,
`tests/protect_dispatch_budget.lua`.
