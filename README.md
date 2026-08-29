<div align="center">

# ⛩ TempleEx

**A next-generation Roblox exploit hub — one loadstring, infinite themes.**

*Infinity Yield alternative · Omarchy-style theming · AI-generated themes · built-in WM*

[![Version](https://img.shields.io/badge/version-1.0.0-7c5cff)](#)
[![Executor support](https://img.shields.io/badge/executors-Wave%20·%20Codex%20·%20Hydrogen%20%26%20more-00e0b8)](#)
[![License](https://img.shields.io/badge/license-MIT-9aa3c0)](#license)

</div>

---

## 🚀 Quick Start

One line. That's it.

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/FoarteBine/TempleEx/main/TempleEx.lua"))()
```

Press **RightCtrl** to open the hub. Hover the **bottom edge of the screen** to reveal the dock.

The bootloader resolves the latest release, caches the full build into your executor's `workspace/`, and works **offline** from cache if GitHub is unreachable. Mirror chain: `raw.githubusercontent.com` → `jsDelivr` → local cache.

## ✨ What makes it different

| | Infinity Yield | **TempleEx** |
|---|---|---|
| Look | fixed, 2–3 built-in themes | **themes = YAML files**, hot-swapped live |
| Windows | drag & drop | **full WM**: snap, tiling, workspaces, Alt+Tab |
| Shell | none | **menu bar + dock** (hover-reveal, like a desktop OS) |
| Config | scattered GUI settings | **one `temple.yaml`** as single source of truth |
| Themes from prompts | — | **AI agents generate valid themes in-game** |
| Updates | ad-hoc | **git-native**: semver tags, channels, rollback, pin |
| Your scripts | run manually | **autoload + session restore + rejoin relaunch** |

## 🎨 Themes, Omarchy-style

Every theme is one self-contained file in `workspace/themes/`:

```
workspace/
├── temple.yaml            # the ONLY config file
├── themes/
│   ├── default.yaml
│   ├── midnight-temple.yaml
│   └── your-theme.yaml    # drop a file → appears in the picker in ≤3s
├── plugins/               # your scripts (autoloadable)
└── cache/
```

- **Hot-swap** — ≤50 ms, no window recreation, positions preserved
- **`extends:`** — inherit & override a base theme
- **57 semantic token roles** — windows, tabs, toggles, ESP, dock, menu bar, snap preview…
- **Live preview** — hover a card in the Theme Picker, the whole environment re-skins
- **Broken theme?** — automatic fallback + error notification, hub never dies

### ✨ AI theme generation

Type a prompt in-game → an AI agent produces a schema-validated YAML theme:

> *"cyberpunk, neon pink and cyan, high contrast"*

The pipeline validates tokens against the schema and enforces **WCAG contrast gates** — failures are fed back to the agent for self-healing retries. Then: Apply / Regenerate / Tweak ("make the background darker"). Providers: OpenAI-compatible, Anthropic, or **fully offline via local Ollama**.

## 🖥 Temple.Shell — a desktop inside the game

- **Window Manager** — focus/z-order, minimize/maximize, edge-snap (halves/quarters), tiling (columns/grid), up to 8 workspaces, Alt+Tab switcher, window position memory
- **Menu bar** (top) — active window title, clock, FPS, executor badge, theme cycler, notification tray, active keybind chips
- **Dock** (bottom) — slides out when your cursor touches the bottom edge; pinned functions (click = toggle, right-click = params popover), running scripts, open windows, workspace switcher, magnification

Everything is theme-driven and hot-swaps with the rest of the UI.

## 🧰 Built-in functions (Temple.Core)

Ready out of the box — no downloads, no setup:

`Fly` · `Speed` · `Infinite Jump` · `Noclip` · `ESP` (boxes/names/tracers/team colors) · `Fullbright` · `Hitbox Expander` · `Freecam` · `Unanchor` · `Respawn Lock` · `No Fall` · `Teleport` (save/goto points) · `Player List`

Each function = one declarative module → automatically gets a GUI toggle, sliders, keybind, command-palette entry and dock icon. State persists in `temple.yaml` and survives rejoin.

## 📜 Script autoload

Mark any script in `plugins/` with `autoload: true` and it starts with the hub:

- **Session restore** — whatever was running comes back on next boot
- **Rejoin relaunch** — `queue_on_teleport` (with respawn fallback) re-arms everything
- **Folder watchdog** — drop a `.lua` into `plugins/`, it appears in the Scripts tab in ≤3 s
- **Isolation** — each script runs in its own sandboxed `_ENV`; a crash shows a badge, never kills the hub

## 🔌 TempleApi — write your own scripts

```lua
local Temple = TempleApi.get()

local win  = Temple.Window({ title = "My Script", size = {500, 360} })
local tab  = win:Tab("Main")
local sect = tab:Section("Settings")

sect:Toggle({ title = "Enabled", flag = "My_Enabled", callback = print })
sect:Slider({ title = "Range", min = 0, max = 100, default = 50, flag = "My_Range" })
sect:Keybind({ title = "Panic", default = "KeyCode", callback = function()
    Temple.Fly:Toggle()          -- built-ins are scriptable too
end })

Temple.Notify({ title = "Loaded", content = "TempleEx v1", level = "success" })
Temple.Theme:apply("midnight-temple")
Temple.Shell:DockPin({ id = "my_pin", icon = "⭐", tooltip = "My Script", toggle = fn })
```

- **Semver API** — breaking changes only on major bumps, deprecations live a full major
- **`Temple.Hub:pull("user/repo")`** — registries are just git repos with an `index.yaml`
- **`Temple.Update()`** — self-update / rollback / version pin via git tags
- **`Temple.IYCompat()`** *(roadmap)* — run Infinity Yield scripts with one line changed

## ⚙️ One config to rule them all — `temple.yaml`

```yaml
version: 1
temple:  { entry_key: "RightCtrl", ui_mode: hybrid, language: ru }
shell:
  wm:    { snap: true, tiling: "off", workspaces: 3 }
  dock:  { reveal: hover, reveal_zone: 4, icon_size: 40, magnify: true }
theme:   { active: midnight-temple, fallback: default, auto_reload: true }
functions: { fly: { enabled: false, speed: 50, keybind: "E" } }
plugins: [{ name: my-script, file: plugins/my.lua, autoload: true }]
ai:      { provider: local-ollama, model: llama3 }
```

Every GUI change writes back into this file (with automatic backup). Validated against [`schema/temple.schema.json`](schema/temple.schema.json).

## 🏗 Building from source

```bash
# Linux / macOS
./build.sh

# Windows (PowerShell)
.\build.ps1
```

Concatenates `src/*.lua` into `TempleEx-full.lua` (the single-file build the bootloader downloads). `TempleEx.lua` itself is the tiny (~13 KB) bootloader.

## 🧱 Project layout

```
TempleEx/
├── TempleEx.lua              # bootloader — the canonical loadstring target
├── src/                      # module sources (yaml, executor, config, theme,
│                             #   core, core_functions, shell, api, autoload, git, ai)
├── themes/                   # official themes (mirrored into workspace/ at boot)
├── schema/                   # JSON Schemas for temple.yaml and theme files
├── agents/                   # AI agent prompt templates (editable!)
├── build.ps1 / build.sh      # single-file build scripts
└── TZ.md                     # full technical specification (RU)
```

## 🔒 Privacy & safety

- No telemetry. Ever. Network calls go only to git mirrors you configured, your AI `base_url`, and webhooks you set up.
- AI keys are read from env/inline config only.
- Scripts from registries require explicit first-run confirmation (author + sha256 shown).
- `fs_write` from TempleApi is sandboxed to `workspace/`.

## ⚖️ License

MIT — see [LICENSE](LICENSE).

> Educational purposes. TempleEx provides generic Roblox client tooling; you are responsible for how you use it.
