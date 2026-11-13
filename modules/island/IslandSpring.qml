import QtQuick

// Damped spring integrated on every rendered frame, parameterised like SwiftUI's
// spring(response:dampingFraction:). Unlike SpringAnimation (fixed 16ms steps), this stays smooth
// on high refresh rate displays and keeps its velocity when the target changes mid-flight.
FrameAnimation {
    id: root

    property real target
    property real value
    property real velocity

    // Period of the undamped oscillation, in seconds
    property real response: 0.42
    // 1 = critically damped (no overshoot), < 1 = bouncy
    property real dampingFraction: 0.8
    // While idle, jump straight to new targets instead of animating
    property bool instant

    function snap(): void {
        running = false;
        velocity = 0;
        value = target;
    }

    onTargetChanged: {
        if (instant && !running)
            snap();
        else
            running = true;
    }

    onTriggered: {
        const dt = Math.min(frameTime, 1 / 20);
        const omega = 2 * Math.PI / Math.max(0.05, response);
        const stiffness = omega * omega;
        const damping = 2 * dampingFraction * omega;

        // Sub-step for stability with large frame times
        const steps = Math.max(1, Math.ceil(dt / 0.004));
        const h = dt / steps;
        let x = value;
        let v = velocity;
        for (let i = 0; i < steps; i++) {
            v += (stiffness * (target - x) - damping * v) * h;
            x += v * h;
        }

        if (Math.abs(target - x) < 0.1 && Math.abs(v) < 2) {
            snap();
        } else {
            velocity = v;
            value = x;
        }
    }

    Component.onCompleted: snap()
}
