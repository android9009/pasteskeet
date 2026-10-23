# Настройки каждого оружия

Изменение клиента от 16.10.2026; API остаётся версии 2 (добавление совместимо),
формат новых конфигов и кодов обмена — версия 3.

В Ragebot и Legitbot список Weapon содержит 34 отдельных огнестрельных оружия.
AWP, SSG 08, SCAR-20 и G3SG1 имеют независимые настройки, как и каждый пистолет,
автомат, дробовик и пулемёт. Выбор в меню редактирует профиль; во время игры бот
использует профиль оружия в руках. Общие переключатели ботов остаются общими.
Zeus, ножи и гранаты в этот список не входят.

## Lua

`settings.weapon_profiles()` доступна сразу при загрузке файла и возвращает
массив из 34 записей в порядке меню. Поля записи: `item_id` (числовой item definition
index), `key` (стабильный ключ), `name` (название), `legacy_group` (прежний класс),
`rage_category` и `legit_category` (готовые категории настроек).

Используй категории из каталога с обычными `settings.get`, `settings.set`,
`settings.override` и `settings.bind`. Имена полей остались прежними;
`settings.list("ragebot - awp")` и панель Settings API во встроенном редакторе
показывают реальные поля. Имена категорий не зависят от языка меню.

```lua
-- Постоянные изменения только для указанного оружия:
settings.set("ragebot - awp", "min damage", 90)
settings.set("ragebot - ssg08", "min damage", 75)
settings.set("legitbot - deagle", "fov", 3.0)
settings.bind("legitbot - deagle", "aimbot", 0x05, 1)

-- Каталог можно один раз индексировать при загрузке файла:
local by_id = {}
for _, profile in ipairs(settings.weapon_profiles()) do
    by_id[profile.item_id] = profile
end
events.on("pre_rage", function()
    local context = combat.context()
    local profile = context.valid and by_id[context.item_id] or nil
    if profile and profile.key == "scar20" then
        settings.override(profile.rage_category, "min damage", 60)
    end
end)
```

`combat.context()` требует командного callback; `item_id` также есть у
`entity.weapon(index)`. Возвращаемый `weapon_type` по-прежнему означает игровой
класс, а не индекс профиля. Внутри `rage_targets/scan/select/fire/shot` менять
настройки и бинды нельзя; используй `pre_rage` или `pre_legit`.

Готовый пример выбора конкретного оружия и временного изменения урона:
[damage_override.lua](examples/damage_override.lua). Он снимает старый override
при переключении выбора; при выключении или ошибке скрипта overrides снимаются
автоматически.

## Совместимость и конфиги

Новые конфиги и коды обмена имеют версию 3 и сохраняют каждое оружие отдельно,
включая значения, массивы хитбоксов, цвета и бинды. Старые полные конфиги и коды
версий 1/2 импортируются: каждое поле прежнего класса копируется всем оружиям
этого класса. Например, `sniper` переносится на SSG 08, AWP, G3SG1 и SCAR-20.
Если файл содержит и старое поле класса, и новое поле конкретного оружия,
новое имеет приоритет для этого поля. Отсутствующие поля сбрасываются к обычной
базе загрузки; настройки предыдущего конфига не остаются. Старые версии клиента
не смогут прочитать новые оружейные профили.

Старые Lua-категории `ragebot - pistol/smg/rifle/sniper/shotgun/lmg` и
`legitbot - pistol/smg/rifle/sniper/shotgun/lmg` остаются совместимыми псевдонимами:

- `set`, `override` и назначение `bind` применяются ко всем оружиям класса;
- `override(..., nil)` снимает overrides этого скрипта со всего класса;
- `get` и чтение `bind` возвращают оружие в руках, если командный контекст валиден
  и оружие относится к запрошенному классу; иначе — первое оружие класса в меню;
- `settings.list()` и `settings.binds()` показывают конкретные категории оружия.

Для новых скриптов используй конкретные категории: чтение старого класса
не может представить разные значения всех его оружий одним значением.

## Полный каталог

К категориям ниже добавляется префикс `ragebot - ` либо `legitbot - `.

| Оружие | Ключ категории | item_id | Прежний класс |
|---|---|---:|---|
| Desert Eagle | `deagle` | 1 | `pistol` |
| Dual Berettas | `elite` | 2 | `pistol` |
| Five-SeveN | `fiveseven` | 3 | `pistol` |
| Glock-18 | `glock` | 4 | `pistol` |
| P2000 | `hkp2000` | 32 | `pistol` |
| P250 | `p250` | 36 | `pistol` |
| Tec-9 | `tec9` | 30 | `pistol` |
| USP-S | `usp_silencer` | 61 | `pistol` |
| CZ75-Auto | `cz75a` | 63 | `pistol` |
| R8 Revolver | `revolver` | 64 | `pistol` |
| MAC-10 | `mac10` | 17 | `smg` |
| MP9 | `mp9` | 34 | `smg` |
| MP7 | `mp7` | 33 | `smg` |
| MP5-SD | `mp5sd` | 23 | `smg` |
| UMP-45 | `ump45` | 24 | `smg` |
| P90 | `p90` | 19 | `smg` |
| PP-Bizon | `bizon` | 26 | `smg` |
| AK-47 | `ak47` | 7 | `rifle` |
| M4A4 | `m4a1` | 16 | `rifle` |
| M4A1-S | `m4a1_silencer` | 60 | `rifle` |
| AUG | `aug` | 8 | `rifle` |
| SG 553 | `sg556` | 39 | `rifle` |
| FAMAS | `famas` | 10 | `rifle` |
| Galil AR | `galilar` | 13 | `rifle` |
| SSG 08 | `ssg08` | 40 | `sniper` |
| AWP | `awp` | 9 | `sniper` |
| G3SG1 | `g3sg1` | 11 | `sniper` |
| SCAR-20 | `scar20` | 38 | `sniper` |
| Nova | `nova` | 35 | `shotgun` |
| XM1014 | `xm1014` | 25 | `shotgun` |
| MAG-7 | `mag7` | 27 | `shotgun` |
| Sawed-Off | `sawedoff` | 29 | `shotgun` |
| M249 | `m249` | 14 | `lmg` |
| Negev | `negev` | 28 | `lmg` |
