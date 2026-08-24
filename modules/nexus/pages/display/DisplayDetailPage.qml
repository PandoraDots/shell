pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services
import qs.modules.nexus.common

PageBase {
    id: root

    readonly property string monitorName: nState.selectedMonitorName
    readonly property var mon: Displays.monitorByName(monitorName)
    readonly property var brightnessMon: Brightness.getMonitor(monitorName)

    readonly property string currentMode: Displays.currentModeString(mon)
    readonly property list<string> modeValues: {
        const modes = (mon?.availableModes ?? []).slice();
        const cur = Displays.currentModeString(mon);
        if (cur && !modes.includes(cur))
            modes.unshift(cur);
        return modes;
    }

    property list<MenuItem> modeItems: []
    property int modeIndex
    property list<MenuItem> mirrorItems: []
    property int mirrorIndex

    readonly property list<MenuItem> presetItems: [
        MenuItem {
            text: qsTr("Preferred")
        },
        MenuItem {
            text: qsTr("Highest refresh")
        },
        MenuItem {
            text: qsTr("Highest resolution")
        }
    ]

    readonly property list<MenuItem> scaleItems: [
        MenuItem {
            text: "100%"
        },
        MenuItem {
            text: "125%"
        },
        MenuItem {
            text: "150%"
        },
        MenuItem {
            text: "175%"
        },
        MenuItem {
            text: "200%"
        },
        MenuItem {
            text: "250%"
        },
        MenuItem {
            text: "300%"
        }
    ]

    readonly property int scaleIndex: {
        const scale = Number(mon?.scale ?? 1);
        let best = 0;
        let bestDiff = Infinity;
        for (let i = 0; i < Displays.scaleChoices.length; i++) {
            const diff = Math.abs(Displays.scaleChoices[i] - scale);
            if (diff < bestDiff) {
                bestDiff = diff;
                best = i;
            }
        }
        return best;
    }

    readonly property list<MenuItem> transformItems: [
        MenuItem {
            text: qsTr("Normal")
        },
        MenuItem {
            text: qsTr("90°")
        },
        MenuItem {
            text: qsTr("180°")
        },
        MenuItem {
            text: qsTr("270°")
        }
    ]

    readonly property int transformIndex: {
        const t = Number(mon?.transform ?? 0);
        const idx = Displays.transformChoices.findIndex(c => c.value === t);
        return idx >= 0 ? idx : 0;
    }

    readonly property bool onlyDisplay: Displays.monitors.filter(m => !m.disabled).length <= 1

    function rebuildModeItems(): void {
        for (let i = modeItems.length - 1; i >= 0; i--)
            modeItems[i].destroy();

        const items = [];
        const modes = root.modeValues;
        for (let i = 0; i < modes.length; i++)
            items.push(modeItemComp.createObject(root, {
                    text: Displays.modeLabel(modes[i])
                }));
        modeItems = items;

        let idx = modes.indexOf(root.currentMode);
        if (idx < 0) {
            const hypr = Displays.modeToHypr(root.currentMode);
            idx = modes.findIndex(m => Displays.modeToHypr(m) === hypr);
        }
        modeIndex = Math.max(0, idx);
    }

    function rebuildMirrorItems(): void {
        for (let i = mirrorItems.length - 1; i >= 0; i--)
            mirrorItems[i].destroy();

        const items = [];
        items.push(modeItemComp.createObject(root, {
                text: qsTr("None")
            }));
        for (const m of Displays.monitors) {
            if (m.name === monitorName)
                continue;
            items.push(modeItemComp.createObject(root, {
                    text: `${Displays.prettyTitle(m)} (${m.name})`
                }));
        }
        mirrorItems = items;

        const mirrorOf = mon?.mirrorOf ?? "none";
        if (!mirrorOf || mirrorOf === "none") {
            mirrorIndex = 0;
            return;
        }
        let i = 1;
        for (const m of Displays.monitors) {
            if (m.name === monitorName)
                continue;
            if (m.name === mirrorOf) {
                mirrorIndex = i;
                return;
            }
            i++;
        }
        mirrorIndex = 0;
    }

    function rebuildMenus(): void {
        rebuildModeItems();
        rebuildMirrorItems();
    }

    onMonChanged: {
        if (!monitorName)
            return;
        if (!mon) {
            Displays.refresh();
            if (!Displays.loading)
                nState.closeSubPage();
            return;
        }
        rebuildMenus();
    }

    onModeValuesChanged: rebuildModeItems()
    Component.onCompleted: rebuildMenus()

    title: mon ? Displays.prettyTitle(mon) : qsTr("Display")
    isSubPage: true

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        Component {
            id: modeItemComp

            MenuItem {}
        }

        Timer {
            running: root.visible
            interval: 1500
            repeat: true
            onTriggered: Displays.refresh()
        }

        SectionHeader {
            first: true
            text: qsTr("Overview")
        }

        InfoRow {
            first: true
            label: qsTr("Connector")
            value: mon?.name ?? "—"
            icon: Displays.iconFor(monitorName)
        }

        InfoRow {
            label: qsTr("Type")
            value: Displays.kindLabel(monitorName)
        }

        InfoRow {
            label: qsTr("Make & model")
            value: {
                const make = (mon?.make || "").trim();
                const model = (mon?.model || "").trim();
                const serial = (mon?.serial || "").trim();
                const base = `${make} ${model}`.trim() || "—";
                return serial ? `${base} · ${serial}` : base;
            }
        }

        InfoRow {
            last: brightnessMon ? false : true
            label: qsTr("Status")
            value: {
                if (!mon)
                    return "—";
                if (mon.disabled)
                    return qsTr("Disabled");
                return mon.focused ? qsTr("Focused") : qsTr("Connected");
            }
        }

        SliderRow {
            visible: !!brightnessMon
            last: true
            icon: "brightness_6"
            label: qsTr("Brightness")
            valueLabel: brightnessMon ? `${Math.round(brightnessMon.brightness * 100)}%` : ""
            value: brightnessMon?.brightness ?? 0
            onMoved: v => {
                if (root.brightnessMon)
                    root.brightnessMon.setBrightness(v);
            }
        }

        SectionHeader {
            text: qsTr("Mode")
        }

        SelectRow {
            first: true
            label: qsTr("Resolution & refresh rate")
            subtext: qsTr("Modes reported by the display")
            menuItems: root.modeItems
            active: root.modeItems[root.modeIndex] ?? null
            fallbackText: qsTr("Select mode")
            onSelected: item => {
                const idx = root.modeItems.indexOf(item);
                if (idx < 0)
                    return;
                const mode = root.modeValues[idx];
                Displays.apply({
                    name: root.monitorName,
                    mode: Displays.modeToHypr(mode),
                    position: root.mon ? `${root.mon.x}x${root.mon.y}` : "auto",
                    scale: root.mon?.scale ?? 1,
                    transform: root.mon?.transform ?? 0
                });
                root.modeIndex = idx;
                Toaster.toast(qsTr("Display mode updated"), Displays.modeLabel(mode), "monitor");
            }
        }

        SelectRow {
            label: qsTr("Quick preset")
            subtext: qsTr("Let Hyprland pick a mode")
            menuItems: root.presetItems
            active: null
            fallbackText: qsTr("Choose preset")
            fallbackIcon: "tune"
            onSelected: item => {
                const idx = root.presetItems.indexOf(item);
                if (idx === 0)
                    Displays.resetPreferred(root.monitorName);
                else if (idx === 1)
                    Displays.highestRefresh(root.monitorName);
                else if (idx === 2)
                    Displays.highestResolution(root.monitorName);
                Toaster.toast(qsTr("Display preset applied"), item.text, "monitor");
            }
        }

        SelectRow {
            last: true
            label: qsTr("Scale")
            subtext: qsTr("UI scaling for this output")
            menuItems: root.scaleItems
            active: root.scaleItems[root.scaleIndex] ?? null
            fallbackText: qsTr("Scale")
            onSelected: item => {
                const idx = root.scaleItems.indexOf(item);
                if (idx < 0)
                    return;
                Displays.applyScale(root.monitorName, Displays.scaleChoices[idx]);
                Toaster.toast(qsTr("Scale updated"), item.text, "monitor");
            }
        }

        SectionHeader {
            text: qsTr("Arrangement")
        }

        StepperRow {
            first: true
            label: qsTr("Position X")
            subtext: qsTr("Pixels from the left of the layout")
            value: mon?.x ?? 0
            from: -7680
            to: 7680
            stepSize: 1
            onMoved: v => Displays.applyPosition(root.monitorName, Math.round(v), root.mon?.y ?? 0)
        }

        StepperRow {
            label: qsTr("Position Y")
            subtext: qsTr("Pixels from the top of the layout")
            value: mon?.y ?? 0
            from: -7680
            to: 7680
            stepSize: 1
            onMoved: v => Displays.applyPosition(root.monitorName, root.mon?.x ?? 0, Math.round(v))
        }

        SelectRow {
            label: qsTr("Orientation")
            menuItems: root.transformItems
            active: root.transformItems[root.transformIndex] ?? null
            fallbackText: qsTr("Orientation")
            onSelected: item => {
                const idx = root.transformItems.indexOf(item);
                if (idx < 0)
                    return;
                Displays.applyTransform(root.monitorName, Displays.transformChoices[idx].value);
                Toaster.toast(qsTr("Orientation updated"), item.text, "screen_rotation");
            }
        }

        SelectRow {
            last: true
            label: qsTr("Mirror")
            subtext: qsTr("Duplicate another display")
            menuItems: root.mirrorItems
            active: root.mirrorItems[root.mirrorIndex] ?? null
            fallbackText: qsTr("None")
            onSelected: item => {
                const idx = root.mirrorItems.indexOf(item);
                if (idx <= 0) {
                    Displays.apply({
                        name: root.monitorName,
                        mode: root.mon ? Displays.modeToHypr(root.currentMode) : "preferred",
                        position: "auto",
                        scale: root.mon?.scale ?? 1,
                        transform: root.mon?.transform ?? 0
                    });
                    root.mirrorIndex = 0;
                    Toaster.toast(qsTr("Mirror disabled"), qsTr("Display is independent again"), "monitor");
                    return;
                }
                let i = 1;
                for (const m of Displays.monitors) {
                    if (m.name === root.monitorName)
                        continue;
                    if (i === idx) {
                        Displays.apply({
                            name: root.monitorName,
                            mode: root.mon ? Displays.modeToHypr(root.currentMode) : "preferred",
                            position: "auto",
                            scale: root.mon?.scale ?? 1,
                            transform: root.mon?.transform ?? 0,
                            mirror: m.name
                        });
                        root.mirrorIndex = idx;
                        Toaster.toast(qsTr("Mirroring"), m.name, "monitor");
                        return;
                    }
                    i++;
                }
            }
        }

        SectionHeader {
            text: qsTr("Options")
        }

        ToggleRow {
            first: true
            text: qsTr("Variable refresh rate")
            subtext: qsTr("Adaptive sync / FreeSync / G-Sync")
            checked: Number(mon?.vrr ?? 0) > 0
            onToggled: {
                Displays.applyVrr(root.monitorName, checked);
                Toaster.toast(checked ? qsTr("VRR enabled") : qsTr("VRR disabled"), root.monitorName, "monitor");
            }
        }

        ToggleRow {
            text: qsTr("Enabled")
            subtext: root.onlyDisplay ? qsTr("Keep at least one display on") : qsTr("Turn this output off")
            checked: !(mon?.disabled ?? false)
            disabled: root.onlyDisplay && !(mon?.disabled ?? false)
            onToggled: Displays.setDisabled(root.monitorName, !checked)
        }

        RowButton {
            last: true
            icon: "restart_alt"
            text: qsTr("Reset to preferred")
            subtext: qsTr("Preferred mode, auto position, 100% scale")
            onClicked: {
                Displays.resetPreferred(root.monitorName);
                Toaster.toast(qsTr("Display reset"), qsTr("Preferred mode restored"), "monitor");
            }
        }
    }
}
