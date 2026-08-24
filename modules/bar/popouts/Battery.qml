pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Services.UPower
import Caelestia.Config
import qs.components
import qs.services

Column {
    id: root

    spacing: Tokens.spacing.medium
    width: Math.max(Tokens.sizes.bar.batteryWidth, profiles.implicitWidth + Tokens.padding.small)

    StyledText {
        text: UPower.displayDevice.isLaptopBattery ? qsTr("Remaining: %1%").arg(Math.round(UPower.displayDevice.percentage * 100)) : qsTr("No battery detected")
    }

    StyledText {
        function formatSeconds(s: int, fallback: string): string {
            const day = Math.floor(s / 86400);
            const hr = Math.floor(s / 3600) % 24;
            const min = Math.floor(s / 60) % 60;

            let comps = [];
            if (day > 0)
                comps.push(`${day} days`);
            if (hr > 0)
                comps.push(`${hr} hours`);
            if (min > 0)
                comps.push(`${min} mins`);

            return comps.join(", ") || fallback;
        }

        text: {
            if (UPower.displayDevice.isLaptopBattery)
                return qsTr("Time %1: %2").arg(UPower.onBattery ? "remaining" : "until charged").arg(UPower.onBattery ? formatSeconds(UPower.displayDevice.timeToEmpty, "Calculating...") : formatSeconds(UPower.displayDevice.timeToFull, "Fully charged!"));
            return qsTr("Power: %1").arg(PerfectSense.label);
        }
    }

    Loader {
        asynchronous: true
        anchors.horizontalCenter: parent.horizontalCenter

        active: PowerProfiles.degradationReason !== PerformanceDegradationReason.None

        height: active ? ((item as Item)?.implicitHeight ?? 0) : 0

        sourceComponent: StyledRect {
            implicitWidth: child.implicitWidth + Tokens.padding.medium * 2
            implicitHeight: child.implicitHeight + Tokens.padding.large

            color: Colours.palette.m3error
            radius: Tokens.rounding.large

            Column {
                id: child

                anchors.centerIn: parent

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: Tokens.spacing.small

                    MaterialIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "warning"
                        color: Colours.palette.m3onError
                    }

                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: qsTr("Performance Degraded")
                        color: Colours.palette.m3onError
                        font: Tokens.font.mono.builders.medium.weight(Font.Medium).build()
                    }
                }

                StyledText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: qsTr("Reason: %1").arg(PerformanceDegradationReason.toString(PowerProfiles.degradationReason))
                    color: Colours.palette.m3onError
                }
            }
        }
    }

    // 5 EC modes (PerfectSense / nekro platform_profile)
    StyledRect {
        id: profiles

        property string current: PerfectSense.ec

        anchors.horizontalCenter: parent.horizontalCenter

        implicitWidth: row.implicitWidth + Tokens.padding.medium * 2
        implicitHeight: row.implicitHeight + Tokens.padding.small

        color: Colours.tPalette.m3surfaceContainer
        radius: Tokens.rounding.full

        Row {
            id: row

            anchors.centerIn: parent
            spacing: Tokens.spacing.extraSmall

            EcProfile {
                id: eco
                modeId: "low-power"
                icon: "energy_savings_leaf"
            }

            EcProfile {
                id: quiet
                modeId: "quiet"
                icon: "bedtime"
            }

            EcProfile {
                id: balance
                modeId: "balanced"
                icon: "balance"
            }

            EcProfile {
                id: perf
                modeId: "balanced-performance"
                icon: "bolt"
            }

            EcProfile {
                id: turbo
                modeId: "performance"
                icon: "rocket_launch"
            }
        }
    }

    StyledText {
        anchors.horizontalCenter: parent.horizontalCenter
        text: {
            const m = PerfectSense.modes.find(x => x.id === PerfectSense.ec);
            return m ? m.hint : "";
        }
        font: Tokens.font.body.small
        color: Colours.palette.m3onSurfaceVariant
    }

    component EcProfile: Item {
        id: profile

        required property string icon
        required property string modeId

        readonly property bool selected: profiles.current === modeId

        implicitWidth: iconItem.implicitHeight + Tokens.padding.small * 2
        implicitHeight: iconItem.implicitHeight + Tokens.padding.small * 2

        StyledRect {
            anchors.fill: parent
            radius: Tokens.rounding.full
            color: profile.selected ? Colours.palette.m3primary : "transparent"

            Behavior on color {
                CAnim {}
            }
        }

        StateLayer {
            radius: Tokens.rounding.full
            color: profile.selected ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
            onClicked: PerfectSense.setMode(profile.modeId)
        }

        MaterialIcon {
            id: iconItem

            anchors.centerIn: parent

            text: profile.icon
            fontStyle: Tokens.font.icon.large
            color: profile.selected ? Colours.palette.m3onPrimary : Colours.palette.m3onSurfaceVariant
            fill: profile.selected ? 1 : 0

            Behavior on color {
                CAnim {}
            }

            Behavior on fill {
                Anim {
                    type: Anim.DefaultEffects
                }
            }
        }
    }
}
