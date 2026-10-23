# FFI для авторов Lua-скриптов

Полный список вызовов: [API_INDEX.ru.md](API_INDEX.ru.md).
Дополнительные подробности и примеры собственного интерфейса DLL:
[FFI_DETAILS.ru.md](FFI_DETAILS.ru.md). Учебный маршрут Lua:
[AUTHORING.ru.md](AUTHORING.ru.md).

В новой пользовательской сборке скита доступен **cffi-lua** для **Lua 5.5**.
Он позволяет объявлять C-типы, загружать DLL и вызывать их экспортированные
функции из Lua. LuaJIT и его JIT-компилятор не добавлены. `api.version` остаётся
равным 2, поэтому наличие новой возможности проверяй непосредственно:

```lua
if type(ffi) ~= "table" then
    error("Для этого скрипта нужна сборка скита с FFI")
end
local ffi = require("ffi")
```

Глобальный `ffi`, `require("ffi")` и `require("cffi")` возвращают один встроенный
модуль. `require` принимает только эти два имени; поиск других Lua-файлов,
Lua-модулей и `package.path` не включён. Для IDE используй вместе
[api.lua](api.lua) и [ffi.lua](ffi.lua). Их не нужно запускать в ските.

FFI-вызовы выполняются в потоке Lua. В обновлённой сборке общий бюджет
обработчика — 250 ms / 20 миллионов VM-инструкций / 262144 единицы native work,
загрузки — 5000 ms. Эти пределы являются защитой от зависания, а не целевым
временем кадра. Блокирующий native-вызов нельзя остановить посередине;
его время учитывается при следующей проверке. Инициализацию DLL/устройства
и подготовку буферов выноси в загрузку. Наличие FFI не отключает watchdog Lua.

Локальное превышение теперь можно поймать через `api.protect` как код
`budget_exceeded`. Defaults — 1000000 VM-инструкций / 25 ms; остаток доступен
через `api.budget()`. Учёт прямых вызовов FFI, callbacks, host API и порядок
вложенных/общих лимитов: [BUDGETS.ru.md](BUDGETS.ru.md).

## Вызов функции DLL

```lua
local ffi = require("ffi")
ffi.cdef[[
    unsigned long __stdcall GetCurrentProcessId(void);
]]
local kernel = ffi.load("kernel32")
local process_id = tonumber(kernel.GetCurrentProcessId())
client.log("Process ID: " .. tostring(process_id))
```

`ffi.cdef` принимает C-декларации строкой. Препроцессор не работает: `#include`,
`#define` и другие директивы из заголовков нужно убрать. Объявляй точные типы
аргументов и результата. Для собственной DLL удобнее экспортировать C-функции
через `extern "C"`: это позволяет обращаться к ним по стабильным именам.

`ffi.load(name)` возвращает объект библиотеки, либо вызывает обычную Lua-ошибку
при неудаче. В Windows можно передать имя системной DLL или полный UTF-8 путь
к своей DLL. Простое имя без расширения дополняется `.dll`. Библиотека должна
подходить для процесса **Windows x64** и иметь доступные зависимости.
Папку `%LOCALAPPDATA%\skeet\native` можно использовать для внешних DLL, но FFI
не ограничен этой папкой. Переменные окружения в строке пути автоматически
не раскрываются: буквальная строка `"%LOCALAPPDATA%/skeet/native/foo.dll"`
не заменяет чтение переменной окружения.

Обычную ошибку загрузки можно обработать через `api.protect`:

```lua
local ffi = require("ffi")
local ok, reason, library = api.protect(function()
    return ffi.load("C:/my-plugin/plugin.dll")
end, {instructions = 50000, time_ms = 25})
if not ok then client.log("DLL: " .. tostring(reason)) end
```

Сохраняй объект библиотеки в локальной переменной на всё время её использования.
Инициализация DLL и нативный вызов могут занять время. Тяжёлую работу можно
выполнять в собственном рабочем потоке DLL, возвращая в Lua только данные;
callbacks из чужого потока в Lua недопустимы. `api.protect` не останавливает
уже начатый нативный вызов. Внешний пример libretro использует синхронные вызовы.

## Структуры, буферы и время жизни

```lua
local ffi = require("ffi")
ffi.cdef[[
    struct script_pixel { uint8_t r, g, b, a; };
]]
local pixel = ffi.new("struct script_pixel", {40, 130, 220, 255})
local bytes = ffi.new("uint8_t[4]", {pixel.r, pixel.g, pixel.b, pixel.a})
local rgba = ffi.string(bytes, 4)
assert(#rgba == 4)
```

Массивы `cdata` индексируются с **0**, таблицы Lua — с 1. `ffi.string(ptr, length)`
копирует заданное число байт в строку Lua, включая нулевые байты. Без `length`
функция читает до первого нулевого байта: этот режим подходит для C-строк,
но не для кадров или произвольных двоичных данных.

Если DLL сохраняет переданный указатель после возвращения из функции, удерживай
сам буфер Lua до момента, когда DLL перестанет его использовать. Один указатель
после `ffi.cast` не заменяет владение исходным объектом. Перед выгрузкой скрипта
нужно остановить нативную работу, освободить её ресурсы и отключить callbacks.
Для нормальной выгрузки есть событие `shutdown`; для `cdata` можно дополнительно
назначить `ffi.gc(value, finalizer)`. `ffi.gc(value, nil)` снимает финализатор.
Обработчик `shutdown` не заменяет очистку при ошибке Lua: используемый ресурс
должен иметь отдельный способ завершения.

