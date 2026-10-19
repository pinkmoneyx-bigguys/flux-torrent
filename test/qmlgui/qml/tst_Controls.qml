import QtQuick
import QtTest
import Flux

TestCase {
    id: root
    name: "Controls"
    width: 640
    height: 520
    visible: true // grabImage captures the window, so the test case must be shown
    when: windowShown

    Component { id: spyComponent; SignalSpy {} }
    Component { id: toastComponent; Toast {} }

    Item {
        id: surface
        anchors.fill: parent

        PillButton { id: pill; x: 10; y: 10; text: "Add" }
        PillButton { id: pillPrimary; x: 110; y: 10; text: "Save"; primary: true; shortcutHint: "Enter" }
        PillButton { id: pillOff; x: 260; y: 10; text: "Off"; enabled: false }
        IconButton { id: iconBtn; x: 10; y: 60; iconPath: Icons.plus; Accessible.name: "Add item" }
        GlassSwitch { id: sw; x: 60; y: 60; Accessible.name: "Switch" }
        GlassSwitch { id: swOn; x: 120; y: 60; checked: true; Accessible.name: "Switch on" }
        GlassCheckBox { id: cb; x: 200; y: 64; Accessible.name: "Check" }
        GlassCheckBox { id: cbOff; x: 240; y: 64; Accessible.name: "Check off" }
        SegmentedControl {
            id: seg
            x: 10; y: 110
            model: ["All", "Active", "Done"]
        }
        FluxProgressBar { id: bar; x: 10; y: 160; width: 200; value: 0.5 }
        FluxProgressBar { id: barGlow; x: 10; y: 180; width: 200; value: 0.5; glow: true }
        Rectangle { id: sibling; x: 300; y: 60; width: 18; height: 18; color: "black" }
        Toast { id: toast; x: 10; y: 220 }
    }

    function signalSpy(target, signalName) {
        const spy = createTemporaryObject(spyComponent, root, { target: target, signalName: signalName })
        verify(spy.valid, "spy for " + signalName)
        return spy
    }

    function cleanup() {
        Theme.reducedMotion = false
        sw.checked = false
        cb.checked = false
        seg.currentIndex = 0
        bar.value = 0.5
        toast.hide()
        toast.actions = []
        tryVerify(() => !toast.visible, 2000)
        // let switch/check animations from mouse toggles settle
        tryCompare(sw.knob, "x", 3, 1000)
        tryCompare(cb.mark, "opacity", 0, 1000)
        tryVerify(() => sw.track.color.a < 0.15, 1000)
        tryVerify(() => seg.itemAt(0).background.color.a > 0.139 && seg.itemAt(2).background.color.a < 0.07, 1000)
    }

    // --- PillButton -------------------------------------------------------------------------------
    function test_pillDefaults() {
        compare(pill.height, 36)
        compare(pill.background.radius, 18)
        compare(pill.primary, false)
        compare(pill.iconPath, "")
        compare(pill.shortcutHint, "")
    }

    function test_pillClicks() {
        const spy = signalSpy(pill, "clicked")
        mouseClick(pill)
        compare(spy.count, 1)
    }

    function test_pillPrimaryLook() {
        verify(Qt.colorEqual(pillPrimary.background.color, Theme.accent))
        verify(!Qt.colorEqual(pill.background.color, Theme.accent))
        waitForRendering(pillPrimary)
        const img = grabImage(pillPrimary)
        verify(!Qt.colorEqual(img.pixel(pillPrimary.width / 2, 18), img.pixel(0, 18)),
               "the accent pill differs from what is behind its corner")
    }

    function test_pillPressScale() {
        mousePress(pill)
        tryCompare(pill, "scale", 0.97, 1000)
        mouseRelease(pill)
        tryCompare(pill, "scale", 1.0, 1000)
    }

    function test_pressScaleDisabledWithReducedMotion() {
        Theme.reducedMotion = true
        mousePress(pill)
        compare(pill.scale, 1.0)
        mouseRelease(pill)
        Theme.reducedMotion = false
    }

    function test_pillAccessible() {
        compare(pill.Accessible.role, Accessible.Button)
        compare(pill.Accessible.name, "Add")
        compare(pill.focusPolicy, Qt.StrongFocus)
    }

    function test_pillKeyboard() {
        const spy = signalSpy(pill, "clicked")
        pill.forceActiveFocus()
        keyClick(Qt.Key_Space)
        compare(spy.count, 1)
    }

    // --- IconButton -------------------------------------------------------------------------------
    function test_iconButtonSize() {
        compare(iconBtn.width, 32)
        compare(iconBtn.height, 32)
        compare(iconBtn.background.radius, 16)
    }

    function test_iconButtonClicks() {
        const spy = signalSpy(iconBtn, "clicked")
        mouseClick(iconBtn)
        compare(spy.count, 1)
    }

    function test_iconButtonWarnsWithoutName() {
        ignoreWarning(/Accessible\.name/)
        const b = createTemporaryObject(Qt.createComponent("Flux", "IconButton"), root, { iconPath: Icons.plus })
        verify(b !== null)
    }

    // --- GlassSwitch ------------------------------------------------------------------------------
    function test_switchToggles() {
        mouseClick(sw)
        verify(sw.checked)
        mouseClick(sw)
        verify(!sw.checked)
    }

    function test_switchKeyboard() {
        sw.forceActiveFocus()
        keyClick(Qt.Key_Space)
        verify(sw.checked)
        keyClick(Qt.Key_Space)
        verify(!sw.checked)
    }

    function test_switchGeometryAndRole() {
        compare(sw.width, 44)
        compare(sw.height, 26)
        verify(sw.checkable)
        compare(sw.Accessible.role, Accessible.CheckBox)
        compare(sw.focusPolicy, Qt.StrongFocus)
    }

    function test_switchKnobSide() {
        sw.checked = true
        tryVerify(() => sw.knob.x === 44 - 3 - 20, 1000)
        sw.checked = false
        tryVerify(() => sw.knob.x === 3, 1000)
        compare(sw.knob.width, 20)
    }

    function test_switchTrackColors() {
        waitForRendering(sw)
        verify(Qt.colorEqual(swOn.track.color, Theme.accent))
        compare(sw.track.color.a.toFixed(2), "0.14")
    }

    // --- GlassCheckBox ----------------------------------------------------------------------------
    function test_checkboxToggles() {
        mouseClick(cb)
        verify(cb.checked)
        cb.forceActiveFocus()
        keyClick(Qt.Key_Space)
        verify(!cb.checked)
    }

    function test_checkboxGeometry() {
        compare(cb.width, 18)
        compare(cb.height, 18)
        verify(cb.checkable)
    }

    function test_checkboxShowsCheck() {
        cb.checked = true
        wait(200)
        waitForRendering(cb)
        verify(!Qt.colorEqual(grabImage(cb).pixel(9, 9), grabImage(cbOff).pixel(9, 9)))
    }

    // --- SegmentedControl -------------------------------------------------------------------------
    function test_segmentedActivates() {
        const spy = signalSpy(seg, "activated")
        mouseClick(seg.itemAt(2))
        compare(seg.currentIndex, 2)
        compare(spy.count, 1)
        compare(spy.signalArguments[0][0], 2)
    }

    function test_segmentedModelAndSelection() {
        verify(seg.itemAt(0) !== null)
        verify(seg.itemAt(2) !== null)
        compare(seg.itemAt(3), null)
        compare(seg.itemAt(1).text, "Active")
        verify(seg.itemAt(0).checked)
        seg.currentIndex = 1
        verify(seg.itemAt(1).checked)
        verify(!seg.itemAt(0).checked)
    }

    function test_segmentedKeyboard() {
        const spy = signalSpy(seg, "activated")
        seg.itemAt(0).forceActiveFocus()
        keyClick(Qt.Key_Right)
        compare(seg.currentIndex, 1)
        keyClick(Qt.Key_Right)
        compare(seg.currentIndex, 2)
        keyClick(Qt.Key_Right) // stays at the end
        compare(seg.currentIndex, 2)
        keyClick(Qt.Key_Left)
        compare(seg.currentIndex, 1)
        compare(spy.count, 3)
    }

    function test_segmentedKeyboardSelectionIsInstant() {
        const selected = Qt.rgba(1, 1, 1, 0.14)
        seg.itemAt(0).forceActiveFocus()
        keyClick(Qt.Key_Right)
        compare(seg.currentIndex, 1)
        verify(Qt.colorEqual(seg.itemAt(1).background.color, selected),
               "pill is at its final colour: " + seg.itemAt(1).background.color)
        keyClick(Qt.Key_Right)
        compare(seg.currentIndex, 2)
        verify(Qt.colorEqual(seg.itemAt(2).background.color, selected))
    }

    function test_segmentedSpaceSelectionIsInstant() {
        seg.itemAt(1).forceActiveFocus()
        keyClick(Qt.Key_Space)
        compare(seg.currentIndex, 1)
        verify(Qt.colorEqual(seg.itemAt(1).background.color, Qt.rgba(1, 1, 1, 0.14)),
               "pill is at its final colour: " + seg.itemAt(1).background.color)
    }

    function test_segmentedMouseSelectionStillAnimates() {
        tryVerify(() => !seg._kbd, 1000)
        mouseClick(seg.itemAt(2))
        compare(seg.currentIndex, 2)
        verify(seg.itemAt(2).background.color.a < 0.14, "pill is fading in: " + seg.itemAt(2).background.color.a)
        tryVerify(() => seg.itemAt(2).background.color.a > 0.139, 1000)
    }

    function test_segmentedKeyboardFlagClearsAfterKeyUp() {
        seg.itemAt(0).forceActiveFocus()
        keyClick(Qt.Key_Right)
        compare(seg.currentIndex, 1)
        tryVerify(() => !seg._kbd, 1000)
        mouseClick(seg.itemAt(2))
        compare(seg.currentIndex, 2)
        verify(seg.itemAt(2).background.color.a < 0.14, "mouse selection animates again: " + seg.itemAt(2).background.color.a)
    }

    function test_segmentedKeyboardFlagClearsOnFocusLoss() {
        seg.itemAt(1).forceActiveFocus()
        keyPress(Qt.Key_Space) // key stays down: no release will reach the segment
        verify(seg._kbd)
        pill.forceActiveFocus() // focus leaves the control
        tryVerify(() => !seg._kbd, 1000)
        keyRelease(Qt.Key_Space)
        mouseClick(seg.itemAt(2))
        compare(seg.currentIndex, 2)
        verify(seg.itemAt(2).background.color.a < 0.14, "mouse selection animates again: " + seg.itemAt(2).background.color.a)
    }

    // --- FluxProgressBar --------------------------------------------------------------------------
    function test_progressGeometry() {
        compare(bar.height, 6)
        compare(bar.Accessible.role, Accessible.ProgressBar)
        fuzzyCompare(bar.fill.width, 100, 0.5)
        verify(Qt.colorEqual(bar.color, Theme.accent))
    }

    function test_progressClamps() {
        bar.value = 2
        fuzzyCompare(bar.fill.width, 200, 0.5)
        bar.value = -1
        compare(bar.fill.width, 0)
    }

    function test_progressGlowFlag() {
        compare(bar.glow, false)
        compare(barGlow.glow, true)
    }


    // --- Keyboard activation is never animated ------------------------------------------------------
    function test_pillKeyboardPressIsNotAnimated() {
        pill.forceActiveFocus()
        keyPress(Qt.Key_Space)
        verify(pill.pressed)
        wait(250)
        compare(pill.scale, 1.0)
        keyRelease(Qt.Key_Space)
        compare(pill.scale, 1.0)
    }

    function test_iconButtonKeyboardPressIsNotAnimated() {
        iconBtn.forceActiveFocus()
        keyPress(Qt.Key_Space)
        verify(iconBtn.pressed)
        wait(250)
        compare(iconBtn.scale, 1.0)
        keyRelease(Qt.Key_Space)
    }

    function test_switchKeyboardToggleIsInstant() {
        sw.forceActiveFocus()
        keyClick(Qt.Key_Space)
        verify(sw.checked)
        compare(sw.knob.x, 44 - 3 - 20)
        verify(Qt.colorEqual(sw.track.color, Theme.accent))
        keyClick(Qt.Key_Space)
        compare(sw.knob.x, 3)
        compare(sw.track.color.a.toFixed(2), "0.14")
    }

    function test_switchMouseToggleStillAnimates() {
        mouseClick(sw)
        verify(sw.checked)
        verify(sw.knob.x < 44 - 3 - 20, "knob is on its way: " + sw.knob.x)
        tryCompare(sw.knob, "x", 44 - 3 - 20, 1000)
    }

    function test_checkboxKeyboardToggleIsInstant() {
        cb.forceActiveFocus()
        keyClick(Qt.Key_Space)
        verify(cb.checked)
        verify(Qt.colorEqual(cb.background.color, Theme.accent))
        compare(cb.mark.opacity, 1)
        keyClick(Qt.Key_Space)
        compare(cb.mark.opacity, 0)
    }

    function test_checkboxMouseToggleStillAnimates() {
        mouseClick(cb)
        verify(cb.checked)
        verify(cb.mark.opacity < 1, "check is fading in: " + cb.mark.opacity)
        tryCompare(cb.mark, "opacity", 1, 1000)
    }

    // --- Toast ------------------------------------------------------------------------------------
    function test_toastButtonsDoNotWrap() {
        toast.actions = [{text: "Открыть папку"}, {text: "Остановить раздачу"}]
        toast.show()
        wait(400)
        compare(toast.buttons.length, 2)
        for (const b of toast.buttons) {
            verify(b.label.text.length > 0)
            verify(!b.label.truncated, "'" + b.label.text + "' is elided")
            verify(b.label.contentWidth <= b.label.width, "'" + b.label.text + "' does not fit")
            compare(b.label.lineCount, 1)
        }
        const a = toast.buttons[0].mapToItem(toast, 0, 0)
        const c = toast.buttons[1].mapToItem(toast, 0, 0)
        compare(a.y, c.y, "two columns, one row")
        verify(c.x > a.x)
        compare(toast.buttons[0].width, toast.buttons[1].width)
    }

    function test_toastLabelCheckDetectsTruncation() {
        // control experiment for the test above: in a narrow toast the same label really is elided
        const narrow = createTemporaryObject(toastComponent, root, {
            width: 200, x: 300, y: 300,
            actions: [{text: "Открыть папку"}, {text: "Остановить раздачу"}]
        })
        narrow.show()
        tryVerify(() => narrow.opacity === 1, 2000)
        verify(narrow.buttons[1].label.truncated)
    }

    function test_toastActionFontSize() {
        toast.actions = [{text: "Open"}]
        compare(toast.buttons[0].fontSize, 13)
        compare(toast.buttons[0].label.font.pixelSize, 13)
        compare(pill.fontSize, 14)
        compare(pill.label.font.pixelSize, 14)
    }

    function test_toastWidth() {
        compare(toast.width, 392)
    }

    function test_toastShowHide() {
        verify(!toast.visible)
        toast.show()
        tryVerify(() => toast.visible && toast.opacity === 1, 2000)
        toast.hide()
        tryVerify(() => !toast.visible, 2000)
    }

    function test_toastShowHideInstantWithReducedMotion() {
        Theme.reducedMotion = true
        toast.show()
        compare(toast.opacity, 1)
        toast.hide()
        compare(toast.opacity, 0)
        verify(!toast.visible)
    }

    function test_toastContentAndActions() {
        let fired = 0
        toast.title = "Done"
        toast.subtitle = "11.4 GB"
        toast.actions = [{text: "Open", primary: true, onTriggered: () => fired++}, {text: "Stop"}]
        toast.show()
        tryVerify(() => toast.opacity === 1, 2000)
        compare(toast.Accessible.name, "Done")
        verify(toast.buttons[0].primary)
        verify(!toast.buttons[1].primary)
        mouseClick(toast.buttons[0])
        compare(fired, 1)
        mouseClick(toast.buttons[1]) // no handler: must not throw
    }
}
