# Comprehensive Implementation Plan: Porting Professional Patterns from Hyprland DE to Dank-omarchy Shell

## Overview
This document outlines professional Quickshell patterns and features from the Hyprland creator's setup that can be adopted to enhance the dank-omarchy shell.

## Phase 1: Configuration System Upgrade

**Reference:** `~/hyprland_de/quickshell/config/Config.qml:225-328`

**Current State:** Dank-omarchy uses `SettingsData.qml` with simple property declarations
**Target State:** JSON-based configuration with live reload

### Implementation Steps:

1. **Create new Config singleton** replacing `Common/SettingsData.qml`
   - Pattern from `config/Config.qml:8-328`
   - Use `FileView` with `JsonAdapter` for each config category
   - Add `watchChanges: true` for live reload
   - Implement auto-creation on missing files (`onLoadFailed` handler)

2. **Split configuration into logical files:**
   ```
   ~/.config/quickshell/config.json    - Main settings
   ~/.config/quickshell/account.json   - User data
   ~/.config/quickshell/misc.json      - Runtime state
   ~/.config/quickshell/matugen.json   - Theme (already exists)
   ```

3. **Key features to port:**
   - Monitor include/exclude lists (lines 271-273)
   - Date format system with roman numeral support (lines 26-78)
   - Opacity helpers for transparency (lines 90-100)
   - Font size scaling system (lines 114-122)

### Code Example:
```qml
FileView {
    path: Quickshell.dataPath("config.json")
    watchChanges: true
    onFileChanged: reload()
    onLoadFailed: error => {
        if (error == FileViewError.FileNotFound) {
            writeAdapter();
        }
    }

    JsonAdapter {
        id: settingsJson
        property JsonObject bar: JsonObject {
            property string edge: "top"
            property int verticalGap: 5
            property int horizontalGap: 5
            property int height: 30
        }
    }
}
```

## Phase 2: State Management Architecture

**Reference:** `~/hyprland_de/quickshell/state/` directory

**Current State:** Services use `Singleton` but lack proper pragma declarations
**Target State:** True singleton pattern with lazy loading

### Implementation Steps:

1. **Update all Services to use proper singleton pattern:**
   ```qml
   pragma Singleton
   pragma ComponentBehavior: Bound

   Singleton {
       id: root
       function load() { /* Force init */ }
   }
   ```

2. **Port key state services:**
   - **BrightnessState** (`state/BrightnessState.qml:1-258`)
     - DDC monitor detection (lines 205-236)
     - Per-monitor brightness arrays (lines 17-19)
     - Backlight fallback (lines 116-129)
     - Queue-based updates (lines 131-165)

   - **UpdateState** (`state/UpdateState.qml:1-50`)
     - Version checking system
     - Update channel support (beta/stable)
     - IPC integration for updates

3. **Add IpcHandler pattern** (Reference: `state/BrightnessState.qml:238-256`)
   ```qml
   IpcHandler {
       target: "brightness"
       function increment() { /* ... */ }
       function decrement() { /* ... */ }
   }
   ```

## Phase 3: Bar Enhancements & Compact Mode

**Reference:** `~/hyprland_de/quickshell/bar/Bar.qml:1-188`

**Current State:** Fixed-height bar without fullscreen awareness
**Target State:** Dynamic bar with compact mode for fullscreen apps

### Implementation Steps:

1. **Add compact mode to TopBar:**
   - Property: `property bool compact: Config.settings.panels.compactEnabled && Hyprland.monitorFor(screen).activeWorkspace.hasFullscreen`
   - Smooth transition states (lines 23-24, 178-182)
   - Dynamic exclusive zone (line 28)
   - Animated margins (lines 43-47)

2. **Port edge configuration** (Reference: `config/Config.qml:102-139`)
   - Support top/bottom positioning
   - Dynamic anchor calculation
   - Content margin adjustments

3. **Add mask regions** (line 184-187)
   ```qml
   mask: Region {
       width: root.width
       height: root.exclusiveZone
   }
   ```