## Основные функции

| Вызов | Назначение |
|---|---|
| `ffi.cdef(text)` | Объявить C-типы, структуры и функции |
| `ffi.load(name)` / `ffi.C` | Явная DLL / системное пространство C-символов |
| `ffi.new(type, ...)` | Создать `cdata`; для `uint8_t[?]` передать длину |
| `ffi.typeof(type)` | Получить переиспользуемый `ctype` |
| `ffi.cast(type, value)` | Преобразовать тип, в том числе тип указателя |
| `ffi.metatype(type, table)` | Задать Lua-метаметоды для поддерживаемого C-типа |
| `ffi.gc(value, fn)` | Назначить финализатор |
| `ffi.sizeof(type)` / `ffi.alignof(type)` | Размер / выравнивание |
| `ffi.offsetof(type, field)` | Смещение поля, либо `nil` |
| `ffi.istype(type, value)` | Проверить C-тип |
| `ffi.string(ptr, length)` | Скопировать байты в строку Lua |
| `ffi.copy(dst, src, length)` | Скопировать байты между буферами |
| `ffi.fill(dst, length, byte)` | Заполнить буфер, по умолчанию нулями |
| `ffi.errno()` | Получить `errno` последнего C-вызова |
| `ffi.abi(flag)` | Проверить свойство ABI, например `64bit` или `win` |
| `ffi.os` / `ffi.arch` | Название ОС / архитектуры |
| `ffi.tonumber(value)` | Преобразовать числовой `cdata`; возможна потеря точности |
| `ffi.nullptr` | Нулевой указатель для сравнения с `cdata` |
| `ffi.addressof(value)` / `ffi.toretval(value)` | Дополнения cffi-lua для адресов / преобразования результата |
| `ffi.eval(text)` / `ffi.type(value)` | Дополнения cffi-lua: разбор числового литерала / тип с учётом `cdata` |

Это совместимость с большой частью LuaJIT FFI, а не обещание полной
взаимозаменяемости. Используй `ffi.nullptr`; имя `ffi.NULL` этой реализацией
не добавлено. Обычные `type` и `tonumber` не заменены автоматически;
для `cdata` доступны `ffi.type` и `ffi.tonumber`.
Подробности: сохранённые [API](ffi-reference/api.md),
[семантика](ffi-reference/semantics.md) и
[синтаксис деклараций](ffi-reference/syntax.md).

## Динамические изображения

Для видео и другого меняющегося изображения добавлены две функции:

- `render.create_texture_rgba(width, height)` → `handle` либо `nil, reason`.
- `render.update_texture_rgba(handle, bytes)` → `true` либо `nil, reason`.
- `render.update_texture_pixels(handle, bytes, format[, pitch])` → `true` либо `nil, reason`.

Оба вызова доступны только в `paint`. Создай текстуру один раз, обновляй её
перед рисованием и передавай ровно `width*height*4` байт в порядке **RGBA**.
Повторный вызов `render.setup_texture_rgba` на каждом кадре создаёт новые
записи неизменяемого кеша; для видео нужен именно изменяемый handle.

Если библиотека отдаёт BGRA/BGRX или 16-битные RGB565/RGB555, используй
`render.update_texture_pixels` с её форматом и шагом строки. Скопируй нужные
байты через `ffi.string` до окончания срока жизни framebuffer.
Подробные размеры и форматы — в [EXTENSIONS.ru.md](EXTENSIONS.ru.md).

```lua
local texture
events.on("paint", function()
    if not texture then
        local reason
        texture, reason = render.create_texture_rgba(64, 64)
        if not texture then client.log(tostring(reason)); return end
    end
    local channel = math.floor((math.sin(client.time()) + 1) * 127.5)
    local rgba = string.rep(string.char(channel, 80, 150, 255), 64 * 64)
    local ok, reason = render.update_texture_rgba(texture, rgba)
    if not ok then client.log(tostring(reason)); return end
    render.texture(texture, 40, 40, 128, 128)
end)
```

Размеры: 1–4096 по каждой стороне, не больше 1 048 576 пикселей на текстуру.
Общие лимиты ресурсов остаются: 64 текстуры, 8 388 608 пикселей, 32 MiB
исходных байтов ресурсов. Handle принадлежит создавшему его скрипту.
После выгрузки GPU view сохраняется для отложенных команд рендера, а свободный
слот того же размера можно переиспользовать. Перезагрузка одинаковой игры
не должна создавать отдельную текстуру на каждый кадр или каждый Reload.

## Границы исполнения и проверка

FFI предоставляет прямой нативный доступ: неверная декларация, обращение
к освобождённой памяти или авария DLL могут завершить процесс. Лимиты Lua
не прерывают нативный код и не учитывают всю выделенную им память.
`api.protect` обрабатывает обычные Lua-ошибки, но не исправляет ошибки указателей
и не изолирует DLL. Callback в Lua можно вызывать только синхронно из потока,
который сейчас выполняет соответствующий Lua state. Рабочий поток DLL должен
передавать данные через свой буфер/очередь; обращаться из него к Lua, `render`
или остальному API скита нельзя.

Для проверки после пользовательской сборки есть
[ffi_smoke.lua](tests/ffi_smoke.lua): вызов функции Windows, структура, массив,
строка и изменяемая текстура. Пример полноценного потребителя FFI:
[doom.lua](games/doom.lua), [инструкция Doom](games/DOOM.ru.md).
Офлайн-проверки и их ограничения описаны в [VALIDATION.ru.md](VALIDATION.ru.md).
