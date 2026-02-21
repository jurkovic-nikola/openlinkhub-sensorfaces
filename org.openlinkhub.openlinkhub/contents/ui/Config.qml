import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

ColumnLayout {
    width: parent ? parent.width : 400
    spacing: 10

    property alias cfg_url: urlField.text
    property alias cfg_refreshMs: refreshSpin.value
    property alias cfg_showHubHeader: hubHeaderCheck.checked
    property alias cfg_systrayUrl: systrayUrlField.text
    property alias cfg_showBattery: showBatteryCheck.checked

    Label { text: "JSON URL:" }
    TextField {
        id: urlField
        Layout.fillWidth: true
        placeholderText: "http://127.0.0.1:27003/api/devices/"
    }

    Label { text: "Systray URL (battery):" }
    TextField {
        id: systrayUrlField
        Layout.fillWidth: true
        placeholderText: "http://127.0.0.1:27003/api/systray"
    }

    Label { text: "Refresh interval (ms):" }
    SpinBox {
        id: refreshSpin
        from: 200
        to: 60000
        stepSize: 100
        editable: true
        value: 1000
    }

    CheckBox {
        id: hubHeaderCheck
        text: "Show hub header rows"
        checked: true
    }

    CheckBox {
        id: showBatteryCheck
        text: "Show battery section"
        checked: true
    }

    Label {
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        opacity: 0.7
        text: "Tip: verify the endpoint works with: curl -v " + urlField.text
    }

    Label {
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        opacity: 0.7
        text: "If you have changed your listenPort, make adjustments here."
    }
}
