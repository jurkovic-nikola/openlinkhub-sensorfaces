import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import org.kde.ksysguard.faces 1.0 as Faces

Faces.SensorFace {
    implicitWidth: 220
    implicitHeight: 60

    contentItem: RowLayout {
        anchors.fill: parent
        spacing: 8
        Label { text: "OpenLinkHub"; font.bold: true }
        Label { text: "Open for details"; opacity: 0.7; Layout.fillWidth: true; elide: Text.ElideRight }
    }
}
