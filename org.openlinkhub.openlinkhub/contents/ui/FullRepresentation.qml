import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

import org.kde.kirigami as Kirigami
import org.kde.ksysguard.faces 1.0 as Faces
import org.kde.quickcharts as Charts
import org.kde.quickcharts.controls as ChartControls

Faces.SensorFace {
    id: root
    implicitWidth: 520
    implicitHeight: 360

    property var cfg: (controller && controller.faceConfiguration) ? controller.faceConfiguration : ({})
    property string cfgUrl: (cfg.url && ("" + cfg.url).length) ? cfg.url : "http://127.0.0.1:27003/api/devices"
    property int cfgRefreshMs: (cfg.refreshMs !== undefined && cfg.refreshMs !== null) ? cfg.refreshMs : 1000
    property bool cfgShowHubHeader: (cfg.showHubHeader !== undefined && cfg.showHubHeader !== null) ? cfg.showHubHeader : true
    property string systrayUrl: (cfg.systrayUrl && ("" + cfg.systrayUrl).length) ? cfg.systrayUrl : "http://127.0.0.1:27003/api/systray"
    property bool showBattery: (cfg.showBattery !== undefined && cfg.showBattery !== null) ? cfg.showBattery : true
    property string storageUrl: (cfg.storageUrl && ("" + cfg.storageUrl).length) ? cfg.storageUrl : "http://127.0.0.1:27003/api/storageTemp"
    property bool showStorage: (cfg.showStorage !== undefined && cfg.showStorage !== null) ? cfg.showStorage : true

    property string lastError: ""
    property string lastUpdatedText: ""
    property var flatRows: []
    property var batteryRows: []
    property var storageRows: []
    property var combinedRows: []

    function s(v) {
        if (v === null || v === undefined) return ""
            return "" + v
    }

    function formatTemp(child) {
        const t = child.temperature
        if (t === null || t === undefined || t === 0) return ""
            const ts = s(child.temperatureString)
            if (ts.length) return ts
    }

    function typeName(t) {
        if (t === 2) return "Headset"
            if (t === 1) return "Mouse"
                if (t === 0) return "Keyboard"
                    return "Device"
    }

    function typeIcon(t) {
        if (t === 2) return "audio-headphones"
            if (t === 1) return "input-mouse"
                if (t === 0) return "input-keyboard"
                    return "battery"
    }

    function buildBatteryRows(obj) {
        const out = []
        const data = obj && obj.data ? obj.data : null
        const batt = data && data.battery ? data.battery : null
        if (!batt) return out

            for (const id in batt) {
                const b = batt[id]
                if (!b) continue
                    out.push({
                        id: id,
                        name: s(b.Device) || id,
                             level: Number(b.Level),
                             type: Number(b.DeviceType)
                    })
            }

            out.sort((a,b) => (a.type - b.type) || (b.level - a.level) || a.name.localeCompare(b.name))
            return out
    }

    function buildFlatRowsFromJson(obj) {
        const out = []
        if (!obj || !obj.devices) return out

            for (const hubSerial in obj.devices) {
                const hub = obj.devices[hubSerial]
                if (!hub) continue

                    const gd = hub.GetDevice
                    const childMap = gd && gd.devices ? gd.devices : null
                    if (!childMap) continue

                        const hubName = s(hub.Product) || s(gd.product) || hubSerial

                        if (cfgShowHubHeader) {
                            out.push({
                                type: "hub",
                                hubSerial: hubSerial,
                                hubName: hubName,
                                firmware: s(gd.firmware)
                            })
                        }

                        const children = []
                        for (const key in childMap) {
                            const ch = childMap[key]
                            if (!ch) continue
                                if (typeof ch.deviceId === "string" && ch.deviceId === "Psu-0") {
                                    continue
                                }

                                children.push({
                                    type: "device",
                                    hubSerial: hubSerial,
                                    channelId: (ch.channelId !== undefined && ch.channelId !== null) ? s(ch.channelId) : s(key),
                                              name: s(ch.name),
                                              rpm: (ch.rpm === undefined || ch.rpm === null) ? "" : s(ch.rpm),
                                              temp: formatTemp(ch),
                                              volts: (ch.volts === undefined || ch.volts === null) ? "" : s(ch.volts),
                                              amps: (ch.amps === undefined || ch.amps === null) ? "" : s(ch.amps),
                                              watts: (ch.watts === undefined || ch.watts === null) ? "" : s(ch.watts)
                                })
                        }

                        children.sort(function(a, b) {
                            const an = Number(a.channelId), bn = Number(b.channelId)
                            if (!isNaN(an) && !isNaN(bn)) return an - bn
                                return ("" + a.channelId).localeCompare("" + b.channelId)
                        })

                        for (let i = 0; i < children.length; i++) out.push(children[i])
            }

            return out
    }

    function fetchJson() {
        const url = cfgUrl
        if (!url || !url.trim().length) {
            lastError = "No URL configured"
            flatRows = []
            return
        }

        const xhr = new XMLHttpRequest()
        xhr.open("GET", url, true)

        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return
                if (xhr.status < 200 || xhr.status >= 300) {
                    lastError = "HTTP " + xhr.status + ": " + xhr.statusText
                    flatRows = []
                    return
                }

                try {
                    const parsed = JSON.parse(xhr.responseText)
                    flatRows = buildFlatRowsFromJson(parsed)
                    lastError = ""
                    lastUpdatedText = new Date().toLocaleTimeString()
                } catch (e) {
                    lastError = "JSON parse error: " + e
                    flatRows = []
                }
        }

        xhr.onerror = function() {
            lastError = "Network error fetching: " + url
            flatRows = []
        }

        xhr.send()
    }

    function fetchSystray() {
        if (!showBattery) { batteryRows = []; return }
        if (!systrayUrl.trim().length) { batteryRows = []; return }

        const xhr = new XMLHttpRequest()
        xhr.open("GET", systrayUrl, true)

        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return
                if (xhr.status < 200 || xhr.status >= 300) {
                    batteryRows = []
                    return
                }
                try {
                    const parsed = JSON.parse(xhr.responseText)
                    batteryRows = buildBatteryRows(parsed)
                } catch (e) {
                    batteryRows = []
                }
        }
        xhr.onerror = function() { batteryRows = [] }
        xhr.send()
    }

    function fetchStorage() {
        if (!showStorage) { storageRows = []; rebuildCombinedRows(); return }
        const url = storageUrl
        if (!url || !url.trim().length) { storageRows = []; rebuildCombinedRows(); return }

        const xhr = new XMLHttpRequest()
        xhr.open("GET", url, true)

        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return
                if (xhr.status < 200 || xhr.status >= 300) {
                    storageRows = []
                    rebuildCombinedRows()
                    return
                }
                try {
                    const parsed = JSON.parse(xhr.responseText)
                    storageRows = buildStorageRows(parsed)
                } catch (e) {
                    storageRows = []
                }
                rebuildCombinedRows()
        }

        xhr.onerror = function() {
            storageRows = []
            rebuildCombinedRows()
        }

        xhr.send()
    }

    function buildStorageRows(obj) {
        const out = []
        const data = (obj && obj.data) ? obj.data : []
        for (let i = 0; i < data.length; i++) {
            const d = data[i]
            if (!d) continue
                out.push({
                    type: "device",
                    name: d.Model || d.Key,
                    rpm: 0,
                    temp: d.TemperatureString || ""
                })
        }
        return out
    }

    function rebuildCombinedRows() {
        const out = []
        for (let i = 0; i < flatRows.length; i++) out.push(flatRows[i])

            if (showStorage && storageRows.length > 0) {
                out.push({ type: "section", title: "Storage" })
                for (let i = 0; i < storageRows.length; i++) out.push(storageRows[i])
            }

            combinedRows = out
    }

    Timer {
        id: pollTimer
        interval: cfgRefreshMs
        running: true
        repeat: true
        onTriggered: {
            root.fetchJson()
            root.fetchSystray()
            root.fetchStorage()
        }
    }

    Connections {
        target: (controller && controller.faceConfiguration) ? controller.faceConfiguration : null
        function onUrlChanged() { root.fetchJson() }
        function onSystrayUrlChanged() { root.fetchSystray() }
        function onShowBatteryChanged() { root.fetchSystray() }
        function onRefreshMsChanged() { pollTimer.interval = root.cfgRefreshMs }
        function onShowHubHeaderChanged() { root.fetchJson() }
        function onStorageUrlChanged() { root.fetchStorage() }
        function onShowStorageChanged() { root.fetchStorage() }
    }

    Component.onCompleted: {
        fetchJson()
        fetchSystray()
        fetchStorage()
        rebuildCombinedRows()
    }

    contentItem: ColumnLayout {
        anchors.fill: parent
        spacing: 8

        RowLayout {
            Layout.fillWidth: true

            Label {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                text: root.lastError.length ? ("ERROR: " + root.lastError) : ("Updated: " + (root.lastUpdatedText.length ? root.lastUpdatedText : "—"))
            }

            Button {
                text: "Refresh"
                onClicked: root.fetchJson()
            }
        }

        Frame {
            Layout.fillWidth: true
            padding: 8

            RowLayout {
                width: parent.width
                spacing: 12

                Label { text: "Device"; font.bold: true; Layout.fillWidth: true }
                Label { text: "Volts"; font.bold: true; Layout.preferredWidth: 110; horizontalAlignment: Text.AlignRight }
                Label { text: "Amps"; font.bold: true; Layout.preferredWidth: 110; horizontalAlignment: Text.AlignRight }
                Label { text: "Watts"; font.bold: true; Layout.preferredWidth: 110; horizontalAlignment: Text.AlignRight }
                Label { text: "RPM"; font.bold: true; Layout.preferredWidth: 110; horizontalAlignment: Text.AlignRight }
                Label { text: "Temp"; font.bold: true; Layout.preferredWidth: 140; horizontalAlignment: Text.AlignRight }
            }
        }

        ListView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            model: root.combinedRows

            delegate: Item {
                width: ListView.view.width
                height: rowLayout.implicitHeight + 8

                ColumnLayout {
                    id: rowLayout
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.margins: 6
                    spacing: 4

                    RowLayout {
                        visible: modelData.type === "section"
                        Layout.fillWidth: true
                        Label {
                            text: modelData.title || ""
                            font.bold: true
                            opacity: 0.9
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }
                    }

                    Item {
                        visible: modelData.type === "spacer"
                        Layout.fillWidth: true
                        height: Kirigami.Units.smallSpacing * 2
                    }

                    RowLayout {
                        visible: modelData.type === "hub"
                        Layout.fillWidth: true
                        Label {
                            text: modelData.hubName
                            font.bold: true
                            Layout.fillWidth: true
                            elide: Text.ElideMiddle
                        }
                        Label {
                            text: modelData.firmware.length ? ("FW " + modelData.firmware) : ""
                            opacity: 0.8
                        }
                    }

                    RowLayout {
                        visible: modelData.type === "device"
                        Layout.fillWidth: true
                        spacing: 12
                        Label {
                            text: modelData.name
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }
                        Label {
                            text: (Number(modelData.volts) > 0) ? (modelData.volts + " V") : ""
                            Layout.preferredWidth: 110
                            horizontalAlignment: Text.AlignRight
                        }
                        Label {
                            text: (Number(modelData.amps) > 0) ? (modelData.amps + " A") : ""
                            Layout.preferredWidth: 110
                            horizontalAlignment: Text.AlignRight
                        }
                        Label {
                            text: (Number(modelData.watts) > 0) ? (modelData.watts + " W") : ""
                            Layout.preferredWidth: 110
                            horizontalAlignment: Text.AlignRight
                        }
                        Label {
                            text: (Number(modelData.rpm) > 0) ? (modelData.rpm + " RPM") : ""
                            Layout.preferredWidth: 110
                            horizontalAlignment: Text.AlignRight
                        }
                        Label {
                            text: modelData.temp
                            Layout.preferredWidth: 140
                            horizontalAlignment: Text.AlignRight
                        }
                    }

                    Rectangle {
                        visible: modelData.type !== "spacer"
                        Layout.fillWidth: true
                        height: 1
                        opacity: 0.15
                    }
                }
            }
        }

        Frame {
            visible: showBattery
            Layout.fillWidth: true
            padding: 8

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 8
                //Label { text: "Battery"; font.bold: true }

                Flow {
                    Layout.fillWidth: false
                    spacing: 12
                    Layout.alignment: Qt.AlignLeft

                    Repeater {
                        model: batteryRows

                        delegate: Frame {
                            padding: 10
                            width: 200

                            ColumnLayout {
                                spacing: 6
                                RowLayout {
                                    Layout.fillWidth: true

                                    Kirigami.Icon {
                                        source: typeIcon(modelData.type)
                                        implicitWidth: 18
                                        implicitHeight: 18
                                    }

                                    Label {
                                        text: modelData.name
                                        font.bold: true
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }
                                }

                                RowLayout {
                                    spacing: 10

                                    Item {
                                        width: 80
                                        height: 80

                                        ChartControls.PieChartControl {
                                            id: ring
                                            anchors.fill: parent

                                            chart.thickness: Kirigami.Units.smallSpacing * 1.5
                                            chart.fromAngle: -90
                                            chart.toAngle: 270
                                            chart.filled: false
                                            chart.smoothEnds: false

                                            readonly property color trackColor: Kirigami.ColorUtils.linearInterpolation(
                                                Kirigami.Theme.backgroundColor,
                                                Kirigami.Theme.textColor,
                                                0.20
                                            )

                                            valueSources: [
                                                Charts.ArraySource {
                                                    array: [
                                                        Math.max(0, Math.min(100, modelData.level)),
                                                        100 - Math.max(0, Math.min(100, modelData.level))
                                                    ]
                                                }
                                            ]

                                            chart.nameSource: Charts.ArraySource { array: ["Level", "Remaining"] }
                                            chart.shortNameSource: Charts.ArraySource { array: ["", ""] }
                                            chart.colorSource: Charts.ArraySource {
                                                array: [ Kirigami.Theme.highlightColor, ring.trackColor ]
                                            }
                                        }

                                        Label {
                                            anchors.centerIn: parent
                                            text: modelData.level + "%"
                                            font.bold: true
                                        }
                                    }

                                    ColumnLayout {
                                        Label { text: typeName(modelData.type); opacity: 0.8 }
                                        Label {
                                            text: (modelData.level >= 0 ? (modelData.level + "%") : "—")
                                            font.bold: true
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Label {
                    visible: batteryRows.length === 0
                    opacity: 0.6
                    text: "No battery devices reported."
                }
            }
        }
    }
}