### Key Properties:
```qml
property real compactState: compact ? 1 : 0
property real uncompactState: 1 - compactState
exclusiveZone: compact ? compactHeight : standardHeight

Behavior on compactState {
    SmoothedAnimation {
        velocity: 8
    }
}
```

## Phase 4: On-Screen Display (OSD) System

**Reference:** `~/hyprland_de/quickshell/osd/OnScreenDisplay.qml:1-143`

**Current State:** No visual feedback for volume/brightness changes
**Target State:** Professional OSD with auto-trigger and animations

### Implementation Steps:

1. **Create `Modules/OSD/` directory with:**
   - `OnScreenDisplay.qml` - Main OSD window
   - `OsdValue.qml` - Value display component

2. **Key features to implement:**
   - Auto-trigger on state changes (lines 44-68)
   - Timer-based auto-hide (lines 27-33)
   - Smooth component switching (lines 87-123)
   - Edge-aware positioning (lines 22-25)

3. **Integration points:**
   ```qml
   Connections {
       target: PipewireState.defaultSink?.audio
       function onVolumeChanged() { triggerShow(false) }
   }

   Timer {
       id: osdTimeout
       interval: Config.settings.osd.timeoutDuration
       onTriggered: root.visible = false
   }
   ```

## Phase 5: Advanced Popup System

**Reference:** `~/hyprland_de/quickshell/popup/PopupHandle.qml:1-40`

**Current State:** Direct modal instantiation
**Target State:** Lazy-loaded popups with proper lifecycle

### Implementation Steps:

1. **Create popup infrastructure:**
   - `PopupHandle.qml` - Manages popup lifecycle
   - `BasePopupDelegate.qml` - Base for all popups
   - `LayerPopupDelegate.qml` - Wayland layer popups

2. **Key patterns to implement:**
   - `LazyLoader` for on-demand loading (line 23-26)
   - `PersistentProperties` for state (lines 7-10)
   - Proper show/hide signals (lines 30-38)

3. **Update existing modals to use new system:**
   ```qml
   PopupHandle {
       delegate: Component { SettingsModal {} }
       show: someBinding
   }
   ```

### Lifecycle Management:
```qml
LazyLoader {
    id: loader
    component: root.delegate
}

Connections {
    target: loader.item
    function onFinished() {
        loader.activeAsync = false;
    }
    function onClosed() {
        root.show = false;
    }
}
```

## Phase 6: Brightness Control System

**Reference:** `~/hyprland_de/quickshell/state/BrightnessState.qml:1-258`

**Current State:** Basic brightness service without DDC support
**Target State:** Full DDC + backlight control with per-monitor support

### Implementation Steps:

1. **DDC Implementation:**
   - Monitor detection via `ddcutil detect` (lines 205-236)
   - Bus mapping to monitors (lines 216-231)
   - Cycling DDC queries (lines 71-91)

2. **Backlight Integration:**
   - Detection via `brightnessctl --list` (lines 118-129)
   - Unified control interface (lines 50-59)

3. **Split vs Unified modes:**
   - Per-monitor control in split mode
   - Synchronized changes in unified mode

### DDC Detection Pattern:
```qml
Process {
    command: ["ddcutil", "detect", "--brief"]
    running: true

    stdout: SplitParser {
        splitMarker: "Display "
        onRead: data => {
            // Parse monitor and map to DDC bus
            if (data.indexOf("-" + monitors[i]) != -1) {
                let b = data.indexOf("i2c-") + 4;
                let e = data.indexOf("\n", b);
                monitorsDdcBuses[i] = parseInt(data.substr(b, e - b));
            }
        }
    }
}
```

## Phase 7: IPC and External Control

**Reference:** Multiple files using `IpcHandler`

**Current State:** No IPC system
**Target State:** Full IPC control for external integration

### Implementation Steps:

1. **Add IPC handlers to key services:**
   ```qml
   IpcHandler {
       target: "serviceName"
       function action() { /* ... */ }
   }
   ```

2. **Implement update system:**
   - Port from `state/UpdateState.qml`
   - Version checking
   - Update notifications via IPC

