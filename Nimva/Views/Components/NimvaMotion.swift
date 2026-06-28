import SwiftUI

// MARK: - Animation presets
//
// Use these instead of ad-hoc Animation values anywhere in the app.
// Consistent curves make the UI feel intentional — every spring should
// feel like the same "material" even across different screens.

enum NimvaAnimation {
    // Snappy press/release — makes button taps feel physical and immediate
    static let buttonPress   = Animation.spring(response: 0.2, dampingFraction: 0.7)

    // Cards, sheets, and new content entering the screen — medium bounce
    static let cardAppear    = Animation.spring(response: 0.4, dampingFraction: 0.75)

    // State switches — Ember expression changes, mood labels, day selection
    // Slightly higher damping = settles quickly without lingering bounce
    static let stateChange   = Animation.spring(response: 0.35, dampingFraction: 0.85)

    // Progress bars, energy bar fill, numeric values ticking up
    static let valueUpdate   = Animation.easeOut(duration: 0.5)

    // Tab and screen transitions — subtle, quick crossfade
    static let transition    = Animation.easeInOut(duration: 0.25)

    // Squash-and-stretch — low damping so the spring overshoots on entry,
    // giving scaleY the "stretch past 1.0 then settle" feel
    static let squashStretch = Animation.spring(response: 0.42, dampingFraction: 0.58)
}

// MARK: - Reduce Motion

// iOS exposes a "Reduce Motion" accessibility setting for users sensitive to movement.
// WCAG 2.3.3 requires respecting this. It's also important for Nimva's audience —
// some ADHD users find animation distracting; vestibular disorder users can feel ill from it.
//
// Use .nimvaAnimation(_:value:) everywhere instead of plain .animation(_:value:).
// It automatically disables the animation when Reduce Motion is enabled.

extension View {
    func nimvaAnimation<V: Equatable>(_ animation: Animation, value: V) -> some View {
        modifier(ReduceMotionModifier(animation: animation, value: value))
    }
}

private struct ReduceMotionModifier<V: Equatable>: ViewModifier {
    // SwiftUI reads this from the iOS accessibility settings automatically
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let animation: Animation
    let value: V

    func body(content: Content) -> some View {
        content.animation(reduceMotion ? .none : animation, value: value)
    }
}

// MARK: - Press scale

// Subtle scale-down on press, spring-back on release.
// This physical response is especially grounding for ADHD users — the visual
// confirmation that "yes, I tapped that" reduces the urge to tap again.
// Also skipped when Reduce Motion is enabled.

extension View {
    func pressScale() -> some View {
        modifier(PressScaleModifier())
    }
}

private struct PressScaleModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isPressed = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed && !reduceMotion ? 0.96 : 1.0)
            .animation(NimvaAnimation.buttonPress, value: isPressed)
            // simultaneousGesture doesn't block the parent Button's tap action
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in isPressed = true }
                    .onEnded   { _ in isPressed = false }
            )
    }
}

// MARK: - Squash-Stretch Transition

// Used for text that changes with state (mood label, day note).
// On removal: the view squashes to scaleY ≈ 0 (wider in X, invisible).
// On insertion: springs from that squashed state back to full size — the bouncy
// spring overshoots scaleY past 1.0 before settling, which is the "stretch" beat.
// The opacity=0 in the active state means the swap happens while the view is invisible,
// so the content change doesn't flash.

private struct SquashTransformModifier: ViewModifier {
    var scaleX: CGFloat
    var scaleY: CGFloat
    var opacity: Double

    func body(content: Content) -> some View {
        content
            .scaleEffect(x: scaleX, y: scaleY)
            .opacity(opacity)
    }
}

extension AnyTransition {
    static var squashStretch: AnyTransition {
        .modifier(
            active:   SquashTransformModifier(scaleX: 1.2,  scaleY: 0.01, opacity: 0),
            identity: SquashTransformModifier(scaleX: 1.0,  scaleY: 1.0,  opacity: 1)
        )
    }
}

// MARK: - Minimum touch target

// WCAG 2.5.5 (Level AAA) and Apple HIG both specify 44×44pt minimum.
// Apply this to any interactive element that's visually smaller than that —
// it expands the tappable hit area without changing the visible layout.

extension View {
    func minTouchTarget() -> some View {
        self
            .frame(minWidth: NimvaLayout.minTouchTarget, minHeight: NimvaLayout.minTouchTarget)
            // contentShape makes the full frame respond to taps, not just the visible pixels
            .contentShape(Rectangle())
    }
}
