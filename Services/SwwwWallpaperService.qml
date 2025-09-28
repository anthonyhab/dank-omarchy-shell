pragma Singleton
pragma ComponentBehavior: Bound

import QtCore
import QtQuick
import Quickshell

Singleton {
    id: root

    readonly property string hyprlandScriptPath: StandardPaths.writableLocation(StandardPaths.ConfigLocation)
        + "/hyprland-de/scripts/wallpaper.sh"

    function doubleQuote(arg) {
        if (arg === undefined || arg === null) {
            return "\"\"";
        }
        const value = String(arg).replace(/["\\$`]/g, "\\$&");
        return "\"" + value + "\"";
    }

    function setWallpaper(path) {
        if (!path || path.length === 0) {
            return;
        }

        const scriptVar = doubleQuote(hyprlandScriptPath);
        const targetVar = doubleQuote(path);
        const command = `SCRIPT_PATH=${scriptVar}; TARGET_PATH=${targetVar}; ` +
            `if [ -f "$SCRIPT_PATH" ]; then "$SCRIPT_PATH" "$TARGET_PATH"; ` +
            `elif command -v swww >/dev/null 2>&1; then swww img "$TARGET_PATH" --transition-type grow --transition-duration 1; fi`;

        Quickshell.execDetached(["bash", "-lc", command]);
    }

    function clearWallpaper() {
        const command = `if command -v swww >/dev/null 2>&1; then swww clear; fi`;
        Quickshell.execDetached(["bash", "-lc", command]);
    }
}
