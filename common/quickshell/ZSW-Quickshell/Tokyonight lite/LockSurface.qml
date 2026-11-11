// LockSurface.qml — one screen of the session lock.
//
// WlSessionLock creates this once per output. PAM runs here, so unlocking is
// the same `login` chain hyprlock used: a failed try is a real PAM failure, and
// faillock counts it. The lock object is the one in Lock.qml; setting its
// `locked` false is the only way out.
//
// This surface is deliberately not part of the bar's process state: it is
// created while locked and destroyed when the lock ends, so nothing here can
// leak a clock timer or a PAM context into the running session.
import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Services.Pam
import Quickshell.Services.UPower
import Quickshell.Wayland

WlSessionLockSurface {
    id: root

    /// The WlSessionLock in Lock.qml.
    property var lock: null
    /// The shell's NotificationStore, for the unread line.
    property var store: null

    property string error: ""
    /// Failed tries since this surface appeared, for the faillock hint below.
    property int failures: 0

    readonly property var now: clock.now
    readonly property var player: {
        const players = Mpris.players.values
        return players.find(p => p.isPlaying) ?? null
    }
    readonly property var battery: UPower.displayDevice
    readonly property bool showBattery: Settings.batteryPill
                                        && root.battery !== null
                                        && root.battery.isPresent
                                        && root.battery.isLaptopBattery
    readonly property int unread: root.store ? root.store.unread : 0

    Timer {
        id: clock
        property var now: new Date()
        interval: 1000
        repeat: true
        running: true
        onTriggered: clock.now = new Date()
    }

    PamContext {
        id: pam
        config: "login"
        user: Quickshell.env("USER")
        onCompleted: result => {
            if (result === PamResult.Success) {
                root.error = ""
                root.failures = 0
                if (root.lock !== null) root.lock.locked = false
                return
            }
            root.failures = root.failures + 1
            // pam_faillock (deny=3, unlock_time=600) is what actually refuses
            // the login; "Incorrect password" would make a correct password
            // look broken for the next ten minutes.
            root.error = result === PamResult.MaxTries || root.failures >= 3
                         ? "Too many tries — wait 10 min or run: faillock --user "
                           + Quickshell.env("USER") + " --reset"
                         : "Incorrect password"
            field.text = ""
            // A failed try is a completed session; a new one starts after the
            // configured grace, or immediately when grace is 0.
            if (Settings.lockGraceSeconds > 0) retry.restart()
            else pam.start()
        }
        onError: e => {
            root.error = "PAM: " + PamError.toString(e)
        }
        onResponseRequiredChanged: {
            if (pam.responseRequired) field.forceActiveFocus()
        }
    }

    Timer {
        id: retry
        interval: Settings.lockGraceSeconds * 1000
        onTriggered: pam.start()
    }

    Component.onCompleted: pam.start()

    Image {
        anchors.fill: parent
        source: ThemeColors.wallpaper
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
    }

    // The scrim is what makes white text readable over any wallpaper. Solid
    // enough to hide the desktop, not so solid that the theme disappears.
    Rectangle {
        anchors.fill: parent
        color: Tokyo.bgDark
        opacity: 0.82
    }

    Column {
        anchors.centerIn: parent
        z: 1
        spacing: 18

        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: Qt.formatDateTime(root.now, "HH:mm")
            color: Tokyo.fg
            font { family: Tokyo.fontFamily; pixelSize: 72; bold: true
                   letterSpacing: 2 }
        }

        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: Qt.formatDateTime(root.now, "dddd, d MMMM")
            color: Tokyo.dim
            font { family: Tokyo.fontFamily; pixelSize: 14; letterSpacing: 1 }
        }

        Item { width: 1; height: 8 }

        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            visible: root.player !== null
            text: root.player !== null
                  ? "▶ " + root.player.trackTitle + " — " + root.player.trackArtist
                  : ""
            color: Tokyo.magenta
            elide: Text.ElideRight
            font { family: Tokyo.fontFamily; pixelSize: 12 }
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 22
            visible: root.showBattery || root.unread > 0

            Text {
                visible: root.showBattery
                text: Math.round(root.battery.percentage) + "%"
                      + (root.battery.state === UPowerDeviceState.Charging ? " 󰂄" : "")
                color: Tokyo.green
                font { family: Tokyo.fontFamily; pixelSize: 12 }
            }
            Text {
                visible: root.unread > 0
                text: root.unread + " unread"
                color: Tokyo.blue
                font { family: Tokyo.fontFamily; pixelSize: 12 }
            }
        }

        Item { width: 1; height: 8 }

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 300
            height: 42
            radius: Tokyo.pillRadius
            color: Tokyo.boxFill
            border.width: 1
            border.color: pam.messageIsError || root.error !== ""
                          ? Tokyo.red : Tokyo.paneEdge

            TextInput {
                id: field
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                focus: true
                color: Tokyo.fg
                selectionColor: Tokyo.blue
                selectedTextColor: Tokyo.islandFill
                echoMode: TextInput.Password
                passwordCharacter: "•"
                font { family: Tokyo.fontFamily; pixelSize: 14 }
                verticalAlignment: TextInput.AlignVCenter
                cursorDelegate: Rectangle { width: 1; color: Tokyo.blue }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: field.text.length === 0
                    text: "Password"
                    color: Tokyo.dim
                    font: field.font
                }

                onAccepted: root.submit()
                Keys.onEscapePressed: field.text = ""
            }
        }

        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: root.error !== "" ? root.error : "Press Enter to unlock"
            color: root.error !== "" ? Tokyo.red : Tokyo.dim
            elide: Text.ElideRight
            font { family: Tokyo.fontFamily; pixelSize: 10 }
        }
    }

    function submit() {
        if (!pam.responseRequired || field.text === "") return
        const text = field.text
        field.text = ""
        pam.respond(text)
    }

    // A pointer press anywhere brings the field back, so a click on the empty
    // desktop cannot leave the lock without a focus target.
    MouseArea {
        anchors.fill: parent
        z: 0
        onClicked: field.forceActiveFocus()
    }
}
