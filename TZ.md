# ТЗ — TempleEx

**Техническое задание на разработку TempleEx — self-contained cheat-hub для Roblox**
Версия документа: 0.3 (draft) · Статус: на согласовании · Объём: только спецификация, без реализации
Изменения в 0.3: добавлены §8 Shell (WM + menu bar + dock) и §13 Автозагрузка скриптов; конфиг `shell:`/`scripts:` в §6; расширения TempleApi и токенов темы.

---

## 1. Общие сведения

### 1.1 Название
**TempleEx** (Temple Executor). Внутренний API для скриптов — **TempleApi**. Встроенные чит-функции — **Temple.Core**. Оболочка рабочего стола — **Temple.Shell**. Формат тем — **TempleTheme (.yaml)**. Репозиторий-дом — GitHub (`TempleEx/TempleEx`, имя-заглушка).

### 1.2 Назначение
TempleEx — альтернатива Infinity Yield: **готовый чит-хаб**, а не просто UI-библиотека. Юзер делает ровно одно действие:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/TempleEx/TempleEx/main/TempleEx.lua"))()
```

— и получает:

1. **Встроенные базовые функции** (fly, speed, ESP, noclip, infinite jump и др., §7) — работают сразу, ничего докачивать не надо.
2. **GUI-фреймворк** для своих скриптов поверх TempleApi (окна, вкладки, кейбинды, таблицы, уведомления).
3. **Встроенный «рабочий стол» (Temple.Shell, §8)**: оконный менеджер (snap/tiling/workspaces), menu bar сверху и dock снизу, который выезжает при наведении мыши к нижней кромке экрана. TempleEx ощущается как мини-DE внутри игры — прямая аналогия с Omarchy.
4. **Автозагрузку скриптов (§13)**: помеченные скрипты из `plugins/` стартуют вместе с хабом, сессионное восстановление и перезапуск после rejoin.
5. **Управление одним YAML-файлом** (`temple.yaml`) — весь хаб настраивается без правок кода.
6. **Темы как в Omarchy**: папка `workspace/themes/`, каждая тема — один `.yaml`, переключение на лету прямо из GUI внутри игры; теме подчиняются и окна, и shell.
7. **AI-агенты для тем**: промпт в GUI → сгенерированный валидный YAML темы → мгновенное применение.
8. **Git-native экосистема**: загрузчик, обновления, темы и реестр скриптов живут в GitHub raw / Releases (§11).

### 1.3 Позиционирование / отличия от Infinity Yield
| Infinity Yield | TempleEx |
|---|---|
| Фиксированный вид, 2–3 встроенные темы | Темы = YAML-файлы, hot-swap из GUI, AI-генерация |
| Окна: перетаскивание и всё | **Полноценный WM**: snap, tiling, workspaces, switcher, dock + menu bar |
| Конфиг размазан по настройкам GUI | Единый `temple.yaml` как источник истины |
| Загрузка через свой лончер/линк, обновления «как получится» | Однострочный raw-GitHub запуск + `Temple.Update()` из git-тегов |
| Плагины/скрипты — только его формат | Реестр скриптов = git-репозитории: `Temple.Hub.pull(repo)` |
| Нет автозагрузки своих скриптов как системы | Autoload + session restore + rejoin-relaunch (§13) |
| API нестабилен между версиями | Версионированный TempleApi (semver) + `IYCompat` для переноса IY-скриптов |

### 1.4 Целевая аудитория
- Roblox-эксплойтеры, которым нужен «всё в одном» хаб на один loadstring.
- Scripters, пишущие свои скрипты поверх TempleApi и публикующие их в git.
- Комьюнити тем: генерация AI-агентами, обмен YAML-файлами, PR в реестр тем.

---

## 2. Цели и не-цели

### 2.1 Цели (обязательно к поставке)
- G1. **Один loadstring = рабочий хаб**: встроенные функции + GUI без каких-либо действий юзера (кроме вставки строки).
- G2. Набор встроенных функций v1 (§7): fly, speed, infinite jump, noclip, ESP, fullbright, hitbox, freecam, unanchor, respawn-lock — минимум.
- G3. GUI-фреймворк не хуже IY по функциональности (окна/вкладки/секции/элементы/уведомления/кейбинды/комманд-палитра).
- G4. **Temple.Shell**: WM (focus/z-order/minimize/maximize/snap/tiling/workspaces) + menu bar сверху + dock снизу с reveal по наведению мыши (§8).
- G5. **Автозагрузка скриптов**: autoload из `plugins/`, восстановление сессии, перезапуск после rejoin (§13).
- G6. Единый конфиг `temple.yaml`; любое изменение из GUI пишется обратно в него.
- G7. Темы Omarchy-style: `workspace/themes/*.yaml`, hot-swap ≤ 50 мс, превью, редактор, watchdog; теме подчиняются окна **и shell**.
- G8. AI-агенты тем: промпт → валидный YAML → применение; итеративный tweak.
- G9. TempleApi — стабильный версионированный Lua-API, открывающий встроенные функции (`Temple.Fly:Set(...)`) и shell (`Temple.Shell:*`).
- G10. **Git-совместимость**: репозиторий, релизы, raw-ссылки, реестры тем/плагинов, автообновление — всё через GitHub (§11).
- G11. Совместимость минимум с 3 популярными executor'ами (§3.3).

### 2.2 Не-цели (v1 вне скоупа)
- Автоаим/silent-aim, анти-кик «неубиваемый», автофарм под конкретные игры — осознанно вне v1 (политика: только универсальные функции; пересматривается v2).
- Управление окнами на уровне ОС (вне Roblox-экрана), мульти-монитор сценарии.
- Мобильные executor'ы (Android) — только Windows-стек в v1.
- Нативный редактор тем вне игры (редактор = внутриигровой GUI + YAML).
- Собственный web-хостинг реестров — только git-хостинг (GitHub в приоритете, Gitee/Codeberg — фолбэки).

---

## 3. Требования к платформе

### 3.1 Среда исполнения
- Lua 5.1 / Luau-совместимый рантайм executor'а.
- Рендер GUI: гибрид `ScreenGui/SurfaceGui` + `Drawing` API; приоритет примитивов из `temple.yaml → temple.ui_mode`.

### 3.2 Workspace и структура файлов
```
workspace/
├── temple.yaml              # ЕДИНЫЙ конфиг (см. §6)
├── TempleEx.lua             # локальный кэш лоадера (см. §5)
├── themes/                  # ВСЕ темы, по одной на .yaml
│   ├── default.yaml
│   └── midnight-temple.yaml
├── plugins/                 # скрипты юзера (autoload, §13)
├── cache/                   # превью тем, кэш AI, сессии, окна WM, бэкапы
│   └── configs/             # windows.json, session.json, teleport.json, <script_id>.json
└── logs/temple.log
```

### 3.3 Executor-совместимость (v1)
| Executor | Статус | Примечание |
|---|---|---|
| Wave | must | эталонный: `workspace/`, `request`, `queue_on_teleport` |
| Codex | must | |
| Hydrogen / Potassium / Swift | should | через фасад `Temple.Executor` (§10.2) |
| прочие | nice | best-effort |

Ни один модуль не вызывает executor-специфичные функции напрямую — только через `Temple.Executor` с фолбэками. Встроенные функции (§7) обязаны деградировать, а не падать: нет функции — в GUI статус «unsupported on this executor».

---

## 4. Архитектура

```
            loadstring(game:HttpGet(raw.githubusercontent/.../TempleEx.lua))()
                                      │
                                      ▼
┌─────────────────────────────  BOOTLOADER (§5)  ─────────────────────────────┐
│  детект executor'а · кэш в workspace/ · зеркала · проверка версии           │
└───────────────┬─────────────────────────────────────────────────────────────┘
                ▼
┌────────────────────────── temple.yaml (config) ──────────────────────────┐
│                                                                           │
│  ┌───────────┐   ┌──────────────┐   ┌─────────────┐   ┌───────────────┐  │
│  │  Kernel   │──▶│  ThemeEngine │──▶│ Temple.Shell│◀──│  AI Agents    │  │
│  │ (boot,    │   │ (load/merge/ │   │  WM+MenuBar │   │  (theme-gen,  │  │
│  │  config,  │   │  hot-swap,   │   │  +Dock+Hub  │   │   refine,     │  │
│  │  fs)      │   │  validate)   │   │  (windows,  │   │   audit)      │  │
│  └─────┬─────┘   └──────▲───────┘   │   picker)   │   └──────▲────────┘  │
│        │                │           └──────▲──────┘          │           │
│        ▼                │                  │                 ▼           │
│  ┌───────────┐   ┌──────┴───────┐   ┌─────┴────┐     ┌────────────┐      │
│  │Temple.Core│◀─▶│ TempleApi    │   │ FS       │◀────│ LLM bridge │      │
│  │ fly/speed │   │ (для своих   │   │(themes/, │     │ (request/  │      │
│  │ esp/noclip│   │  скриптов)   │   │ yaml)    │     │  proxy)    │      │
│  │ +flags/   │   └──────────────┘   └──────────┘     └────────────┘      │
│  │  binds    │              ▲                                             │
│  └───────────┘   ┌──────────┴─────────┐                                   │
│                  │ Autoload (§13)     │◀── plugins/ + Temple.Hub (§11)    │
│                  └────────────────────┘                                   │
└───────────────────────────────────────────────────────────────────────────┘
```

Модули (исходники раздельные, релиз — single-file build):

1. **Bootloader** — §5.
2. **Kernel** — парсинг `temple.yaml`, детект executor'а, FS-абстракция, логирование, `Temple.reload()`.
3. **Temple.Core** — встроенные функции (§7): каждая = модуль с флагом, кейбиндом, записью в комманд-палитру.
4. **ThemeEngine** — YAML-темы, валидация, слияние, токены, hot-swap.
5. **Temple.Shell** — WM + menu bar + dock + вкладки хаба (§8). Единый менеджер всех окон — и своих, и скриптовых.
6. **TempleApi** — публичный фасад (§10).
7. **Autoload** — загрузка/восстановление сессий скриптов (§13).
8. **AI Agents** — §12.
9. **LLM bridge** — HTTP через `request` executor'а, провайдеры из `temple.yaml → ai`.
10. **Hub/Git layer** — реестры и обновления (§11).

Принципы:
- **Data-driven**: GUI строится из токенов темы; виджет не хранит цвет «в коде».
- **Reactive**: смена токена → подписанные виджеты (и shell) перекрашиваются за один проход.
- **Single source of truth**: состояние = `temple.yaml` + тема + `cache/configs/`.
- **Feature = флаг + бинд + команда + иконка дока**: каждая встроенная функция автоматически получает Toggle в GUI, Keybind, запись в комманд-палитру и слот в доке из одного декларативного описания.

---

## 5. Запуск: один loadstring (Bootloader)

### 5.1 Контракт
- **R5.1** Официальная строка запуска — ровно одна, публичная, стабильная:
  ```lua
  loadstring(game:HttpGet("https://raw.githubusercontent.com/TempleEx/TempleEx/main/TempleEx.lua"))()
  ```
- **R5.2** `TempleEx.lua` в корне репо — **bootloader** (≤ 15 КБ), а не вся библиотека: он резолвит релиз, кэширует полный билд и исполняет его. Полный билд `TempleEx-full.lua` лежит в GitHub Releases (raw-ссылка на тег).
- **R5.3** Зеркала (порядок фолбэков настраивается в `temple.yaml → git.mirrors`): `raw.githubusercontent.com` → `cdn.jsdelivr.net/gh/...` → `gitee`/`codeberg` mirror → локальный кэш `workspace/TempleEx.lua`.
- **R5.4** Кэш: успешно загруженный полный билд пишется в `workspace/TempleEx.lua`; при недоступности сети хаб стартует с кэша + warning-уведомление «offline mode, vX.Y».
- **R5.5** Версионирование ссылки: `?v=1.2.3` или путь `releases/download/v1.2.3/` поддерживаются; `main` = всегда latest stable.
- **R5.6** Идемпотентность: повторный loadstring в том же плейсе не дублирует хаб, а возвращает существующий `Temple` (и, опционально, открывает GUI).
- **R5.7** Boot ≤ 1.5 с cold (с сети), ≤ 0.5 с с кэша. Ошибка загрузки → чистое `error()` с текстом и списком зеркал, без полудохлого GUI.
- **R5.8** Анти-«сгоревшая ссылка»: README репо и `temple.yaml → git.entry_url` содержат каноническую строку; bootloader при 404 на всех зеркалах печатает актуальную строку из кэша.

---

## 6. Единый конфиг `temple.yaml`

**R6.1** Весь пользовательский контроль хабом — через один файл. Никаких `config.json`/реестров внутри игры.

```yaml
# workspace/temple.yaml
version: 1

temple:
  entry_key: "RightCtrl"        # открыть/закрыть ВСЕ окна (свернуть shell)
  ui_mode: hybrid               # drawing | surface | hybrid
  language: ru

shell:                          # §8
  wm:
    snap: true                  # прилипание к краям/четвертям
    tiling: false               # авто-раскладка окон (off | columns | grid)
    workspaces: 3               # 0 = отключить
    switcher_key: "Alt+Tab"     # переключатель окон
    remember: true              # позиции/размеры в cache/configs/windows.json
  menubar:
    enabled: true
    height: 24
    autohide: false             # скрывать, когда нет фокусных окон
    items: [menu, title, clock, fps, executor, theme, tray, binds]
  dock:
    enabled: true
    position: bottom            # v1: bottom; left/right — v1.1
    reveal: hover               # hover | always | key("F4")
    reveal_zone: 4              # px от кромки экрана, за которые dock выезжает
    hide_delay: 0.4             # с после ухода мыши
    icon_size: 40
    magnify: true               # увеличение иконок под курсором
    pins: [fly, esp, speed, themes, ai, scripts]

scripts:                        # §13
  autoload: true                # глобальный master-switch
  restore_session: true         # вернуть скрипты, работавшие до закрытия
  rejoin_relaunch: true         # перезапуск через queue_on_teleport
  watch_folder: true            # новые .lua в plugins/ видны ≤ 3 с
  stagger: 200                  # мс между стартами autoload-скриптов

git:
  repo: TempleEx/TempleEx
  channel: stable               # stable | canary
  auto_update: true
  mirrors:
    - https://raw.githubusercontent.com
    - https://cdn.jsdelivr.net/gh
  registries:                   # §11.3
    themes: TempleEx/themes
    scripts: TempleEx/hub-index

theme:
  active: midnight-temple       # имя = themes/<имя>.yaml
  fallback: default
  auto_reload: true             # watchdog за themes/ (2 с)
  accent_override: null

paths:
  workspace: auto
  themes: themes
  plugins: plugins

functions:                      # состояние встроенных функций (§7)
  fly:     { enabled: false, speed: 50, keybind: "E" }
  speed:   { enabled: false, multiplier: 2, keybind: "Q" }
  esp:     { enabled: false, players: true, boxes: false }

plugins:                        # конкретные скрипты и их autoload (§13)
  - name: esp-suite
    file: plugins/esp.lua       # локальный файл ИЛИ git-ссылка (§11.3)
    autoload: true
  - name: speed-hack
    file: plugins/speed.lua
    autoload: false

ai:
  provider: openai-compatible   # openai-compatible | anthropic | local-ollama | custom
  base_url: https://api.openai.com/v1
  model: gpt-4o-mini
  api_key_env: TEMPLE_AI_KEY
  agents:
    theme-gen:    { model: inherit, temperature: 0.9 }
    theme-refine: { model: inherit, temperature: 0.4 }
    config-audit: { model: inherit, temperature: 0.0 }

behavior:
  notify_default: { duration: 5, position: top-right }
  window_default: { size: [520, 380] }
  stealth:
    gui_name_prefix: null
    anti_screenshot: false
```

- **R6.2** Валидация по JSON Schema (`schema/temple.schema.json` в репо). Ошибка → лог + уведомление, запуск с дефолтами.
- **R6.3** Любое изменение из GUI (тема, тумблер функции, pin дока, autoload скрипта) пишется обратно в `temple.yaml` с сохранением комментариев где возможно; перед первой записью — `cache/temple.yaml.bak`.
- **R6.4** YAML-парсер — встроенный подмножество-YAML (block styles, scalars, lists, maps, comments).

---

## 7. Встроенные функции (Temple.Core)

### 7.1 Набор v1
Все функции — универсальные (не привязаны к игре), каждая имеет GUI-карточку в вкладке **Functions**, флаг в `temple.yaml → functions`, опциональный кейбинд, запись в комманд-палитру и слот в доке (§8.4).

| Функция | Параметры (v1) | Примечание |
|---|---|---|
| **Fly** | speed, vertical speed, WASD + Space/C, bypass-режимы | эталонная: `LinearVelocity`/`BodyVelocity` с автовыбором под executor |
| **Speed** | multiplier, mode (walkspeed / humanoid / velocity) | авто-возврат при выключении |
| **Infinite Jump** | delay | |
| **Noclip** | — | `CanCollide=false` тик-листер |
| **ESP** | players/containers/npcs, boxes, names, distance, chams, tracers, team-coloring | Highlight/BoxAdornment + `Drawing` |
| **Fullbright** | brightness, clock-time, fog off | |
| **Hitbox Expander** | size, transparency, show | |
| **Freecam** | speed, keybind | |
| **Unanchor / Respawn Lock / No Fall** | — | простые тумблеры |
| **Teleport** | точки (save/goto), к игроку | `cache/configs/teleport.json` |
| **Player List** | kick self, view info | контекстная таблица |

### 7.2 Требования к функциям
- **R7.1** Каждая функция = декларативный модуль `{ id, title, icon, params, defaults, on_enable, on_disable, on_param }`; ядро само генерирует Toggle/Slider/Keybind/команду/иконку дока. Добавление функции не требует правок GUI-кода.
- **R7.2** Состояние персистится в `temple.yaml → functions`; после `Temple.reload()` или rejoin функции восстанавливаются.
- **R7.3** Все функции доступны из TempleApi: `Temple.Fly:Set("speed", 80)`, `Temple.ESP:AddFilter(fn)`.
- **R7.4** Деградация вместо падения: неподдерживаемый приём → статус `unsupported`, тумблер заблокирован с tooltip, хаб жив.
- **R7.5** Тики функций — один общий `RunService`-цикл ядра; idle-затраты выключенных функций = 0.
- **R7.6** Никаких per-game exploits; список расширяется через RFC-PR в репо.

---

## 8. Temple.Shell — WM, Menu Bar, Dock

### 8.1 Концепция
Temple.Shell — оболочка рабочего стола внутри игрового экрана, развивающая аналогию с Omarchy до конца: не только темы, но и **окружение**. Состоит из трёх частей:

- **WM (window manager)** — единый менеджер всех окон хаба и сторонних скриптов;
- **Menu Bar** — полоса сверху (статус, быстрые действия, трей);
- **Dock** — панель снизу, **выезжающая при наведении мыши к нижней кромке экрана** (reveal-зона настраивается), с пинами функций, скриптов и окон.

- **R8.1** Все окна (хаба и TempleApi-скриптов) живут под контролем WM: скрипт не может «увести окно из-под менеджмента», но может попросить `floating = true` (окно вне tiling, всё ещё под snap/focus).
- **R8.2** Shell полностью темо-зависим: menu bar, dock, snap-превью, индикаторы используют токены (§9) и перекрашиваются hot-swap'ом наравне с окнами.
- **R8.3** Каждый элемент shell включается/выключается в `temple.yaml → shell` (юзер может оставить «голые окна» без бара и дока).

### 8.2 WM (Window Manager)
- **R8.4 Жизненный цикл**: `Open / Focus / Minimize / Maximize / Restore / Close`; z-order по фокусу; клик поднимает окно; `entry_key` сворачивает/разворачивает всё одним движением.
- **R8.5 Snap**: перетаскивание к кромке → половина экрана, к углу → четверть; превью зоны snap цветом `snap.preview`; Alt+перетаскивание → сетка 3×3.
- **R8.6 Tiling** (опция `wm.tiling: columns|grid`): открытые окна автораскладываются без наложений; новое окно «вдавливает» остальные; любое окно можно вывести в float.
- **R8.7 Workspaces** (`wm.workspaces: N`, 0 = выкл): окна привязаны к workspace; индикатор в menu bar + свитчер в доке; перенос окна — перетаскиванием на индикатор или `Temple.Window:SetWorkspace(n)`.
- **R8.8 Switcher**: `Alt+Tab` — оверлей со списком окон (заголовок + иконка приложения); live-миниатюры — v1.1.
- **R8.9 Память окон**: позиция/размер/workspace каждого окна по стабильному `window id` в `cache/configs/windows.json`; восстановление после boot и после rejoin.
- **R8.10 Анимации** (скорость из темы `effects.animation_speed`): slide dock, scale minimize (в иконку дока), fade switcher. При `animations: false` — мгновенные переходы.
- **R8.11 Minimized-окна** живут иконками в доке с бейджем «свёрнуто»; клик — restore + focus.

### 8.3 Menu Bar (сверху)
Полоса высотой `shell.menubar.height`, composition из `items`:

| Элемент | Содержимое |
|---|---|
| `menu` | dropdown: Reload hub, Settings, Themes, Update…, Exit hub (полное закрытие) |
| `title` | заголовок фокусного окна (или «TempleEx» если фокуса нет) |
| `clock` | время |
| `fps` | FPS игры (источник — `RunService`-сэмплер) |
| `executor` | имя executor'а + версия |
| `theme` | текущая тема; клик — cycle по избранным; long-press — открыть Theme Picker |
| `tray` | трей уведомлений: колокольчик + счётчик, dropdown истории нотификаций сессии |
| `binds` | активные кейбинды (чипы), клик — jump к окну-владельцу |

- **R8.12** `autohide: true` — bar прячется, когда нет ни одного открытого окна (reveal так же, как dock).
- **R8.13** Слоты для скриптов: `Temple.Shell:MenuItem({...})` добавляет пункт в dropdown `menu` (секция «Scripts»); `Temple.Shell:StatusChip({...})` — чип в район `binds`.

### 8.4 Dock (снизу, reveal по наведению)
- **R8.14 Reveal**: курсор попадает в нижнюю полосу экрана высотой `reveal_zone` px → dock выезжает снизу (slide-анимация); ушёл (за пределы dock + `hide_delay`) → уехал. Режимы `reveal: always` (dock постоянный) и `key` (показ по хоткею) — из конфига.
- **R8.15 Состав дока** (слева направо): пины функций (`pins`), разделитель, пины autoload-скриптов (иконка = `icon` плагина или буква), разделитель, иконки открытых/свёрнутых окон, разделитель, workspace-свитчер, справа — системные: Themes, AI, Scripts, Settings.
- **R8.16 Взаимодействие**: клик по функции = toggle (иконка подсвечивается `dock.icon.active`, когда функция включена); правый клик = popover с параметрами функции/скрипта (без открытия окна); drag — reorder пинов (пишется в `pins`); middle-click по скрипту = reload скрипта.
- **R8.17 Magnify**: опциональное увеличение иконок под курсором (радиус/сила из конфига, скорость из темы).
- **R8.18 Индикаторы**: точка под иконкой = окно открыто; бейдж «!» = у скрипта была ошибка в сессии.

### 8.9 Требования shell
- **R8.19** Hit-test дока/бара не блокирует игру, когда shell скрыт (Transparency/Active=false полностью).
- **R8.20** Раскрытие дока ≤ 100 мс от входа в reveal-зону; CPU idle при спрятанном shell = 0 (никаких heartbeat-циклов, только InputBegan/Moved-слушатель).
- **R8.21** Все строки shell (тоoltips, названия) — через локализатор `temple.language`.

---

## 9. Система тем (Omarchy-style)

### 9.1 Модель
- **R9.1** Каждая тема — ровно один файл `workspace/themes/<name>.yaml`. Имя темы = имя файла.
- **R9.2** Тема самодостаточна или `extends: <name>` — глубокое слияние токенов.
- **R9.3** Hot-swap: без пересоздания окон/shell-элементов, ≤ 50 мс на 200 виджетах.
- **R9.4** Битая тема → откат на `theme.fallback` + уведомление с ошибкой и кнопкой «Открыть файл».
- **R9.5** Тема применяется ко всему: хаб, **menu bar, dock, snap-превью, switcher**, окна сторонних скриптов, уведомления, комманд-палитра, AI-панель.
- **R9.6** Watchdog: новый/изменённый файл в `themes/` виден в пикере ≤ 3 с.

### 9.2 Токены темы (schema v1)
```yaml
# themes/midnight-temple.yaml
temple_theme: 1
name: Midnight Temple
author: temple
extends: default
meta: { tags: [dark, blue, glass], description: "Ночной храм: индиго + неон" }

palette:
  bg-0: "#0b0e1a"
  bg-1: "#121729"
  bg-2: "#1a2138"
  fg-0: "#e8ecf8"
  fg-1: "#9aa3c0"
  accent: "#7c5cff"
  accent-2: "#00e0b8"
  danger: "#ff5470"
  success: "#3ddc84"
  warning: "#ffb454"

tokens:                         # семантические роли → палитра
  window.bg: palette.bg-1
  sidebar.bg: palette.bg-0
  tab.active: palette.accent
  toggle.on: palette.accent-2
  text.primary: palette.fg-0
  button.primary.bg: palette.accent
  notification.bg: palette.bg-2
  menubar.bg: palette.bg-0
  dock.bg: palette.bg-0
  dock.icon.active: palette.accent-2
  snap.preview: palette.accent
  # полный реестр ролей — Приложение А

typography: { font: GothamSSm, sizes: { xs: 12, sm: 14, md: 16, lg: 20, xl: 26 } }
geometry:
  radius: { window: 12, element: 8, pill: 999 }
  padding: { window: 14, element: 8 }
  shadow: { blur: 12, transparency: 0.5, color: "#000000" }
effects:
  blur: true
  gradient: { angle: 135, from: palette.bg-1, to: palette.bg-0 }
  animations: true
  animation_speed: 1.0
icons: { set: temple-default, overrides: {} }
layout: { sidebar: left, window_opacity: 0.96 }
```
- **R9.7** Виджеты обращаются только к ролям (`theme.get("toggle.on")`), никогда к `palette.*` напрямую.
- **R9.8** Неизвестная роль = warning; неизвестный слой = ошибка темы.

### 9.3 Theme Picker (внутриигровой)
Сетка карточек-превью (детерминированный рендер из YAML, превью включает mini-окно + mini-dock), живой preview по наведению, поиск/фильтр по тегам, кнопки Apply / Edit (встроенный YAML-редактор с валидацией) / Duplicate / Export / Delete (в `cache/trash/`), и **«✨ Generate with AI»** (§12).

### 9.4 Импорт/экспорт
- **R9.9** Тема = один текстовый файл → шарится в Discord/Telegram как есть. Импорт из файла, буфера обмена, URL.
- **R9.10** Репозиторий тем сообщества — git-репо с YAML; `Temple.Theme.pull(repo_or_url)` тянет тему из GitHub raw (§11.3).

---

## 10. TempleApi (для сторонних скриптов)

### 10.1 Получение API
```lua
-- из-под loadstring-хаба (скрипт в plugins/ или вызов из консоли):
local Temple = TempleApi.get()
-- или классически:
local Temple = loadstring(game:HttpGet(".../TempleEx.lua"))()
```
- **R10.1** Идемпотентность: повторный require возвращает тот же объект.
- **R10.2** Semver: `Temple.version = {major=1,minor=0,patch=0}`; breaking — только major; deprecated живут ≥ 1 major с warning.

### 10.2 Поверхность API

```lua
Temple.version

-- ── UI + WM ─────────────────────────────────────────
local win  = Temple.Window({ title, size, keybind, floating = false })
local tab  = win:Tab("Visuals")
local sect = tab:Section("Main")

sect:Toggle({ title, description, default, flag, callback })
sect:Slider({ title, min, max, step, default, flag, callback, suffix })
sect:Dropdown({ title, values, default, flag, callback, multi })
sect:Button({ title, description, callback })
sect:Input({ title, placeholder, default, flag, callback })
sect:Keybind({ title, default, mode = "toggle"|"hold", flag, callback })
sect:Label / Paragraph / List / Colorpicker / Table / Image

-- управление окном из скрипта (делегат WM):
win:Minimize() / :Maximize() / :Restore() / :Focus() / :Close()
win:Snap("left"|"right"|"tl"|"tr"|"bl"|"br"|"center")
win:SetWorkspace(n) / win:OnFocusChanged(fn)

Temple.Flags["ESP_Enabled"]
win:OnClosed(fn) / win:Destroy()

-- ── Shell ───────────────────────────────────────────
Temple.Shell:DockPin({ id, icon, tooltip, toggle = fn, popover = fn })
Temple.Shell:DockUnpin(id)
Temple.Shell:MenuItem({ text, section = "Scripts", callback })   -- dropdown menu bar
Temple.Shell:StatusChip({ id, text, icon, tooltip })
Temple.Shell:Workspace() / :SetWorkspace(n) / :WorkspaceCount()

-- ── Встроенные функции ──────────────────────────────
Temple.Fly:Enable() / :Disable() / :Toggle() / :Set(param, value) / :Get(param)
Temple.Speed / Temple.ESP / Temple.Noclip / ...  -- тот же контракт
Temple.Core:list()

-- ── Скрипты / автозагрузка ──────────────────────────
Temple.Script:id() / :name()                    -- контекст текущего скрипта
Temple.Script:SetAutoload(bool)                 -- пишет plugins[].autoload в temple.yaml
Temple.Script:Reload()                          -- перезапуск себя

-- ── Уведомления / кейбинды / команды ────────────────
Temple.Notify({ title, content, duration, level })   -- level: info|success|warn|error
Temple.Bind({ name, default, mode, registry, callback }) / Temple.Unbind(name)
Temple.Command({ name, category, callback })    -- комманд-палитра

-- ── Тема ────────────────────────────────────────────
Temple.Theme:get(role) / :set(role, value) / :apply(name) / :list()
Temple.Theme:onChange(fn)

-- ── Executor-фасад ──────────────────────────────────
Temple.Executor:name() / :http(url, opts) / :saveinstance()
Temple.Executor:queue_on_teleport(str) / :get_clipboard()
Temple.Executor:fs_write(path, content)         -- sandbox: только workspace/

-- ── Конфиг / сеть / git ─────────────────────────────
Temple.Plugin({ name, version, icon, onLoad, onUnload })
Temple.Config:save(script_id) / :load(script_id)
Temple.Webhook:send(url, payload)
Temple.Hub:search(query) / :run(name) / :pull(repo_or_url)
Temple.Update()
```

### 10.3 Требования
- **R10.3** Все конструкторы — одна options-таблица (named args).
- **R10.4** `Temple.IYCompat()` — адаптер сигнатур Infinity Yield (v1.1; архитектура v1 обязана это допускать).
- **R10.5** Мутации GUI — только через `task.defer`-очередь ядра.
- **R10.6** pcall-границы: ошибка callback'а скрипта → уведомление + бейдж «!» на иконке дока + лог, хаб жив.
- **R10.7** Docs из LSP-аннотаций: `docs/TempleApi.md` + `TempleApi.d.lua`, публикуются при каждом релизе.

---

## 11. Git-совместимость

### 11.1 Структура репозитория TempleEx
```
TempleEx/
├── TempleEx.lua              # bootloader (каноническая raw-ссылка)
├── src/                      # модули (Kernel, Core/*, Shell/*, Theme, Api, ...)
├── schema/                   # temple.schema.json, theme.schema.json
├── agents/                   # промпт-шаблоны AI-агентов
├── themes/                   # официальные темы (зеркалируются в workspace при boot)
├── docs/                     # TempleApi.md, TempleApi.d.lua, гайды
├── .github/workflows/        # CI: build single-file, schema-validate, release
└── CHANGELOG.md
```
- **R11.1** Релиз = GitHub Release с артефактами `TempleEx.lua` (bootloader) и `TempleEx-full.lua` (single-file build из `src/`), тег `v1.2.3`.
- **R11.2** CI обязан: сборка, валидация всех YAML в `themes/` по схеме, генерация docs, проверка semver-соответствия CHANGELOG.

### 11.2 Самообновление
- **R11.3** При boot (если `git.auto_update: true`) bootloader сравнивает кэш-тег с `releases/latest` (HEAD-запрос или `VERSION`-файл в raw — без токена). Новый релиз → докачка билда → применение со следующего boot или сразу по подтверждению `Temple.Update()`.
- **R11.4** Каналы: `stable` (теги), `canary` (raw `dev`-ветка). Переключение в `temple.yaml`.
- **R11.5** Откат: `cache/TempleEx.prev.lua`; `Temple.Update({ to = "v1.2.2" })` — пин версии по тегу.

### 11.3 Реестры контента = git-репозитории
- **R11.6** Индекс реестра — `index.yaml` в репо (`TempleEx/hub-index`, `TempleEx/themes`):
  ```yaml
  - name: AutoFarm-X
    file: scripts/autofarm.lua
    author: someone
    tags: [farm]
    version: 2.1
    sha256: "..."
  ```
- **R11.7** `Temple.Hub:pull("user/repo")` или raw-URL: скачивает в `plugins/`, проверяет `sha256`, diff-уведомление при обновлении.
- **R11.8** Вкладка **Scripts** = браузер реестров: поиск по тегам, Run (без установки) / Install (в `plugins/`, сразу с тумблером autoload), история версий из git-логов.
- **R11.9** Темы сообщества: PR в `TempleEx/themes` → CI (схема + контраст-gate) → мерж → доступна через `Temple.Theme.pull` и кнопкой «Community» в пикере.
- **R11.10** Сетевые пути реестров — только `https://` на git-хостинги из `git.mirrors` allowlist + явно добавленные юзером репо.

### 11.4 Требования к raw-совместимости
- **R11.11** Любой официальный файл корректно отдаётся по `raw.githubusercontent.com` без редиректов и совместим с `game:HttpGet`.
- **R11.12** Канонические ссылки в README: `main` (stable raw), `releases/download/vX.Y.Z/...` (пин), jsDelivr-зеркало.

---

## 12. AI-агенты (генерация тем)

### 12.1 Роли
| Агент | Задача | Вход | Выход |
|---|---|---|---|
| **theme-gen** | тема с нуля | промпт + schema + 3 примера | валидный `themes/<slug>.yaml` |
| **theme-refine** | правка темы | текущий YAML + фидбек | новый YAML |
| **theme-namer** | slug/название/теги | промпт | meta-блок |
| **config-audit** | аудит `temple.yaml`/темы | YAML | проблемы + фиксы |

### 12.2 Пайплайн
```
prompt → [theme-gen] → YAML → [Validator: schema + токены + WCAG-контраст]
   → fail → авто-ретрай с текстом ошибки (≤2) → всё ещё fail → показать юзеру
   → ok → themes/<slug>.yaml → preview → юзер: Apply / Regenerate / Tweak
```
- **R12.1** Агент никогда не пишет в `temple.yaml` и не применяет тему без нажатия Apply.
- **R12.2** Выход строго YAML (JSON/response_format, иначе парсинг fenced-блока с валидацией).
- **R12.3** Контраст-gate: WCAG `text.primary`/`window.bg` < 3.0 → warning, < 2.0 → ошибка с конкретной претензией агенту (self-healing).
- **R12.4** Промпт-шаблоны — внешние (`agents/*.md`), редактируются юзером.
- **R12.5** Кэш по хешу промпта+модели в `cache/ai/`.
- **R12.6** `provider: local-ollama` — полностью офлайн.
- **R12.7** Приватность: промпт уходит только на `ai.base_url`; ключ из env/inline; телеметрии нет.
- **R12.8** Генерация не блокирует GUI (очередь запросов = 1, статус-пайплайн в панели).

### 12.3 UX
Панель «✨ AI Themes» (пин дока + вкладка): поле промпта → Generate → статусы generating/validating/preview → Apply; «Tweak» — чат с theme-refine в контексте текущей темы; история генераций сессии.

---

## 13. Автозагрузка скриптов

### 13.1 Источники и запуск
- **R13.1** Источники: файлы в `plugins/` (локальные), записи `plugins:` в `temple.yaml` (локальный путь или git-ссылка), установленные через `Temple.Hub:pull` (кладутся в `plugins/` и получают запись с `autoload: false` по умолчанию).
- **R13.2** Порядок загрузки = порядок в `plugins:`; между стартами — `scripts.stagger` мс (защита от флуда HTTP/GUI в один кадр).
- **R13.3** Скрипт получает контекст: `Temple.Script:id()/name()`, свой `Temple.Config` namespace, изолированный `_ENV` (общие — только `Temple*` и стандартные библиотеки).
- **R13.4** Изоляция ошибок: падение скрипта при загрузке → уведомление + бейдж «!» на иконке дока + лог; остальные скрипты и хаб не затронуты. `Temple.Script:Stop()` корректно рвёт его соединения/кейбинды/окна.

### 13.2 Управление autoload
- **R13.5** Тумблер autoload: в вкладке Scripts (карточка скрипта), в popover иконки дока (правый клик), и напрямую в `temple.yaml → plugins[].autoload`. Все три пишут в одно место — `temple.yaml` (R6.3).
- **R13.6** Watchdog `plugins/` (`scripts.watch_folder`): новый `.lua` появляется в вкладке Scripts и как кандидат в док ≤ 3 с; удаление — гаснет иконка, скрипт останавливается.

### 13.3 Восстановление сессии и rejoin
- **R13.7 Session restore** (`scripts.restore_session`): при закрытии/релоаде хаба список **запущенных** скриптов (autoload + запущенные вручную в этой сессии) пишется в `cache/configs/session.json`; при следующем boot они стартуют автоматически после готовности shell.
- **R13.8 Rejoin-relaunch** (`scripts.rejoin_relaunch`): через `Temple.Executor:queue_on_teleport` в очередь кладётся канонический loadstring + маркер `--autoload`; после телепорта/респавна хаб поднимается из кэша и восстанавливает сессию. На executor'ах без `queue_on_teleport` — фолбэк: слушать `Player.LocalPlayer` respawn и перезапускать сессию в том же плейсе.
- **R13.9** Первая загрузка скрипта из git-реестра требует явного подтверждения юзера (показ sha256 + автор); дальше — silent autoload до изменения хеша (then — снова подтверждение).
- **R13.10** `entry_key` и команда `:autoload off` (комманд-палитра) — аварийный «выключить всё autoload на эту сессию» для отладки.

---

## 14. Нефункциональные требования

- **NF1** Boot ≤ 1.5 с cold / ≤ 0.5 с с кэша; reveal дока ≤ 100 мс; idle CPU ≤ 1% (спрятанный shell = 0 циклов); hot-swap темы ≤ 50 мс; 50+ окон без деградации (пулинг, отложенная отрисовка скрытых вкладок).
- **NF2** Память GUI-части ≤ 60 МБ при 20 окнах; Destroy реально освобождает Instance'ы; dock/menubar переиспользуют ноды.
- **NF3** Ошибка модуля не убивает хаб (pcall-границы); автобэкап `temple.yaml` перед записью; WM переживает падение любого скрипта (его окна закрываются корректно).
- **NF4** Stealth best-effort: имена нод из `behavior.stealth`; сетевые запросы — только git-allowlist + настроенные AI/webhook; из глобалов — только `TempleApi`/`Temple`.
- **NF5** `fs_write` из TempleApi — песочница `workspace/`, нормализация путей, `..` запрещён.
- **NF6** Одна кодовая база под все executor'ы §3.3; расхождения — только в `Temple.Executor`.
- **NF7** Релиз = single-file build + `schema/` + `agents/`; semver; CHANGELOG; CI (§11.1).

---

## 15. Этапы и приёмка

### Этап 0 — Спецификация (этот документ)
Фиксация: schema `temple.yaml`, реестр токенов-ролей (Приложение А), список функций v1 (§7.1), контракты shell (§8) и autoload (§13), сигнатуры TempleApi, структура репо (§11.1).
**Выход:** согласованные схемы и списки.

### Этап 1 — Bootloader + ядро + функции
§5 (loadstring, зеркала, кэш), Kernel, Temple.Core: **fly, speed, infinite jump, noclip, fullbright**, базовые окна, TempleApi UI-конструкторы, запись в `temple.yaml`.
**Приёмка:** одна raw-строка → ≤ 1.5 с → рабочий хаб с летящим персонажем; повторный loadstring не дублирует GUI; офлайн-старт с кэша.

### Этап 2 — Shell + темы + автозагрузка
WM (focus/min/max/snap/tiling/workspaces/switcher/remember), menu bar, dock с hover-reveal; ThemeEngine + Theme Picker + watchdog + редактор YAML, 2 темы; autoload + session restore + rejoin-relaunch + watch_folder.
**Приёмка:** наведение к нижней кромке → dock ≤ 100 мс, клик по иконке Fly включает полёт без открытия окна; перетаскивание окна к краю → half-snap; `foo.yaml` в `themes/` → ≤ 3 с в пикере → hot-swap ≤ 50 мс; скрипт с `autoload: true` стартует с хабом, после rejoin поднимается сам; `Alt+Tab` переключает окна.

### Этап 3 — Git-экосистема + AI
Hub-реестры (`index.yaml`, вкладка Scripts, pull/run/install), auto-update по тегам, каналы stable/canary; LLM bridge + theme-gen/refine + контраст-gate + панель AI.
**Приёмка:** плагин из стороннего git-репо ставится кнопкой, получает иконку в доке и autoload-тумблер; `Temple.Update()` откатывает на пин-версию; промпт «киберпанк-розовый, высокий контраст» → ≤ 60 с валидная тема с WCAG ≥ 3.0, перекрашивающая в т.ч. dock и menu bar.

### Этап 4 — Экосистема-2
`IYCompat`, docs-портал `TempleApi.d.lua`, плагины-примеры, коммьюнити-PR workflow для тем, левый/правый dock, live-миниатюры switcher, полная поддержка Hydrogen/Potassium/Swift.
**Приёмка:** 3 реальных IY-скрипта поднимаются через compat без правок логики.

### Риски
| Риск | Митигция |
|---|---|
| GitHub-raw блокировки/зеркала «горят» | R5.3 цепочка зеркал + локальный кэш + печать канонической строки |
| Различия `Drawing`/функций executor'ов | фасад `Temple.Executor`, деградация R7.4, CI-матрица смоков |
| Dock/menubar конфликтуют с GUI игры (клик-_through) | reveal-зона вне hit-test в скрытом состоянии (R8.19), режим `reveal: key` |
| LLM выдаёт битый YAML | schema-gate + авто-ретрай + человек-в-цикле |
| Обновление сломало хаб | `cache/TempleEx.prev.lua` + пин версий (R11.5) |
| Вредоносные autoload-скрипты | подтверждение первого запуска + sha256 (R13.9), allowlist реестров, изоляция `_ENV`, аварийный off (R13.10) |
| Токены/названия разъезжаются | Приложение А фиксируется на Этапе 0; `temple_theme: 1` semver формата |

---

## Приложение А — Реестр токенов-ролей (фрагмент; полный — до Этапа 1)
`window.bg, window.border, window.title.fg, window.close.hover, sidebar.bg, sidebar.item.active.bg, sidebar.item.fg, tab.active, tab.idle.fg, tab.hover, section.header.fg, element.bg, element.border, element.focus, text.primary, text.muted, text.accent, toggle.track.off, toggle.track.on, toggle.knob, slider.fill, slider.knob, dropdown.bg, dropdown.item.hover, button.primary.bg, button.primary.fg, button.ghost.fg, button.danger.bg, input.bg, input.placeholder, keybind.bg, notification.bg, notification.fg, notification.level.{info,success,warn,error}, esp.box, esp.name, esp.tracer, menubar.bg, menubar.fg, dock.bg, dock.icon, dock.icon.active, dock.indicator, snap.preview, switcher.bg, workspace.active.fg` + палитра `palette.*`

## Приложение Б — Критерии готовности ТЗ
Документ принят после: (1) фиксации полного реестра ролей Приложения А (включая shell-роли); (2) финального списка встроенных функций v1 и их параметров; (3) подтверждения состава menu bar/dock v1; (4) подтверждения списка executor'ов и git-хостингов; (5) выбора дефолтного AI-провайдера и политики ключей.
