import QtQuick
import QtTest
import Flux

// The status pill at the bottom of the window: connection, DHT nodes and all-time totals.
TestCase {
    id: tc
    name: "StatusPill"
    when: windowShown
    width: 1200
    height: 80
    visible: true

    Component {
        id: pillComponent
        StatusPill {
            width: 1176
        }
    }

    function cleanup() {
        FluxTestI18n.setLanguage("")
    }

    function text(pill, name) {
        const t = findChild(pill, name)
        verify(t, name + " exists")
        return t.text
    }

    function test_bindsToSession() {
        const pill = createTemporaryObject(pillComponent, tc)
        compare(pill.connected, SessionFacade.connected)
        compare(pill.port, SessionFacade.listenPort)
        compare(pill.dhtNodes, SessionFacade.dhtNodes)
        compare(pill.totalDownloaded, SessionFacade.totalDownloaded)
        compare(pill.totalUploaded, SessionFacade.totalUploaded)
        compare(pill.height, 34)
    }

    function test_connected() {
        const pill = createTemporaryObject(pillComponent, tc, { connected: true, port: 51413 })
        compare(text(pill, "statusConnection"), "Connected · port 51413")
        verify(Qt.colorEqual(findChild(pill, "statusDot").color, Theme.accent), "the dot is green online")
    }

    function test_disconnected() {
        const pill = createTemporaryObject(pillComponent, tc, { connected: false, port: 51413 })
        compare(text(pill, "statusConnection"), "No connection")
        verify(!Qt.colorEqual(findChild(pill, "statusDot").color, Theme.accent), "the dot is not green offline")
    }

    function test_dhtAndTotals() {
        const pill = createTemporaryObject(pillComponent, tc, {
            dhtNodes: 412,
            totalDownloaded: 1.2 * 1024 * 1024 * 1024 * 1024,
            totalUploaded: 2.2 * 1024 * 1024 * 1024 * 1024
        })
        compare(text(pill, "statusDht"), "DHT 412 nodes")
        compare(text(pill, "statusTotals"), "Total ↓ " + Format.size(1.2 * 1024 * 1024 * 1024 * 1024)
                + " · ↑ " + Format.size(2.2 * 1024 * 1024 * 1024 * 1024))
        // totals sit at the right end of the pill
        const totals = findChild(pill, "statusTotals")
        const right = totals.mapToItem(pill, totals.width, 0).x
        compare(Math.round(right), pill.width - 16)
    }

    function test_russian_data() {
        return [
            { tag: "1", n: 1, dht: "DHT 1 узел" },
            { tag: "3", n: 3, dht: "DHT 3 узла" },
            { tag: "412", n: 412, dht: "DHT 412 узлов" },
        ]
    }

    function test_russian(data) {
        verify(FluxTestI18n.setLanguage("ru"))
        const pill = createTemporaryObject(pillComponent, tc, { connected: true, port: 51413, dhtNodes: data.n })
        compare(text(pill, "statusConnection"), "Подключено · порт 51413")
        compare(text(pill, "statusDht"), data.dht)
        verify(text(pill, "statusTotals").startsWith("Всего ↓ "))
        pill.connected = false
        compare(text(pill, "statusConnection"), "Нет соединения")
    }
}