### IPC Pattern Example:
```qml
IpcHandler {
    target: "update"

    function updated(epoch: int): void {
        UpdateState.setUpdated(epoch);
    }
}

// Usage: quickshell ipc call update updated 1234567890
```

## Phase 8: Widget and Component Upgrades

**Reference:** `~/hyprland_de/quickshell/commonwidgets/`

**Current State:** Basic widgets without advanced features
**Target State:** Professional widgets with consistent patterns

### Implementation Steps:

1. **Upgrade FontIcon/DankIcon:**
   - Add variable font axes support (lines 13-16)
   - OS-specific font detection (line 11)

2. **Add WrapperItem/WrapperRectangle patterns:**
   - Consistent margin system
   - Border and radius inheritance

3. **Implement StyledComponents:**
   - `StyledButton.qml`
   - `StyledSlider.qml`
   - `StyledSwitch.qml`
   - `StyledScrollBar.qml`

### FontIcon Variable Axes:
```qml
Text {
    font {
        family: SystemState.osString == "Fedora Linux"
            ? "Material Icons Outlined"
            : "Material Symbols Outlined"
        pixelSize: iconSize
        variableAxes: {
            "FILL": fill,
            "opsz": iconSize
        }
    }
}
```

## Key Architecture Patterns

### 1. Singleton Service Pattern
```qml
pragma Singleton
pragma ComponentBehavior: Bound

Singleton {
    id: root
    property bool featureAvailable: false

    function load() {
        // Force initialization
    }
}
```

### 2. Lazy Loading Pattern
```qml
LazyLoader {
    id: loader
    component: expensiveComponent
    activeAsync: showCondition
}
```

### 3. State Persistence Pattern
```qml
PersistentProperties {
    id: props
    property bool show: false
}
```

### 4. Process Management Pattern
```qml
Process {
    id: proc
    running: false
    command: ["cmd", "args"]

    stdout: SplitParser {
        splitMarker: ""
        onRead: data => { /* handle */ }
    }
}
```

### 5. Smart Feature Detection
```qml
Process {
    command: ["tool", "--check"]
    onExited: (code) => {
        featureAvailable = code === 0
    }
}
```

## Implementation Priority Order

### Week 1: Configuration System & State Management (Phase 1-2)
- [ ] Implement JSON-based configuration
- [ ] Add live reload capability
- [ ] Update singleton patterns
- [ ] Add lazy loading

### Week 2: Bar Enhancements & OSD (Phase 3-4)
- [ ] Implement compact mode
- [ ] Add edge configuration
- [ ] Create OSD system
- [ ] Add volume/brightness feedback

### Week 3: Popup System & Brightness Control (Phase 5-6)
- [ ] Implement lazy popup loading
- [ ] Add DDC support
- [ ] Integrate backlight control
- [ ] Add per-monitor brightness

### Week 4: IPC System & Widget Upgrades (Phase 7-8)
- [ ] Add IPC handlers
- [ ] Implement update system
- [ ] Upgrade widgets
- [ ] Add styled components

## Testing Checklist

- [ ] Configuration live reload working
- [ ] Compact mode triggers on fullscreen
- [ ] OSD appears for volume/brightness
- [ ] Popups lazy-load correctly
- [ ] DDC brightness control works
- [ ] IPC commands function
- [ ] All animations smooth (60 FPS)
- [ ] Multi-monitor behavior correct
- [ ] Feature detection graceful
- [ ] Error handling robust

## Performance Considerations

1. **Use mask regions** for proper window shapes
2. **Implement lazy loading** for expensive components
3. **Queue updates** to prevent process spam
4. **Use SmoothedAnimation** for state transitions
5. **Leverage PersistentProperties** for state preservation

## Compatibility Notes

- Ensure both Niri and Hyprland compatibility
- Test on various distros (Fedora font detection)
- Verify DDC support availability
- Check for required tools (ddcutil, brightnessctl)
- Handle missing features gracefully

## Resources

- Hyprland DE Source: `~/hyprland_de/quickshell/`
- Quickshell Documentation: https://quickshell.outfoxxed.me/
- Material Design Icons: https://fonts.google.com/icons