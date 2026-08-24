pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services
import qs.modules.nexus.common

PageBase {
    id: root

    title: qsTr("Monitors")

    Component.onCompleted: Displays.refresh()

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        Timer {
            running: root.visible
            interval: 2000
            repeat: true
            onTriggered: Displays.refresh()
        }

        SectionHeader {
            first: true
            text: qsTr("Connected")
        }

        ItemList {
            id: monitorList

            showList: Displays.monitors.length > 0
            placeholderIcon: "monitor"
            placeholderText: Displays.loading ? qsTr("Detecting displays…") : qsTr("No displays detected")

            model: Displays.monitors

            delegate: StyledRect {
                id: row

                required property var modelData
                required property int index

                readonly property bool focused: modelData?.focused ?? false
                readonly property bool disabled: modelData?.disabled ?? false

                anchors.left: monitorList.list.contentItem.left
                anchors.right: monitorList.list.contentItem.right
                implicitHeight: layout.implicitHeight + layout.anchors.margins * 2
                radius: Tokens.rounding.extraSmall
                color: "transparent"

                StateLayer {
                    onClicked: {
                        root.nState.selectedMonitorName = row.modelData.name;
                        root.nState.openSubPage(1);
                    }
                }

                RowLayout {
                    id: layout

                    anchors.fill: parent
                    anchors.margins: Tokens.padding.medium
                    anchors.leftMargin: Tokens.padding.largeIncreased
                    anchors.rightMargin: Tokens.padding.largeIncreased
                    spacing: Tokens.spacing.medium

                    StyledRect {
                        implicitWidth: implicitHeight
                        implicitHeight: monIcon.implicitHeight + Tokens.padding.small * 2
                        radius: Tokens.rounding.full
                        color: row.focused ? Colours.palette.m3primary : Colours.palette.m3secondaryContainer

                        MaterialIcon {
                            id: monIcon

                            anchors.centerIn: parent
                            text: Displays.iconFor(row.modelData?.name ?? "")
                            color: row.focused ? Colours.palette.m3onPrimary : Colours.palette.m3onSecondaryContainer
                            fontStyle: Tokens.font.icon.small
                            fill: 1
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Tokens.spacing.small

                            StyledText {
                                Layout.fillWidth: true
                                text: Displays.prettyTitle(row.modelData)
                                font: Tokens.font.body.small
                                elide: Text.ElideRight
                            }

                            StyledText {
                                visible: row.focused
                                text: qsTr("Active")
                                color: Colours.palette.m3primary
                                font: Tokens.font.label.small
                            }
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: {
                                const kind = Displays.kindLabel(row.modelData?.name ?? "");
                                const name = row.modelData?.name ?? "";
                                const sum = row.disabled ? qsTr("Disabled") : Displays.summary(row.modelData);
                                return `${kind} · ${name} · ${sum}`;
                            }
                            color: Colours.palette.m3outline
                            font: Tokens.font.label.small
                            elide: Text.ElideRight
                        }
                    }

                    MaterialIcon {
                        text: "chevron_right"
                        color: Colours.palette.m3onSurfaceVariant
                        fontStyle: Tokens.font.icon.small
                    }
                }
            }
        }

        RowButton {
            Layout.topMargin: Tokens.spacing.large - parent.spacing
            first: true
            last: true
            icon: "refresh"
            text: qsTr("Refresh displays")
            subtext: qsTr("Rescan connected monitors")
            onClicked: Displays.refresh()
        }

        ConnectedRect {
            Layout.topMargin: Tokens.spacing.large - parent.spacing
            Layout.fillWidth: true
            first: true
            last: true
            implicitHeight: tip.implicitHeight + Tokens.padding.large * 2

            RowLayout {
                id: tip

                anchors.fill: parent
                anchors.margins: Tokens.padding.large
                anchors.leftMargin: Tokens.padding.largeIncreased
                anchors.rightMargin: Tokens.padding.largeIncreased
                spacing: Tokens.spacing.medium

                MaterialIcon {
                    text: "info"
                    color: Colours.palette.m3onSurfaceVariant
                    fontStyle: Tokens.font.icon.small
                }

                StyledText {
                    Layout.fillWidth: true
                    text: qsTr("Changes apply to the current session. Built-in and external displays appear here when connected.")
                    color: Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.body.small
                    wrapMode: Text.WordWrap
                }
            }
        }
    }
}
