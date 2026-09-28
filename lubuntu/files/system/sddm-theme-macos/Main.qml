// macOS-style SDDM theme: blurred wallpaper, date + large clock at the top,
// round avatar with a pill password field near the bottom, power buttons below.
// Uses only QtQuick, Qt5Compat.GraphicalEffects and SddmComponents (no Plasma).

import QtQuick 2.15
import Qt5Compat.GraphicalEffects
import SddmComponents 2.0

Rectangle {
    id: root
    width: 1920
    height: 1080
    color: "black"

    readonly property string uiFont: config.fontFamily || "Inter"
    readonly property bool previewPower: config.previewPower === "true"
    property int sessionIndex: sessionModel.lastIndex >= 0 ? sessionModel.lastIndex : 0

    TextConstants { id: textConstants }

    Connections {
        target: sddm
        function onLoginFailed() {
            password.text = ""
            message.text = "Incorrect password"
            shake.restart()
            password.forceActiveFocus()
        }
    }

    // ---- blurred wallpaper on every screen ----
    Repeater {
        model: screenModel
        Item {
            x: geometry.x; y: geometry.y; width: geometry.width; height: geometry.height
            Image {
                id: wall
                anchors.fill: parent
                source: config.background
                fillMode: Image.PreserveAspectCrop
                asynchronous: false
                visible: false
            }
            FastBlur {
                anchors.fill: parent
                source: wall
                radius: 72
            }
            Rectangle { anchors.fill: parent; color: "#33000000" }
        }
    }

    // ---- content on the primary screen ----
    Item {
        property var geo: screenModel.geometry(screenModel.primary)
        x: geo.x; y: geo.y; width: geo.width; height: geo.height

        // date + time, like the macOS lock screen
        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: parent.height * 0.08
            spacing: 0
            Text {
                id: dateText
                anchors.horizontalCenter: parent.horizontalCenter
                color: "#e6ffffff"
                font.family: root.uiFont
                font.pixelSize: 26
                font.weight: Font.DemiBold
            }
            Text {
                id: timeText
                anchors.horizontalCenter: parent.horizontalCenter
                color: "#e6ffffff"
                font.family: root.uiFont
                font.pixelSize: 112
                font.weight: Font.Bold
            }
            Timer {
                interval: 1000; running: true; repeat: true; triggeredOnStart: true
                onTriggered: {
                    var now = new Date()
                    dateText.text = Qt.formatDateTime(now, "dddd d MMMM")
                    timeText.text = Qt.formatDateTime(now, "h:mm AP").replace(/\s*[AP]M$/i, "")
                }
            }
        }

        // hidden list that tracks the selected user
        ListView {
            id: users
            model: userModel
            currentIndex: userModel.lastIndex >= 0 ? userModel.lastIndex : 0
            visible: false
            width: 1; height: 1
            delegate: Item {
                property string login: model.name
                property string display: model.realName !== "" ? model.realName : model.name
                property string avatar: model.icon
            }
        }

        // avatar, name, password
        Column {
            id: loginBox
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: parent.height * 0.14
            spacing: 14

            Item {
                width: 96; height: 96
                anchors.horizontalCenter: parent.horizontalCenter
                // SDDM's built-in face is a dark silhouette: show it white on grey like macOS
                readonly property bool defaultFace: avatarImg.source.toString().indexOf("/usr/share/sddm/faces") >= 0

                Rectangle {
                    id: avatarMask
                    anchors.fill: parent
                    radius: width / 2
                    visible: false
                }
                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: "#9a9a9a"
                    Text {
                        anchors.centerIn: parent
                        visible: avatarImg.status !== Image.Ready
                        text: users.currentItem ? users.currentItem.display.charAt(0).toUpperCase() : ""
                        color: "white"
                        font.family: root.uiFont
                        font.pixelSize: 44
                        font.weight: Font.DemiBold
                    }
                }
                Image {
                    id: avatarImg
                    anchors.fill: parent
                    source: users.currentItem ? users.currentItem.avatar : ""
                    fillMode: Image.PreserveAspectCrop
                    visible: false
                }
                ColorOverlay {
                    id: tinted
                    anchors.fill: parent
                    source: avatarImg
                    color: parent.defaultFace ? "#f2ffffff" : "#00000000"
                    visible: false
                }
                OpacityMask {
                    anchors.fill: parent
                    source: tinted
                    maskSource: avatarMask
                    visible: avatarImg.status === Image.Ready
                }
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 12
                Text {
                    text: "‹"
                    visible: userModel.count > 1
                    color: "white"; font.pixelSize: 24
                    MouseArea { anchors.fill: parent; onClicked: users.decrementCurrentIndex() }
                }
                Text {
                    text: users.currentItem ? users.currentItem.display : ""
                    color: "white"
                    font.family: root.uiFont
                    font.pixelSize: 17
                    font.weight: Font.DemiBold
                }
                Text {
                    text: "›"
                    visible: userModel.count > 1
                    color: "white"; font.pixelSize: 24
                    MouseArea { anchors.fill: parent; onClicked: users.incrementCurrentIndex() }
                }
            }

            // pill-shaped password field
            Rectangle {
                id: pill
                width: 220; height: 34
                radius: height / 2
                color: "#40ffffff"
                border.color: password.activeFocus ? "#80ffffff" : "#30ffffff"
                border.width: 1
                anchors.horizontalCenter: parent.horizontalCenter

                SequentialAnimation {
                    id: shake
                    property real base: 0
                    NumberAnimation { target: pill; property: "anchors.horizontalCenterOffset"; to: -12; duration: 50 }
                    NumberAnimation { target: pill; property: "anchors.horizontalCenterOffset"; to: 12; duration: 70 }
                    NumberAnimation { target: pill; property: "anchors.horizontalCenterOffset"; to: -8; duration: 70 }
                    NumberAnimation { target: pill; property: "anchors.horizontalCenterOffset"; to: 8; duration: 70 }
                    NumberAnimation { target: pill; property: "anchors.horizontalCenterOffset"; to: 0; duration: 50 }
                }

                TextInput {
                    id: password
                    anchors.left: parent.left
                    anchors.right: enterBtn.left
                    anchors.leftMargin: 14
                    anchors.rightMargin: 6
                    anchors.verticalCenter: parent.verticalCenter
                    echoMode: TextInput.Password
                    passwordCharacter: "●"
                    color: "white"
                    font.family: root.uiFont
                    font.pixelSize: 14
                    clip: true
                    focus: true
                    Component.onCompleted: forceActiveFocus()
                    onTextChanged: message.text = ""
                    Keys.onReturnPressed: root.doLogin()
                    Keys.onEnterPressed: root.doLogin()

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Enter Password"
                        color: "#b3ffffff"
                        font: password.font
                        visible: password.text.length === 0
                    }
                }

                // round arrow button, shown once something is typed
                Rectangle {
                    id: enterBtn
                    width: 24; height: 24; radius: 12
                    anchors.right: parent.right
                    anchors.rightMargin: 5
                    anchors.verticalCenter: parent.verticalCenter
                    color: "#59ffffff"
                    opacity: password.text.length > 0 ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 150 } }
                    Text {
                        anchors.centerIn: parent
                        text: "→"
                        color: "white"
                        font.pixelSize: 15
                        font.weight: Font.Bold
                    }
                    MouseArea { anchors.fill: parent; onClicked: root.doLogin() }
                }
            }

            Text {
                id: message
                anchors.horizontalCenter: parent.horizontalCenter
                text: ""
                color: "#e6ffffff"
                font.family: root.uiFont
                font.pixelSize: 13
                height: 16
            }
        }

        // power buttons along the bottom, like the macOS login window
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 36
            spacing: 44

            Repeater {
                model: [
                    { label: "Sleep",     icon: "suspend.png",  show: sddm.canSuspend,  act: function() { sddm.suspend() } },
                    { label: "Restart",   icon: "reboot.png",   show: sddm.canReboot,   act: function() { sddm.reboot() } },
                    { label: "Shut Down", icon: "shutdown.png", show: sddm.canPowerOff, act: function() { sddm.powerOff() } }
                ]
                delegate: Column {
                    visible: modelData.show || root.previewPower
                    spacing: 6
                    Rectangle {
                        width: 40; height: 40; radius: 20
                        anchors.horizontalCenter: parent.horizontalCenter
                        color: pma.containsMouse ? "#59ffffff" : "#33ffffff"
                        Image {
                            id: pwrIcon
                            anchors.centerIn: parent
                            width: 20; height: 20
                            source: Qt.resolvedUrl(modelData.icon)
                            visible: false
                        }
                        ColorOverlay { anchors.fill: pwrIcon; source: pwrIcon; color: "white" }
                        MouseArea { id: pma; anchors.fill: parent; hoverEnabled: true; onClicked: modelData.act() }
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: modelData.label
                        color: "#e6ffffff"
                        font.family: root.uiFont
                        font.pixelSize: 12
                    }
                }
            }
        }

        // small session picker, bottom-left (click to cycle)
        Text {
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            anchors.margins: 24
            color: "#b3ffffff"
            font.family: root.uiFont
            font.pixelSize: 12
            text: sessions.currentItem ? "Session: " + sessions.currentItem.sname + (sessionModel.rowCount() > 1 ? "  ›" : "") : ""
            MouseArea {
                anchors.fill: parent
                onClicked: {
                    sessions.currentIndex = (sessions.currentIndex + 1) % sessions.count
                    root.sessionIndex = sessions.currentIndex
                }
            }
        }
        ListView {
            id: sessions
            model: sessionModel
            currentIndex: root.sessionIndex
            visible: false
            width: 1; height: 1
            delegate: Item { property string sname: model.name }
        }
    }

    function doLogin() {
        if (!users.currentItem) return
        message.text = ""
        sddm.login(users.currentItem.login, password.text, root.sessionIndex)
    }
}
