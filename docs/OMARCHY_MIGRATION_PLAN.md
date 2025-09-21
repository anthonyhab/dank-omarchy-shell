# Omarchy Theme Migration

This checklist captures the high-level work required to transition from Matugen-driven dynamic theming to bespoke Omarchy theme packs while keeping merges with upstream DankMaterialShell manageable.

## Baseline & Safeguards
- [ ] Snapshot current fork state (commit or tag) before invasive changes
- [ ] Document contributor workflow updates in `AGENTS.md` and project README
- [ ] Keep Matugen code paths isolated until removal to ease potential rebases

## Theme Runtime Refactor
- [ ] Replace Matugen-specific properties/processes in `Common/Theme.qml` with an `OmarchyThemeManager`
- [ ] Provide helpers for palette lookups (`paletteHex`, `paletteRgba`, etc.) sourced from `dank.colors`
- [ ] Ensure light/dark switching reloads Omarchy data and reapplies toolkit assets

## Toolkit Asset Generation
- [ ] Port Matugen templates into `~/.config/omarchy/theme-generator/templates/`
- [ ] Implement `scripts/omarchy-theme-generator.sh` (or QML runner) that renders templates using Omarchy palettes
- [ ] Support GTK3/GTK4 symlinks, Qt5ct/Qt6ct configs, terminal palettes, dgop, and optional Firefox CSS

## Settings & IPC Updates
- [ ] Remove Matugen toggles (`themeSource`, `wallpaperDynamicTheming`) from `SettingsData.qml`
- [ ] Refresh Personalization / Appearance copy to describe Omarchy themes and generator behavior
- [ ] Ensure IPC `omarchy.setTheme` triggers theme regeneration without Matugen fallbacks

## Cleanup & Validation
- [ ] Delete Matugen scripts/assets once Omarchy pipeline is stable
- [ ] Update documentation (README, docs/) to reference Omarchy templates and generator usage
- [ ] Test each Omarchy theme (dark/light) across bar, modals, GTK/Qt apps, terminals, and external services

> Track progress by checking off items as they land in separate, focused commits to keep rebases against upstream manageable.
