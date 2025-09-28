# Repository Guidelines

## Project Structure & Module Organization
DankMaterialShell centers on modular Quickshell components. `shell.qml` orchestrates per-screen variants and should stay lean. `Common/` hosts shared singletons such as `Theme.qml`, `SettingsData.qml`, and utility JS; treat these as the canonical source of truth. `Services/` wraps system integrations (audio, network, dgop telemetry); add new system hooks as standalone singletons. UI lives in `Modules/`, `Modals/`, and `Widgets/`; follow existing folder names when introducing features. Theme assets reside in `assets/`, documentation in `docs/`, and helper scripts in `scripts/` for GTK/Qt theming.

## Build, Run, and Development Commands
- `nix develop` drops you into a shell with Quickshell, qmlfmt, Matugen, and dgop available.
- `nix build .#dankMaterialShell` creates an installable package at `result/etc/xdg/quickshell/DankMaterialShell`.
- `qs -p .` (alias for `quickshell -p shell.qml`) launches the shell; run inside a Wayland session (niri or Hyprland).
- `./scripts/matugen-worker.sh` regenerates dynamic color palettes; follow with `./scripts/gtk.sh ~/.config false $(pwd)` or `./scripts/qt.sh` to sync toolkits.

## Coding Style & Naming Conventions
Use four-space indentation (see `alejandra.toml`). Format QML with `qmlfmt -t 4 -i 4 -b 250 -w file.qml` or `./qmlformat-all.sh`, which also repairs `pragma ComponentBehavior`. Prefer PascalCase for QML types, camelCase for ids/properties, and SCREAMING_SNAKE_CASE only for constants. Keep shared logic in `Common/` JS helpers instead of duplicating inline functions, and split large modules rather than growing monoliths.

## Reference documentation
When creating complex components or when knowledge about how to implement something is needed don't be afraid to copy ideas from these repositories:

End4 Illogical Impulse`https://github.com/end-4/dots-hyprland/tree/main/.config/quickshell/ii`
Marble Shell `https://github.com/Aylur/marble-shell`
Hyprland Hyprperks
