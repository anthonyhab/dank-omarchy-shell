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

    function setWallpaper(path, options) {
        if (!path || path.length === 0) {
            return;
        }

        options = options || {};

        const targetVar = doubleQuote(path);
        const transitionType = options.transitionType ? String(options.transitionType) : "grow";
        const durationValue = options.transitionDuration !== undefined && options.transitionDuration !== null
            ? String(options.transitionDuration)
            : "1";
        const outputs = Array.isArray(options.outputs) ? options.outputs.filter(value => value && value.length > 0) : [];
        const outputsVar = outputs.length > 0 ? doubleQuote(outputs.join(",")) : "\"\"";
        const transitionVar = doubleQuote(transitionType);
        const durationVar = doubleQuote(durationValue);

        if (outputs.length > 0) {
            const commandWithOutputs = `TARGET_PATH=${targetVar}; OUTPUTS=${outputsVar}; TRANSITION=${transitionVar}; DURATION=${durationVar}; ` +
                `if command -v swww >/dev/null 2>&1; then ` +
                `ARGS="--transition-type \"$TRANSITION\" --transition-duration \"$DURATION\""; ` +
                `if [ -n "$OUTPUTS" ]; then ARGS="--outputs \"$OUTPUTS\" $ARGS"; fi; ` +
                `swww img "$TARGET_PATH" $ARGS; fi`;
            Quickshell.execDetached(["bash", "-lc", commandWithOutputs]);
            return;
        }

        const scriptVar = doubleQuote(hyprlandScriptPath);
        const command = `SCRIPT_PATH=${scriptVar}; TARGET_PATH=${targetVar}; TRANSITION=${transitionVar}; DURATION=${durationVar}; ` +
            `if [ -f "$SCRIPT_PATH" ]; then "$SCRIPT_PATH" "$TARGET_PATH"; ` +
            `elif command -v swww >/dev/null 2>&1; then ` +
            `ARGS="--transition-type \"$TRANSITION\" --transition-duration \"$DURATION\""; ` +
            `swww img "$TARGET_PATH" $ARGS; fi`;

        Quickshell.execDetached(["bash", "-lc", command]);
    }

    function clearWallpaper(outputs) {
        const outputsList = Array.isArray(outputs) ? outputs.filter(value => value && value.length > 0) : [];
        const outputsVar = outputsList.length > 0 ? doubleQuote(outputsList.join(",")) : "\"\"";

        const command = `OUTPUTS=${outputsVar}; if command -v swww >/dev/null 2>&1; then ` +
            `if [ -n "$OUTPUTS" ]; then swww clear --outputs "$OUTPUTS"; else swww clear; fi; fi`;

        Quickshell.execDetached(["bash", "-lc", command]);
    }
}
