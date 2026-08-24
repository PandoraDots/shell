pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia
import qs.services

Singleton {
    id: root

    readonly property string bin: `${Quickshell.env("HOME")}/PandoraProject/scripts/perfectsense`

    property string ec: "balanced"
    property string label: "Balanced"
    property string fans: "0,0"
    property string batteryLimiter: "0"
    property string rgb: ""
    property string logo: ""
    property string usbCharging: "30"
    property string lcdOverride: "0"
    property string backlightTimeout: "0"
    property string bootSound: "1"
    property int cpuRpm: 0
    property int gpuRpm: 0
    property real cpuTemp: 0
    property real gpuTemp: 0
    property var choices: ["low-power", "quiet", "balanced", "balanced-performance", "performance"]
    property bool available: false
    property bool busy: false
    // true = usuário pediu duty manual; curva userspace NÃO atua
    property bool fanCurveManual: false
    property bool fanCurveEnabled: true
    property string displayPreset: "native-240"

    // Modo automático do usuário (curva pode boostar duty no sysfs sem sair de "auto" na UI)
    readonly property bool fansAuto: !fanCurveManual
    readonly property bool cpuFanAuto: {
        if (!fanCurveManual)
            return true;
        const p = fans.split(",");
        return p.length >= 1 && Number(p[0]) === 0;
    }
    readonly property bool gpuFanAuto: {
        if (!fanCurveManual)
            return true;
        const p = fans.split(",");
        return p.length >= 2 && Number(p[1]) === 0;
    }
    readonly property int cpuFanPercent: {
        const p = fans.split(",");
        return Math.max(0, Math.min(100, Number(p[0]) || 0));
    }
    readonly property int gpuFanPercent: {
        const p = fans.split(",");
        return Math.max(0, Math.min(100, Number(p[1]) || 0));
    }

    readonly property string rgbZ1: rgbPart(0, "ff0000")
    readonly property string rgbZ2: rgbPart(1, "ff0000")
    readonly property string rgbZ3: rgbPart(2, "ff0000")
    readonly property string rgbZ4: rgbPart(3, "ff0000")
    readonly property int rgbBrightness: {
        const p = rgb.split(",");
        return Math.max(0, Math.min(100, Number(p[4]) || 0));
    }

    readonly property string logoColor: {
        const p = logo.split(",");
        return (p[0] || "ff0000").toLowerCase();
    }
    readonly property int logoBrightness: {
        const p = logo.split(",");
        return Math.max(0, Math.min(100, Number(p[1]) || 0));
    }
    readonly property bool logoOn: {
        const p = logo.split(",");
        return Number(p[2] || 0) !== 0 && logoColor !== "000000";
    }

    readonly property var primaryMonitor: {
        const mons = Displays.monitors;
        if (!mons || mons.length === 0)
            return null;
        const builtin = mons.find(m => Displays.isBuiltin(m.name));
        if (builtin)
            return builtin;
        const focused = mons.find(m => m.focused);
        return focused || mons[0];
    }
    readonly property string monitorName: primaryMonitor?.name ?? ""
    readonly property string monitorSummary: {
        const m = primaryMonitor;
        if (!m)
            return qsTr("No display");
        const hz = Math.round(Number(m.refreshRate) * 100) / 100;
        const scale = Math.round(Number(m.scale) * 100);
        return `${m.width}×${m.height} @ ${hz} Hz · ${scale}%`;
    }
    readonly property string monitorDetail: {
        const m = primaryMonitor;
        if (!m)
            return "";
        return `${Displays.prettyTitle(m)} · ${m.name}`;
    }

    readonly property var modes: [
        {
            id: "low-power",
            label: qsTr("Eco"),
            icon: "energy_savings_leaf",
            hint: qsTr("FHD-equiv @ 60Hz · lights off · power saver")
        },
        {
            id: "quiet",
            label: qsTr("Quiet"),
            icon: "bedtime",
            hint: qsTr("FHD-equiv @ 60Hz · lights off · quieter fans")
        },
        {
            id: "balanced",
            label: qsTr("Balanced"),
            icon: "balance",
            hint: qsTr("Restores last display preset · everyday use")
        },
        {
            id: "balanced-performance",
            label: qsTr("Performance"),
            icon: "bolt",
            hint: qsTr("Restores last display preset · higher sustained power")
        },
        {
            id: "performance",
            label: qsTr("Turbo"),
            icon: "rocket_launch",
            hint: qsTr("Restores last display preset · maximum EC power")
        }
    ]

    readonly property var displayPresets: [
        {
            id: "fhd-60",
            label: qsTr("1080p · 60 Hz"),
            hint: qsTr("Logical ~1920×1200 @ 60 Hz (scale 133%)")
        },
        {
            id: "fhd-240",
            label: qsTr("1080p · 240 Hz"),
            hint: qsTr("Logical ~1920×1200 @ 240 Hz (scale 133%)")
        },
        {
            id: "native-60",
            label: qsTr("Native · 60 Hz"),
            hint: qsTr("2560×1600 @ 60 Hz (scale 125%)")
        },
        {
            id: "native-240",
            label: qsTr("Native · 240 Hz"),
            hint: qsTr("2560×1600 @ 240 Hz (scale 125%)")
        }
    ]

    function displayPresetLabel(id: string): string {
        for (const p of displayPresets) {
            if (p.id === id)
                return p.label;
        }
        return id;
    }

    function rgbPart(idx: int, fallback: string): string {
        const p = rgb.split(",");
        const v = (p[idx] || fallback).trim().toLowerCase();
        return /^[0-9a-f]{6}$/.test(v) ? v : fallback;
    }

    function refresh(): void {
        statusProc.running = true;
        Displays.refresh();
    }

    function run(args: list<string>): void {
        busy = true;
        actionProc.command = [bin].concat(args);
        actionProc.running = true;
    }

    function setMode(id: string): void {
        run(["mode", "set", id]);
    }

    function setDisplayPreset(id: string): void {
        run(["display", "preset", id]);
    }

    function cycleDisplayPreset(): void {
        run(["display", "cycle"]);
    }

    function setDisplayCustom(output: string, mode: string, scale: real): void {
        const s = (scale && scale > 0) ? `${scale}` : "1";
        run(["display", "set", output, mode, s]);
    }

    function setFanAuto(): void {
        run(["fan", "auto"]);
    }

    function setFan(cpu: int, gpu: int): void {
        const c = Math.max(0, Math.min(100, Math.round(cpu)));
        const g = Math.max(0, Math.min(100, Math.round(gpu)));
        // 0,0 = automático (curva permitida); qualquer outro = manual (curva off)
        if (c === 0 && g === 0)
            run(["fan", "auto"]);
        else
            run(["fan", "set", `${c}`, `${g}`]);
    }

    function setFanCpu(cpu: int): void {
        // Sair do auto e aplicar duty manual na CPU
        const g = gpuFanAuto ? Math.max(1, gpuFanPercent || 40) : Math.max(1, gpuFanPercent);
        setFan(Math.max(1, cpu), g);
    }

    function setFanGpu(gpu: int): void {
        const c = cpuFanAuto ? Math.max(1, cpuFanPercent || 40) : Math.max(1, cpuFanPercent);
        setFan(c, Math.max(1, gpu));
    }

    function setFanCpuAuto(on: bool): void {
        if (on) {
            if (gpuFanAuto)
                setFanAuto();
            else
                setFan(0, Math.max(1, gpuFanPercent || 40));
        } else {
            setFan(Math.max(1, cpuFanPercent || 40), gpuFanAuto ? 0 : Math.max(1, gpuFanPercent || 40));
        }
    }

    function setFanGpuAuto(on: bool): void {
        if (on) {
            if (cpuFanAuto)
                setFanAuto();
            else
                setFan(Math.max(1, cpuFanPercent || 40), 0);
        } else {
            setFan(cpuFanAuto ? 0 : Math.max(1, cpuFanPercent || 40), Math.max(1, gpuFanPercent || 40));
        }
    }

    function setBatteryLimiter(on: bool): void {
        run(["battery", on ? "on" : "off"]);
    }

    function setRgbZones(z1: string, z2: string, z3: string, z4: string, bri: int): void {
        run(["rgb", "set", normHex(z1), normHex(z2), normHex(z3), normHex(z4), `${Math.max(0, Math.min(100, bri))}`]);
    }

    function setRgbOff(): void {
        run(["rgb", "off"]);
    }

    function setLogo(color: string, bri: int, on: bool): void {
        run(["logo", "set", normHex(color), `${Math.max(0, Math.min(100, bri))}`, on ? "1" : "0"]);
    }

    function setAttr(name: string, value: string): void {
        run(["attr", "set", name, value]);
    }

    function resetLights(): void {
        run(["reset-lights"]);
    }

    function gameEnter(): void {
        run(["game", "enter"]);
    }

    function gameLeave(): void {
        run(["game", "leave"]);
    }

    function normHex(v: string): string {
        let s = (v || "").trim().toLowerCase().replace(/^#/, "");
        if (/^[0-9a-f]{3}$/.test(s))
            s = s.split("").map(c => c + c).join("");
        if (!/^[0-9a-f]{6}$/.test(s))
            return "ff0000";
        return s;
    }

    function modeIcon(id: string): string {
        for (const m of modes) {
            if (m.id === id)
                return m.icon;
        }
        return "balance";
    }

    function modeLabel(id: string): string {
        for (const m of modes) {
            if (m.id === id)
                return m.label;
        }
        return id;
    }

    Process {
        id: statusProc

        command: [root.bin, "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const j = JSON.parse(text.trim());
                    root.available = true;
                    root.ec = j.ec || root.ec;
                    root.label = j.label || root.label;
                    // fan_curve antes de fans — para onFansChanged ver auto correto
                    if (j.fan_curve) {
                        root.fanCurveManual = !!j.fan_curve.manual;
                        root.fanCurveEnabled = j.fan_curve.enabled !== false;
                    } else {
                        const fp = String(j.fans || "0,0").split(",");
                        root.fanCurveManual = !(Number(fp[0]) === 0 && Number(fp[1]) === 0);
                    }
                    if (j.display_preset)
                        root.displayPreset = j.display_preset;
                    root.fans = j.fans || "";
                    root.batteryLimiter = `${j.battery_limiter ?? "0"}`;
                    root.rgb = j.rgb || "";
                    root.logo = j.logo || "";
                    root.usbCharging = `${j.usb_charging ?? ""}`;
                    root.lcdOverride = `${j.lcd_override ?? ""}`;
                    root.backlightTimeout = `${j.backlight_timeout ?? ""}`;
                    root.bootSound = `${j.boot_animation_sound ?? ""}`;
                    root.cpuRpm = j.fans_rpm?.cpu ?? 0;
                    root.gpuRpm = j.fans_rpm?.gpu ?? 0;
                    root.cpuTemp = (j.temps_mc?.cpu ?? 0) / 1000;
                    root.gpuTemp = (j.temps_mc?.gpu ?? 0) / 1000;
                    if (j.choices && j.choices.length)
                        root.choices = j.choices;
                } catch (e) {
                    root.available = false;
                }
            }
        }
    }

    Process {
        id: actionProc

        stdout: StdioCollector {
            onStreamFinished: {
                root.busy = false;
                root.refresh();
            }
        }
        stderr: StdioCollector {
            onStreamFinished: root.busy = false
        }
    }

    Timer {
        interval: 2500
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    IpcHandler {
        function status(): string {
            return root.ec;
        }

        function setMode(id: string): void {
            root.setMode(id);
        }

        function refresh(): void {
            root.refresh();
        }

        target: "perfectSense"
    }
}
