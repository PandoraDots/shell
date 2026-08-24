pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services

Item {
    id: root

    implicitWidth: Math.max(layout.implicitWidth, 1100)
    implicitHeight: layout.implicitHeight

    property int draftCpuFan: 40
    property int draftGpuFan: 40
    property bool draftCpuAuto: true
    property bool draftGpuAuto: true
    property bool syncingFans: false

    function pullFans(): void {
        syncingFans = true;
        draftCpuAuto = PerfectSense.cpuFanAuto;
        draftGpuAuto = PerfectSense.gpuFanAuto;
        if (!PerfectSense.cpuFanAuto)
            draftCpuFan = Math.max(1, PerfectSense.cpuFanPercent);
        if (!PerfectSense.gpuFanAuto)
            draftGpuFan = Math.max(1, PerfectSense.gpuFanPercent);
        syncingFans = false;
    }

    function commitFans(): void {
        if (syncingFans)
            return;
        fanDebounce.restart();
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

    Component.onCompleted: pullFans()

    Connections {
        target: PerfectSense
        function onFansChanged(): void {
            if (!fanDebounce.running)
                root.pullFans();
        }
        function onFanCurveManualChanged(): void {
            if (!fanDebounce.running)
                root.pullFans();
        }
    }

    Timer {
        id: fanDebounce
        interval: 280
        onTriggered: root.applyFansNow()
    }

    ColumnLayout {
        id: layout

        anchors.fill: parent
        spacing: Tokens.spacing.medium

        // Header
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: Tokens.padding.large
            Layout.rightMargin: Tokens.padding.large
            spacing: Tokens.spacing.medium

            MaterialIcon {
                text: "sensors"
                fontStyle: Tokens.font.icon.builders.extraLarge.scale(1.4).build()
                color: Colours.palette.m3primary
                fill: 1
            }

            Column {
                Layout.fillWidth: true
                spacing: Tokens.spacing.extraSmall

                StyledText {
                    text: qsTr("PerfectSense")
                    font: Tokens.font.title.large
                    color: Colours.palette.m3onSurface
                }

                StyledText {
                    text: PerfectSense.available ? qsTr("Mode: %1 · CPU %2° · GPU %3°").arg(PerfectSense.label).arg(Math.round(PerfectSense.cpuTemp)).arg(Math.round(PerfectSense.gpuTemp)) : qsTr("nekro_sense unavailable")
                    font: Tokens.font.body.small
                    color: Colours.palette.m3onSurfaceVariant
                }
            }

            StyledText {
                visible: PerfectSense.busy
                text: "…"
                color: Colours.palette.m3primary
            }
        }

        // Telemetry + monitor strip
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: Tokens.padding.large
            Layout.rightMargin: Tokens.padding.large
            spacing: Tokens.spacing.medium

            TeleStat {
                icon: "air"
                label: qsTr("CPU fan")
                value: PerfectSense.cpuRpm > 0 ? `${PerfectSense.cpuRpm} rpm` : "—"
            }

            TeleStat {
                icon: "mode_fan"
                label: qsTr("GPU fan")
                value: PerfectSense.gpuRpm > 0 ? `${PerfectSense.gpuRpm} rpm` : "—"
            }

            TeleStat {
                icon: "thermostat"
                label: qsTr("Temps")
                value: `${Math.round(PerfectSense.cpuTemp)}° / ${Math.round(PerfectSense.gpuTemp)}°`
            }

            TeleStat {
                icon: "laptop_chromebook"
                label: qsTr("Display")
                value: PerfectSense.primaryMonitor ? `${Math.round(Number(PerfectSense.primaryMonitor.refreshRate))} Hz · ${PerfectSense.primaryMonitor.width}×${PerfectSense.primaryMonitor.height}` : "—"
                subValue: PerfectSense.displayPresetLabel(PerfectSense.displayPreset)
                clickable: true
                onClicked: PerfectSense.cycleDisplayPreset()
            }
        }

        // Main controls — two columns
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: Tokens.padding.large
            Layout.rightMargin: Tokens.padding.large
            spacing: Tokens.spacing.medium

            // Fans
            SectionCard {
                Layout.fillWidth: true
                Layout.fillHeight: true
                title: qsTr("Fans")
                subtitle: root.draftCpuAuto && root.draftGpuAuto ? qsTr("Automatic EC curve") : qsTr("Manual duty where Auto is off")

                FanAxis {
                    label: qsTr("CPU")
                    icon: "memory"
                    rpm: PerfectSense.cpuRpm
                    value: root.draftCpuFan
                    autoMode: root.draftCpuAuto
                    onToggleAuto: root.toggleCpuAuto()
                    onMoved: v => {
                        if (root.draftCpuAuto)
                            return;
                        root.draftCpuFan = Math.max(1, v);
                        root.commitFans();
                    }
                }

                FanAxis {
                    label: qsTr("GPU")
                    icon: "developer_board"
                    rpm: PerfectSense.gpuRpm
                    value: root.draftGpuFan
                    autoMode: root.draftGpuAuto
                    onToggleAuto: root.toggleGpuAuto()
                    onMoved: v => {
                        if (root.draftGpuAuto)
                            return;
                        root.draftGpuFan = Math.max(1, v);
                        root.commitFans();
                    }
                }
            }

            // Lighting + battery
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: Tokens.spacing.medium

                SectionCard {
                    Layout.fillWidth: true
                    title: qsTr("Lighting")
                    subtitle: qsTr("Keyboard RGB · back logo")

                    Flow {
                        Layout.fillWidth: true
                        spacing: Tokens.spacing.small

                        ActionChip {
                            text: qsTr("Inferno")
                            icon: "palette"
                            onClicked: PerfectSense.setRgbZones("ff0000", "ff0000", "ff0000", "ff0000", 60)
                        }

                        ActionChip {
                            text: qsTr("Dim")
                            icon: "brightness_low"
                            onClicked: PerfectSense.setRgbZones("ff0000", "ff0000", "ff0000", "ff0000", 20)
                        }

                        ActionChip {
                            text: qsTr("KB off")
                            icon: "light_off"
                            onClicked: PerfectSense.setRgbOff()
                        }

                        ActionChip {
                            text: qsTr("Logo on")
                            icon: "lightbulb"
                            active: PerfectSense.logoOn
                            onClicked: PerfectSense.setLogo("ff0000", 70, true)
                        }

                        ActionChip {
                            text: qsTr("Logo off")
                            icon: "lightbulb_outline"
                            onClicked: PerfectSense.setLogo("000000", 0, false)
                        }
                    }
                }

                SectionCard {
                    Layout.fillWidth: true
                    title: qsTr("Battery & misc")
                    subtitle: PerfectSense.monitorDetail || qsTr("Predator Sense toggles")

                    Flow {
                        Layout.fillWidth: true
                        spacing: Tokens.spacing.small

                        ActionChip {
                            text: qsTr("Limit 80%")
                            icon: "battery_saver"
                            active: PerfectSense.batteryLimiter === "1"
                            onClicked: PerfectSense.setBatteryLimiter(PerfectSense.batteryLimiter !== "1")
                        }

                        ActionChip {
                            text: qsTr("USB 30m")
                            icon: "usb"
                            active: PerfectSense.usbCharging === "30"
                            onClicked: PerfectSense.setAttr("usb_charging", "30")
                        }

                        ActionChip {
                            text: qsTr("USB off")
                            icon: "usb_off"
                            active: PerfectSense.usbCharging === "0"
                            onClicked: PerfectSense.setAttr("usb_charging", "0")
                        }

                        ActionChip {
                            text: qsTr("LCD OD")
                            icon: "tv"
                            active: PerfectSense.lcdOverride === "1"
                            onClicked: PerfectSense.setAttr("lcd_override", PerfectSense.lcdOverride === "1" ? "0" : "1")
                        }

                        ActionChip {
                            text: qsTr("KB timeout")
                            icon: "timer"
                            active: PerfectSense.backlightTimeout === "1"
                            onClicked: PerfectSense.setAttr("backlight_timeout", PerfectSense.backlightTimeout === "1" ? "0" : "1")
                        }

                        ActionChip {
                            text: qsTr("Boot sound")
                            icon: "volume_up"
                            active: PerfectSense.bootSound === "1"
                            onClicked: PerfectSense.setAttr("boot_animation_sound", PerfectSense.bootSound === "1" ? "0" : "1")
                        }
                    }
                }
            }
        }
    }

    component TeleStat: StyledRect {
        id: teleStat

        required property string icon
        required property string label
        required property string value
        property string subValue: ""
        property bool clickable: false
        signal clicked

        Layout.fillWidth: true
        implicitHeight: col.implicitHeight + Tokens.padding.medium * 2
        radius: Tokens.rounding.large
        color: Colours.tPalette.m3surfaceContainer

        StateLayer {
            anchors.fill: parent
            radius: parent.radius
            disabled: !teleStat.clickable
            onClicked: teleStat.clicked()
        }

        Column {
            id: col

            anchors.centerIn: parent
            spacing: Tokens.spacing.extraSmall

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Tokens.spacing.extraSmall

                MaterialIcon {
                    text: teleStat.icon
                    color: Colours.palette.m3primary
                    fontStyle: Tokens.font.icon.small
                }

                StyledText {
                    text: teleStat.label
                    font: Tokens.font.label.small
                    color: Colours.palette.m3onSurfaceVariant
                }
            }

            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: teleStat.value
                font: Tokens.font.title.small
                color: Colours.palette.m3onSurface
            }

            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: teleStat.subValue.length > 0
                text: teleStat.subValue
                font: Tokens.font.label.small
                color: Colours.palette.m3onSurfaceVariant
            }
        }
    }

    component FanAxis: ColumnLayout {
        id: fanAxis

        required property string label
        required property string icon
        required property int rpm
        required property int value
        required property bool autoMode
        signal moved(value: int)
        signal toggleAuto

        Layout.fillWidth: true
        spacing: Tokens.spacing.small

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.small

            ActionChip {
                text: qsTr("Auto")
                icon: "autorenew"
                active: fanAxis.autoMode
                onClicked: fanAxis.toggleAuto()
            }

            MaterialIcon {
                text: fanAxis.icon
                color: Colours.palette.m3primary
                fontStyle: Tokens.font.icon.small
                opacity: fanAxis.autoMode ? 0.45 : 1
            }

            StyledText {
                text: fanAxis.label
                font: Tokens.font.label.medium
                color: Colours.palette.m3onSurface
                opacity: fanAxis.autoMode ? 0.45 : 1
            }

            StyledText {
                Layout.fillWidth: true
                text: fanAxis.autoMode ? qsTr("Auto (curva)") : (fanAxis.rpm > 0 ? `${fanAxis.rpm} rpm` : "")
                font: Tokens.font.label.small
                color: Colours.palette.m3onSurfaceVariant
                elide: Text.ElideRight
            }

            StyledSpinBox {
                from: 1
                to: 100
                stepSize: 1
                value: fanAxis.value
                cLayer: 2
                enabled: !fanAxis.autoMode
                opacity: enabled ? 1 : 0.4
                onValueModified: {
                    if (!fanAxis.autoMode)
                        fanAxis.moved(Math.round(value));
                }
            }

            StyledText {
                text: "%"
                font: Tokens.font.label.small
                color: Colours.palette.m3onSurfaceVariant
                opacity: fanAxis.autoMode ? 0.4 : 1
            }
        }

        CustomMouseArea {
            function onWheel(event: WheelEvent): void {
                if (fanAxis.autoMode)
                    return;
                const step = 5;
                if (event.angleDelta.y > 0)
                    fanAxis.moved(Math.min(100, fanAxis.value + step));
                else if (event.angleDelta.y < 0)
                    fanAxis.moved(Math.max(1, fanAxis.value - step));
            }

            Layout.fillWidth: true
            implicitHeight: Tokens.padding.medium * 2
            enabled: !fanAxis.autoMode
            opacity: enabled ? 1 : 0.35

            StyledSlider {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                implicitHeight: parent.implicitHeight
                radius: Tokens.rounding.small
                value: fanAxis.value / 100
                enabled: !fanAxis.autoMode
                onInteraction: v => {
                    if (!fanAxis.autoMode)
                        fanAxis.moved(Math.max(1, Math.round(v * 100)));
                }
            }
        }
    }

    component SectionCard: StyledRect {
        default property alias content: body.data
        required property string title
        property string subtitle: ""

        implicitHeight: inner.implicitHeight + Tokens.padding.large * 2
        radius: Tokens.rounding.extraLarge
        color: Colours.tPalette.m3surfaceContainer

        ColumnLayout {
            id: inner

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.margins: Tokens.padding.large
            spacing: Tokens.spacing.small

            Column {
                spacing: 2

                StyledText {
                    text: title
                    font: Tokens.font.title.small
                    color: Colours.palette.m3onSurface
                }

                StyledText {
                    visible: subtitle.length > 0
                    text: subtitle
                    font: Tokens.font.body.small
                    color: Colours.palette.m3onSurfaceVariant
                }
            }

            ColumnLayout {
                id: body

                Layout.fillWidth: true
                spacing: Tokens.spacing.small
            }
        }
    }

    component ActionChip: StyledRect {
        id: chip

        property string text
        property string icon: ""
        property bool active: false
        signal clicked

        implicitWidth: row.implicitWidth + Tokens.padding.medium * 2
        implicitHeight: row.implicitHeight + Tokens.padding.small
        radius: Tokens.rounding.full
        color: active ? Colours.palette.m3primary : Colours.tPalette.m3surfaceContainerHighest

        StateLayer {
            radius: parent.radius
            color: active ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
            onClicked: chip.clicked()
        }

        Row {
            id: row

            anchors.centerIn: parent
            spacing: Tokens.spacing.extraSmall

            MaterialIcon {
                visible: chip.icon.length > 0
                anchors.verticalCenter: parent.verticalCenter
                text: chip.icon
                fontStyle: Tokens.font.icon.small
                color: chip.active ? Colours.palette.m3onPrimary : Colours.palette.m3onSurfaceVariant
                fill: chip.active ? 1 : 0
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: chip.text
                font: Tokens.font.label.medium
                color: chip.active ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
            }
        }
    }
}
