pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Caelestia
import qs.services

Singleton {
    id: root

    property list<var> monitors: []
    property bool loading: false

    readonly property list<real> scaleChoices: [1.0, 1.25, 1.5, 1.75, 2.0, 2.5, 3.0]

    readonly property list<var> transformChoices: [
        {
            value: 0,
            label: qsTr("Normal")
        },
        {
            value: 1,
            label: qsTr("90°")
        },
        {
            value: 2,
            label: qsTr("180°")
        },
        {
            value: 3,
            label: qsTr("270°")
        }
    ]

    function refresh(): void {
        if (proc.running)
            return;
        loading = true;
        proc.running = true;
    }

    function monitorByName(name: string): var {
        return monitors.find(m => m.name === name) ?? null;
    }

    function isBuiltin(name: string): bool {
        return /^(eDP|LVDS|DSI|DPI)-/i.test(name ?? "");
    }

    function iconFor(name: string): string {
        return isBuiltin(name) ? "laptop_chromebook" : "monitor";
    }

    function kindLabel(name: string): string {
        return isBuiltin(name) ? qsTr("Built-in display") : qsTr("External display");
    }

    function prettyTitle(mon: var): string {
        if (!mon)
            return qsTr("Display");
        const desc = (mon.description || "").trim();
        if (desc)
            return desc;
        const make = (mon.make || "").trim();
        const model = (mon.model || "").trim();
        if (make || model)
            return `${make} ${model}`.trim();
        return mon.name;
    }

    function modeLabel(mode: string): string {
        const m = String(mode).match(/^(\d+)x(\d+)@([\d.]+)\s*Hz$/i);
        if (!m)
            return mode;
        const hz = Number(m[3]);
        const hzText = Number.isInteger(hz) ? String(hz) : hz.toFixed(2).replace(/\.?0+$/, "");
        return `${m[1]}×${m[2]} @ ${hzText} Hz`;
    }

    function modeToHypr(mode: string): string {
        const m = String(mode).match(/^(\d+)x(\d+)@([\d.]+)\s*Hz$/i);
        if (!m)
            return mode;
        const hz = Number(m[3]);
        const hzText = Number.isInteger(hz) ? String(hz) : String(Math.round(hz * 100) / 100);
        return `${m[1]}x${m[2]}@${hzText}`;
    }

    // Modos “principais”: por resolução, 60 Hz (se existir) + maior Hz
    function mainModes(mon: var): var {
        if (!mon)
            return [];
        const modes = mon.availableModes ?? [];
        const byRes = {};
        for (const mode of modes) {
            const m = String(mode).match(/^(\d+)x(\d+)@([\d.]+)\s*Hz$/i);
            if (!m)
                continue;
            const key = `${m[1]}x${m[2]}`;
            const hz = Number(m[3]);
            if (!byRes[key])
                byRes[key] = [];
            byRes[key].push({
                mode: mode,
                hz: hz
            });
        }
        const out = [];
        const keys = Object.keys(byRes).sort((a, b) => {
            const [aw, ah] = a.split("x").map(Number);
            const [bw, bh] = b.split("x").map(Number);
            return (bw * bh) - (aw * ah);
        });
        for (const key of keys) {
            const list = byRes[key].sort((a, b) => a.hz - b.hz);
            const at60 = list.find(x => Math.abs(x.hz - 60) < 0.5);
            const max = list[list.length - 1];
            if (at60)
                out.push(at60.mode);
            if (max && (!at60 || Math.abs(max.hz - at60.hz) > 0.5))
                out.push(max.mode);
        }
        return out;
    }

    function hasHighRefresh(mon: var): bool {
        if (!mon)
            return false;
        if (Number(mon.refreshRate) > 60.5)
            return true;
        const modes = mon.availableModes ?? [];
        for (const mode of modes) {
            const m = String(mode).match(/@([\d.]+)\s*Hz$/i);
            if (m && Number(m[1]) > 60.5)
                return true;
        }
        return false;
    }

    function currentModeString(mon: var): string {
        if (!mon)
            return "";
        const modes = mon.availableModes ?? [];
        const targetW = mon.width;
        const targetH = mon.height;
        const targetHz = Number(mon.refreshRate);
        let best = "";
        let bestDiff = Infinity;
        for (const mode of modes) {
            const m = String(mode).match(/^(\d+)x(\d+)@([\d.]+)\s*Hz$/i);
            if (!m)
                continue;
            if (Number(m[1]) !== targetW || Number(m[2]) !== targetH)
                continue;
            const diff = Math.abs(Number(m[3]) - targetHz);
            if (diff < bestDiff) {
                bestDiff = diff;
                best = mode;
            }
        }
        if (best)
            return best;
        const hz = Number.isFinite(targetHz) ? (Math.round(targetHz * 100) / 100) : 60;
        return `${targetW}x${targetH}@${hz}Hz`;
    }

    function summary(mon: var): string {
        if (!mon)
            return "";
        const hz = Math.round(Number(mon.refreshRate) * 100) / 100;
        const scalePct = Math.round(Number(mon.scale) * 100);
        return `${mon.width}×${mon.height} @ ${hz} Hz · ${scalePct}%`;
    }

    function apply(opts: var): void {
        const name = opts.name ?? "";
        if (!name)
            return;

        const parts = [`output = "${name}"`];

        if (opts.mode !== undefined && opts.mode !== null && opts.mode !== "")
            parts.push(`mode = "${opts.mode}"`);
        if (opts.position !== undefined && opts.position !== null && opts.position !== "")
            parts.push(`position = "${opts.position}"`);
        if (opts.scale !== undefined && opts.scale !== null)
            parts.push(`scale = ${Number(opts.scale)}`);
        if (opts.transform !== undefined && opts.transform !== null)
            parts.push(`transform = ${Number(opts.transform)}`);
        if (opts.mirror !== undefined && opts.mirror !== null && opts.mirror !== "")
            parts.push(`mirror = "${opts.mirror}"`);
        if (opts.vrr !== undefined && opts.vrr !== null)
            parts.push(`vrr = ${Number(opts.vrr)}`);

        Hypr.extras.batchMessage([`eval hl.monitor({ ${parts.join(", ")} })`]);
        refreshTimer.restart();
    }

    function applyMode(name: string, mode: string): void {
        apply({
            name: name,
            mode: mode
        });
    }

    function applyScale(name: string, scale: real): void {
        const mon = monitorByName(name);
        apply({
            name: name,
            mode: mon ? modeToHypr(currentModeString(mon)) : "preferred",
            position: mon ? `${mon.x}x${mon.y}` : "auto",
            scale: scale,
            transform: mon?.transform ?? 0
        });
    }

    function applyPosition(name: string, x: int, y: int): void {
        const mon = monitorByName(name);
        apply({
            name: name,
            mode: mon ? modeToHypr(currentModeString(mon)) : "preferred",
            position: `${x}x${y}`,
            scale: mon?.scale ?? 1,
            transform: mon?.transform ?? 0
        });
    }

    function applyTransform(name: string, transform: int): void {
        const mon = monitorByName(name);
        apply({
            name: name,
            mode: mon ? modeToHypr(currentModeString(mon)) : "preferred",
            position: mon ? `${mon.x}x${mon.y}` : "auto",
            scale: mon?.scale ?? 1,
            transform: transform
        });
    }

    function applyVrr(name: string, enabled: bool): void {
        const mon = monitorByName(name);
        apply({
            name: name,
            mode: mon ? modeToHypr(currentModeString(mon)) : "preferred",
            position: mon ? `${mon.x}x${mon.y}` : "auto",
            scale: mon?.scale ?? 1,
            transform: mon?.transform ?? 0,
            vrr: enabled ? 1 : 0
        });
    }

    function setDisabled(name: string, disabled: bool): void {
        if (disabled) {
            apply({
                name: name,
                mode: "disable"
            });
        } else {
            apply({
                name: name,
                mode: "preferred",
                position: "auto",
                scale: 1
            });
        }
    }

    function resetPreferred(name: string): void {
        apply({
            name: name,
            mode: "preferred",
            position: "auto",
            scale: 1,
            transform: 0
        });
    }

    function highestRefresh(name: string): void {
        applyMode(name, "highrr");
    }

    function highestResolution(name: string): void {
        applyMode(name, "highres");
    }

    Component.onCompleted: refresh()

    Connections {
        target: Hypr

        function onConfigReloaded(): void {
            root.refresh();
        }
    }

    Connections {
        target: Hyprland

        function onRawEvent(event: HyprlandEvent): void {
            const n = event.name;
            if (n.endsWith("v2"))
                return;
            if (n.includes("mon") || n === "configreloaded" || n === "focusedmon")
                refreshTimer.restart();
        }
    }

    Timer {
        id: refreshTimer

        interval: 250
        onTriggered: root.refresh()
    }

    Process {
        id: proc

        command: ["hyprctl", "-j", "monitors"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.loading = false;
                try {
                    const data = JSON.parse(text);
                    root.monitors = Array.isArray(data) ? data : [];
                } catch (e) {
                    root.monitors = [];
                }
            }
        }
        stderr: StdioCollector {}
        onExited: code => {
            if (code !== 0)
                root.loading = false;
        }
    }
}
