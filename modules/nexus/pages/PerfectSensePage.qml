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

    title: qsTr("PerfectSense")

    property int draftCpuFan: 40
    property int draftGpuFan: 40
    property bool draftCpuAuto: true
    property bool draftGpuAuto: true
    property string draftZ1: PerfectSense.rgbZ1
    property string draftZ2: PerfectSense.rgbZ2
    property string draftZ3: PerfectSense.rgbZ3
    property string draftZ4: PerfectSense.rgbZ4
    property int draftRgbBri: PerfectSense.rgbBrightness
    property string draftLogoColor: PerfectSense.logoColor
    property int draftLogoBri: PerfectSense.logoBrightness
    property bool syncing: false

    function pullFromService(): void {
        syncing = true;
        draftCpuAuto = PerfectSense.cpuFanAuto;
        draftGpuAuto = PerfectSense.gpuFanAuto;
        if (!PerfectSense.cpuFanAuto)
            draftCpuFan = Math.max(1, PerfectSense.cpuFanPercent);
        if (!PerfectSense.gpuFanAuto)
            draftGpuFan = Math.max(1, PerfectSense.gpuFanPercent);
        draftZ1 = PerfectSense.rgbZ1;
        draftZ2 = PerfectSense.rgbZ2;
        draftZ3 = PerfectSense.rgbZ3;
        draftZ4 = PerfectSense.rgbZ4;
        draftRgbBri = PerfectSense.rgbBrightness || 60;
        draftLogoColor = PerfectSense.logoColor;
        draftLogoBri = PerfectSense.logoBrightness || 70;
        syncing = false;
    }

    function applyFansNow(): void {
        PerfectSense.setFan(draftCpuAuto ? 0 : draftCpuFan, draftGpuAuto ? 0 : draftGpuFan);
    }

    function toggleCpuAuto(): void {
        if (draftCpuAuto) {
            draftCpuAuto = false;
            if (draftCpuFan < 1)
                draftCpuFan = 40;
        } else {
            draftCpuAuto = true;
        }
        applyFansNow();
    }

    function toggleGpuAuto(): void {
        if (draftGpuAuto) {
            draftGpuAuto = false;
            if (draftGpuFan < 1)
                draftGpuFan = 40;
        } else {
            draftGpuAuto = true;
        }
        applyFansNow();
    }

    Component.onCompleted: {
        PerfectSense.refresh();
        pullFromService();
    }

    readonly property list<MenuItem> usbItems: [
        MenuItem {
            text: qsTr("Off")
        },
        MenuItem {
            text: qsTr("10 minutes")
        },
        MenuItem {
            text: qsTr("20 minutes")
        },
        MenuItem {
            text: qsTr("30 minutes")
        }
    ]
    readonly property list<string> usbValues: ["0", "10", "20", "30"]
    readonly property int usbIndex: {
        const i = usbValues.indexOf(PerfectSense.usbCharging);
        return i >= 0 ? i : 0;
    }

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        Connections {
            target: PerfectSense
            function onFansChanged(): void {
                if (!fanDebounce.running)
                    root.pullFromService();
            }
            function onFanCurveManualChanged(): void {
                if (!fanDebounce.running)
                    root.pullFromService();
            }
            function onRgbChanged(): void {
                if (!root.syncing)
                    root.pullFromService();
            }
            function onLogoChanged(): void {
                if (!root.syncing)
                    root.pullFromService();
            }
        }

        Timer {
            id: fanDebounce
            interval: 280
            onTriggered: root.applyFansNow()
        }

        // Status
        SectionHeader {
            first: true
            text: qsTr("Status")
        }

        InfoRow {
            first: true
            icon: "sensors"
            label: qsTr("EC power mode")
            value: PerfectSense.available ? PerfectSense.label : qsTr("Unavailable")
            subtext: qsTr("Embedded controller profile from nekro_sense")
        }

        InfoRow {
            icon: "thermostat"
            label: qsTr("Temperatures")
            value: `${Math.round(PerfectSense.cpuTemp)}° / ${Math.round(PerfectSense.gpuTemp)}°`
            subtext: qsTr("CPU and GPU package temperatures from the Acer hwmon sensor")
        }

        InfoRow {
            icon: "mode_fan"
            label: qsTr("Fan speeds")
            value: `${PerfectSense.cpuRpm || "—"} / ${PerfectSense.gpuRpm || "—"} rpm`
            subtext: qsTr("Measured CPU and GPU fan RPM")
        }

        InfoRow {
            last: false
            icon: "laptop_chromebook"
            label: qsTr("Primary display")
            value: PerfectSense.monitorSummary
            subtext: PerfectSense.monitorDetail || qsTr("Built-in panel · click presets below")
        }

        // Built-in display presets
        SectionHeader {
            text: qsTr("Built-in display presets")
        }

        ConnectedRect {
            Layout.fillWidth: true
            first: true
            last: true
            implicitHeight: dispCol.implicitHeight + Tokens.padding.large * 2

            ColumnLayout {
                id: dispCol

                anchors.fill: parent
                anchors.margins: Tokens.padding.large
                anchors.leftMargin: Tokens.padding.largeIncreased
                anchors.rightMargin: Tokens.padding.largeIncreased
                spacing: Tokens.spacing.small

                StyledText {
                    Layout.fillWidth: true
                    text: qsTr("Panel only exposes 2560×1600 @ 60/240. “1080p” uses scale 133% (logical ~1920×1200). Eco/Quiet force FHD·60; other modes restore your last preset.")
                    wrapMode: Text.WordWrap
                    color: Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.body.small
                }

                Flow {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.small

                    Repeater {
                        model: PerfectSense.displayPresets

                        StyledRect {
                            id: presetChip

                            required property var modelData
                            readonly property bool active: PerfectSense.displayPreset === modelData.id

                            implicitWidth: presetRow.implicitWidth + Tokens.padding.medium * 2
                            implicitHeight: presetRow.implicitHeight + Tokens.padding.small
                            radius: Tokens.rounding.full
                            color: active ? Colours.palette.m3primary : Colours.tPalette.m3surfaceContainerHighest

                            StateLayer {
                                radius: parent.radius
                                color: presetChip.active ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
                                onClicked: PerfectSense.setDisplayPreset(presetChip.modelData.id)
                            }

                            Row {
                                id: presetRow
                                anchors.centerIn: parent
                                spacing: Tokens.spacing.extraSmall

                                MaterialIcon {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "tv"
                                    fontStyle: Tokens.font.icon.small
                                    color: presetChip.active ? Colours.palette.m3onPrimary : Colours.palette.m3onSurfaceVariant
                                }

                                StyledText {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: presetChip.modelData.label
                                    font: Tokens.font.label.medium
                                    color: presetChip.active ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
                                }
                            }
                        }
                    }
                }

                StyledText {
                    Layout.fillWidth: true
                    text: {
                        const p = PerfectSense.displayPresets.find(x => x.id === PerfectSense.displayPreset);
                        return p ? p.hint : "";
                    }
                    color: Colours.palette.m3outline
                    font: Tokens.font.label.small
                }
            }
        }

        // External displays (>60 Hz): main modes + manual
        Repeater {
            model: Displays.monitors.filter(m => !Displays.isBuiltin(m.name) && Displays.hasHighRefresh(m))

            ColumnLayout {
                id: extBlock

                required property var modelData
                Layout.fillWidth: true
                spacing: Tokens.spacing.extraSmall

                property string manualMode: ""

                SectionHeader {
                    text: qsTr("External · %1").arg(Displays.prettyTitle(extBlock.modelData))
                }

                ConnectedRect {
                    Layout.fillWidth: true
                    first: true
                    last: true
                    implicitHeight: extCol.implicitHeight + Tokens.padding.large * 2

                    ColumnLayout {
                        id: extCol

                        anchors.fill: parent
                        anchors.margins: Tokens.padding.large
                        anchors.leftMargin: Tokens.padding.largeIncreased
                        anchors.rightMargin: Tokens.padding.largeIncreased
                        spacing: Tokens.spacing.small

                        StyledText {
                            Layout.fillWidth: true
                            text: Displays.summary(extBlock.modelData)
                            color: Colours.palette.m3onSurfaceVariant
                            font: Tokens.font.body.small
                        }

                        Flow {
                            Layout.fillWidth: true
                            spacing: Tokens.spacing.small

                            Repeater {
                                model: Displays.mainModes(extBlock.modelData)

                                StyledRect {
                                    id: extModeChip

                                    required property string modelData
                                    readonly property bool active: Displays.currentModeString(extBlock.modelData) === modelData

                                    implicitWidth: extModeTxt.implicitWidth + Tokens.padding.medium * 2
                                    implicitHeight: extModeTxt.implicitHeight + Tokens.padding.small
                                    radius: Tokens.rounding.full
                                    color: active ? Colours.palette.m3secondary : Colours.tPalette.m3surfaceContainerHighest

                                    StateLayer {
                                        radius: parent.radius
                                        onClicked: Displays.applyMode(extBlock.modelData.name, Displays.modeToHypr(extModeChip.modelData))
                                    }

                                    StyledText {
                                        id: extModeTxt
                                        anchors.centerIn: parent
                                        text: Displays.modeLabel(extModeChip.modelData)
                                        font: Tokens.font.label.medium
                                        color: extModeChip.active ? Colours.palette.m3onSecondary : Colours.palette.m3onSurface
                                    }
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Tokens.spacing.small

                            StyledTextField {
                                id: manualField
                                Layout.fillWidth: true
                                placeholderText: qsTr("e.g. 1920x1080@144")
                                text: extBlock.manualMode
                                onEditingFinished: extBlock.manualMode = text.trim()
                            }

                            StyledRect {
                                id: applyChip
                                implicitWidth: applyRow.implicitWidth + Tokens.padding.medium * 2
                                implicitHeight: applyRow.implicitHeight + Tokens.padding.small
                                radius: Tokens.rounding.full
                                color: Colours.palette.m3primary

                                StateLayer {
                                    radius: parent.radius
                                    color: Colours.palette.m3onPrimary
                                    onClicked: {
                                        const mode = (manualField.text || extBlock.manualMode || "").trim();
                                        if (!mode)
                                            return;
                                        PerfectSense.setDisplayCustom(extBlock.modelData.name, mode, Number(extBlock.modelData.scale) || 1);
                                        Displays.refresh();
                                    }
                                }

                                Row {
                                    id: applyRow
                                    anchors.centerIn: parent
                                    spacing: Tokens.spacing.extraSmall

                                    MaterialIcon {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "check"
                                        fontStyle: Tokens.font.icon.small
                                        color: Colours.palette.m3onPrimary
                                    }

                                    StyledText {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: qsTr("Apply")
                                        font: Tokens.font.label.medium
                                        color: Colours.palette.m3onPrimary
                                    }
                                }
                            }
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: qsTr("Manual mode: WIDTH×HEIGHT@Hz (panel must support it)")
                            color: Colours.palette.m3outline
                            font: Tokens.font.label.small
                        }
                    }
                }
            }
        }

        // Power modes
        SectionHeader {
            text: qsTr("Power modes")
        }

        ConnectedRect {
            Layout.fillWidth: true
            first: true
            last: true
            implicitHeight: modesCol.implicitHeight + Tokens.padding.large * 2

            ColumnLayout {
                id: modesCol

                anchors.fill: parent
                anchors.margins: Tokens.padding.large
                anchors.leftMargin: Tokens.padding.largeIncreased
                anchors.rightMargin: Tokens.padding.largeIncreased
                spacing: Tokens.spacing.small

                StyledText {
                    Layout.fillWidth: true
                    text: qsTr("Eco and Quiet switch the built-in panel to 1080p-equivalent (scale 133% @ 60 Hz), disable animations, and turn lighting off. Other modes restore your last display preset.")
                    wrapMode: Text.WordWrap
                    color: Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.body.small
                }

                Flow {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.small

                    Repeater {
                        model: PerfectSense.modes

                        StyledRect {
                            id: modeChip

                            required property var modelData

                            readonly property bool active: PerfectSense.ec === modelData.id

                            implicitWidth: modeRow.implicitWidth + Tokens.padding.medium * 2
                            implicitHeight: modeRow.implicitHeight + Tokens.padding.small
                            radius: Tokens.rounding.full
                            color: active ? Colours.palette.m3primary : Colours.tPalette.m3surfaceContainerHighest

                            StateLayer {
                                radius: parent.radius
                                color: modeChip.active ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
                                onClicked: PerfectSense.setMode(modeChip.modelData.id)
                            }

                            Row {
                                id: modeRow

                                anchors.centerIn: parent
                                spacing: Tokens.spacing.extraSmall

                                MaterialIcon {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: modeChip.modelData.icon
                                    fontStyle: Tokens.font.icon.small
                                    color: modeChip.active ? Colours.palette.m3onPrimary : Colours.palette.m3onSurfaceVariant
                                    fill: modeChip.active ? 1 : 0
                                }

                                StyledText {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: modeChip.modelData.label
                                    font: Tokens.font.label.medium
                                    color: modeChip.active ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
                                }
                            }
                        }
                    }
                }

                StyledText {
                    Layout.fillWidth: true
                    text: {
                        const m = PerfectSense.modes.find(x => x.id === PerfectSense.ec);
                        return m ? m.hint : "";
                    }
                    color: Colours.palette.m3outline
                    font: Tokens.font.label.small
                }
            }
        }

        // Fans
        SectionHeader {
            text: qsTr("Fans")
        }

        ConnectedRect {
            Layout.fillWidth: true
            first: true
            last: true
            implicitHeight: fansCol.implicitHeight + Tokens.padding.large * 2

            ColumnLayout {
                id: fansCol

                anchors.fill: parent
                anchors.margins: Tokens.padding.large
                anchors.leftMargin: Tokens.padding.largeIncreased
                anchors.rightMargin: Tokens.padding.largeIncreased
                spacing: Tokens.spacing.medium

                StyledText {
                    Layout.fillWidth: true
                    text: qsTr("Each fan can follow the EC curve (Auto) or a fixed duty. While Auto is on for a fan, its slider and percentage are locked. Manual values are a percentage of maximum speed — higher is louder and uses more power.")
                    wrapMode: Text.WordWrap
                    color: Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.body.small
                }

                FanControl {
                    label: qsTr("CPU fan")
                    subtext: qsTr("Cooler for the CPU package")
                    value: root.draftCpuFan
                    rpm: PerfectSense.cpuRpm
                    autoMode: root.draftCpuAuto
                    onToggleAuto: root.toggleCpuAuto()
                    onMoved: v => {
                        if (root.draftCpuAuto)
                            return;
                        root.draftCpuFan = Math.max(1, v);
                        fanDebounce.restart();
                    }
                }

                FanControl {
                    label: qsTr("GPU fan")
                    subtext: qsTr("Cooler for the discrete GPU")
                    value: root.draftGpuFan
                    rpm: PerfectSense.gpuRpm
                    autoMode: root.draftGpuAuto
                    onToggleAuto: root.toggleGpuAuto()
                    onMoved: v => {
                        if (root.draftGpuAuto)
                            return;
                        root.draftGpuFan = Math.max(1, v);
                        fanDebounce.restart();
                    }
                }
            }
        }

        // Keyboard RGB
        SectionHeader {
            text: qsTr("Keyboard RGB")
        }

        ConnectedRect {
            Layout.fillWidth: true
            first: true
            last: false
            implicitHeight: rgbIntro.implicitHeight + Tokens.padding.large * 2

            StyledText {
                id: rgbIntro

                anchors.fill: parent
                anchors.margins: Tokens.padding.large
                anchors.leftMargin: Tokens.padding.largeIncreased
                anchors.rightMargin: Tokens.padding.largeIncreased
                text: qsTr("Four-zone per-key lighting on the Predator keyboard. Each zone is an RRGGBB colour. Brightness is a shared 0–100 value written to the EC.")
                wrapMode: Text.WordWrap
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.body.small
            }
        }

        HexRow {
            label: qsTr("Zone 1")
            subtext: qsTr("Leftmost keyboard zone")
            value: root.draftZ1
            onEditingFinished: v => root.draftZ1 = PerfectSense.normHex(v)
        }

        HexRow {
            label: qsTr("Zone 2")
            subtext: qsTr("Centre-left zone")
            value: root.draftZ2
            onEditingFinished: v => root.draftZ2 = PerfectSense.normHex(v)
        }

        HexRow {
            label: qsTr("Zone 3")
            subtext: qsTr("Centre-right zone")
            value: root.draftZ3
            onEditingFinished: v => root.draftZ3 = PerfectSense.normHex(v)
        }

        HexRow {
            label: qsTr("Zone 4")
            subtext: qsTr("Rightmost keyboard zone")
            value: root.draftZ4
            onEditingFinished: v => root.draftZ4 = PerfectSense.normHex(v)
        }

        StepperRow {
            label: qsTr("Brightness")
            subtext: qsTr("Shared backlight intensity for all zones")
            value: root.draftRgbBri
            from: 0
            to: 100
            stepSize: 1
            onMoved: v => root.draftRgbBri = Math.round(v)
        }

        RowButton {
            icon: "check"
            text: qsTr("Apply keyboard colours")
            subtext: qsTr("Write zones and brightness to the EC")
            onClicked: PerfectSense.setRgbZones(root.draftZ1, root.draftZ2, root.draftZ3, root.draftZ4, root.draftRgbBri)
        }

        RowButton {
            last: true
            icon: "light_off"
            text: qsTr("Turn keyboard lights off")
            subtext: qsTr("Sets all zones to black at zero brightness")
            onClicked: PerfectSense.setRgbOff()
        }

        // Back logo
        SectionHeader {
            text: qsTr("Back logo")
        }

        ConnectedRect {
            Layout.fillWidth: true
            first: true
            last: false
            implicitHeight: logoIntro.implicitHeight + Tokens.padding.large * 2

            StyledText {
                id: logoIntro

                anchors.fill: parent
                anchors.margins: Tokens.padding.large
                anchors.leftMargin: Tokens.padding.largeIncreased
                anchors.rightMargin: Tokens.padding.largeIncreased
                text: qsTr("Lid lightbar / rear Predator logo. Colour is RRGGBB; brightness is 0–100. Turning it off writes black at zero intensity.")
                wrapMode: Text.WordWrap
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.body.small
            }
        }

        HexRow {
            label: qsTr("Logo colour")
            subtext: qsTr("Hex colour for the rear logo LED")
            value: root.draftLogoColor
            onEditingFinished: v => root.draftLogoColor = PerfectSense.normHex(v)
        }

        StepperRow {
            label: qsTr("Logo brightness")
            subtext: qsTr("Intensity of the rear logo")
            value: root.draftLogoBri
            from: 0
            to: 100
            stepSize: 1
            onMoved: v => root.draftLogoBri = Math.round(v)
        }

        RowButton {
            icon: "lightbulb"
            text: qsTr("Apply logo")
            subtext: qsTr("Enable the logo with the colour and brightness above")
            onClicked: PerfectSense.setLogo(root.draftLogoColor, root.draftLogoBri, true)
        }

        RowButton {
            last: true
            icon: "lightbulb_outline"
            text: qsTr("Turn logo off")
            onClicked: PerfectSense.setLogo("000000", 0, false)
        }

        // Battery & misc
        SectionHeader {
            text: qsTr("Battery & system")
        }

        ToggleRow {
            first: true
            text: qsTr("Battery charge limit (80%)")
            subtext: qsTr("Stops charging near 80% to reduce wear when mostly plugged in")
            checked: PerfectSense.batteryLimiter === "1"
            onToggled: PerfectSense.setBatteryLimiter(checked)
        }

        SelectRow {
            label: qsTr("USB charging while off")
            subtext: qsTr("How long USB ports stay powered when the laptop is shut down")
            menuItems: root.usbItems
            active: root.usbItems[root.usbIndex] ?? null
            fallbackText: qsTr("USB charging")
            onSelected: item => {
                const idx = root.usbItems.indexOf(item);
                if (idx >= 0)
                    PerfectSense.setAttr("usb_charging", root.usbValues[idx]);
            }
        }

        ToggleRow {
            text: qsTr("LCD overdrive")
            subtext: qsTr("Reduces panel ghosting; may increase overshoot on some content")
            checked: PerfectSense.lcdOverride === "1"
            onToggled: PerfectSense.setAttr("lcd_override", checked ? "1" : "0")
        }

        ToggleRow {
            text: qsTr("Keyboard backlight timeout")
            subtext: qsTr("Dims or turns off keyboard lights after idle")
            checked: PerfectSense.backlightTimeout === "1"
            onToggled: PerfectSense.setAttr("backlight_timeout", checked ? "1" : "0")
        }

        ToggleRow {
            text: qsTr("Boot animation sound")
            subtext: qsTr("Plays the Predator boot chime during firmware startup")
            checked: PerfectSense.bootSound === "1"
            onToggled: PerfectSense.setAttr("boot_animation_sound", checked ? "1" : "0")
        }

        RowButton {
            last: true
            icon: "restart_alt"
            text: qsTr("Reset lighting")
            subtext: qsTr("Ask the EC to restore default lighting state")
            onClicked: PerfectSense.resetLights()
        }
    }

    component FanControl: ColumnLayout {
        id: fanCtl

        required property string label
        required property string subtext
        required property int value
        required property int rpm
        required property bool autoMode
        signal moved(value: int)
        signal toggleAuto

        Layout.fillWidth: true
        spacing: Tokens.spacing.small

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.small

            StyledRect {
                id: autoChip

                implicitWidth: autoRow.implicitWidth + Tokens.padding.medium * 2
                implicitHeight: autoRow.implicitHeight + Tokens.padding.small
                radius: Tokens.rounding.full
                color: fanCtl.autoMode ? Colours.palette.m3primary : Colours.tPalette.m3surfaceContainerHighest

                StateLayer {
                    radius: parent.radius
                    color: fanCtl.autoMode ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
                    onClicked: fanCtl.toggleAuto()
                }

                Row {
                    id: autoRow

                    anchors.centerIn: parent
                    spacing: Tokens.spacing.extraSmall

                    MaterialIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "autorenew"
                        fontStyle: Tokens.font.icon.small
                        color: fanCtl.autoMode ? Colours.palette.m3onPrimary : Colours.palette.m3onSurfaceVariant
                        fill: fanCtl.autoMode ? 1 : 0
                    }

                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: qsTr("Auto")
                        font: Tokens.font.label.medium
                        color: fanCtl.autoMode ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                StyledText {
                    text: fanCtl.label
                    font: Tokens.font.body.small
                }

                StyledText {
                    text: fanCtl.autoMode ? qsTr("%1 · EC curve").arg(fanCtl.subtext) : `${fanCtl.subtext}${fanCtl.rpm > 0 ? ` · ${fanCtl.rpm} rpm` : ""}`
                    color: Colours.palette.m3outline
                    font: Tokens.font.label.small
                }
            }

            StyledSpinBox {
                from: 1
                to: 100
                stepSize: 1
                value: fanCtl.value
                cLayer: 2
                enabled: !fanCtl.autoMode
                opacity: enabled ? 1 : 0.4
                onValueModified: {
                    if (!fanCtl.autoMode)
                        fanCtl.moved(Math.round(value));
                }
            }
        }

        CustomMouseArea {
            function onWheel(event: WheelEvent): void {
                if (fanCtl.autoMode)
                    return;
                const step = 5;
                if (event.angleDelta.y > 0)
                    fanCtl.moved(Math.min(100, fanCtl.value + step));
                else if (event.angleDelta.y < 0)
                    fanCtl.moved(Math.max(1, fanCtl.value - step));
            }

            Layout.fillWidth: true
            implicitHeight: Tokens.padding.medium * 2
            enabled: !fanCtl.autoMode
            opacity: enabled ? 1 : 0.35

            StyledSlider {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                implicitHeight: parent.implicitHeight
                radius: Tokens.rounding.small
                value: fanCtl.value / 100
                enabled: !fanCtl.autoMode
                onInteraction: v => {
                    if (!fanCtl.autoMode)
                        fanCtl.moved(Math.max(1, Math.round(v * 100)));
                }
            }
        }
    }

    component HexRow: ConnectedRect {
        id: hexRoot

        property string label
        property string subtext
        property string value
        signal editingFinished(value: string)

        Layout.fillWidth: true
        implicitHeight: hexLayout.implicitHeight + Tokens.padding.medium * 2

        RowLayout {
            id: hexLayout

            anchors.fill: parent
            anchors.margins: Tokens.padding.medium
            anchors.leftMargin: Tokens.padding.largeIncreased
            anchors.rightMargin: Tokens.padding.largeIncreased
            spacing: Tokens.spacing.medium

            StyledRect {
                implicitWidth: Tokens.padding.extraLarge
                implicitHeight: Tokens.padding.extraLarge
                radius: Tokens.rounding.extraSmall
                color: `#${PerfectSense.normHex(hexRoot.value)}`
                border.width: 1
                border.color: Colours.palette.m3outlineVariant
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                StyledText {
                    Layout.fillWidth: true
                    text: hexRoot.label
                    font: Tokens.font.body.small
                    elide: Text.ElideRight
                }

                StyledText {
                    Layout.fillWidth: true
                    text: hexRoot.subtext
                    color: Colours.palette.m3outline
                    font: Tokens.font.label.small
                    elide: Text.ElideRight
                }
            }

            StyledTextField {
                Layout.preferredWidth: Tokens.sizes.nexus.smallTextFieldWidth
                Layout.maximumWidth: hexRoot.width / 3
                text: hexRoot.value
                placeholderText: "rrggbb"
                maximumLength: 7
                onEditingFinished: hexRoot.editingFinished(text)
            }
        }
    }
}
