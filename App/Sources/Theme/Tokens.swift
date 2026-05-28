// App/Sources/Theme/Tokens.swift
//
// Design tokens from UX Design v1.0 §7 and v0.6 prototype.
// Adaptive light/dark colors, typography, spacing, shadows, radii.

import AppKit
import SwiftUI

// MARK: - Adaptive Color Helper

private func adaptiveColor(light: (CGFloat, CGFloat, CGFloat), dark: (CGFloat, CGFloat, CGFloat)) -> Color {
    Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
        let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let c = isDark ? dark : light
        return NSColor(red: c.0, green: c.1, blue: c.2, alpha: 1)
    }))
}

// MARK: - Colors

public enum PareColor {
    // Backgrounds
    public static let bg       = adaptiveColor(light: (0.980, 0.980, 0.969), dark: (0.086, 0.082, 0.071))  // #FAFAF7 / #161512
    public static let surface  = adaptiveColor(light: (1.000, 1.000, 1.000), dark: (0.122, 0.118, 0.102))  // #FFFFFF / #1F1E1A
    public static let surface2 = adaptiveColor(light: (0.957, 0.953, 0.933), dark: (0.157, 0.149, 0.122))  // #F4F3EE / #28261F

    // Lines
    public static let line       = adaptiveColor(light: (0.910, 0.902, 0.875), dark: (0.204, 0.196, 0.169))  // #E8E6DF / #34322B
    public static let lineStrong = adaptiveColor(light: (0.831, 0.820, 0.780), dark: (0.275, 0.267, 0.231))  // #D4D1C7 / #46443B

    // Ink (text)
    public static let ink  = adaptiveColor(light: (0.082, 0.078, 0.059), dark: (0.961, 0.953, 0.925))  // #15140F / #F5F3EC
    public static let ink2 = adaptiveColor(light: (0.227, 0.220, 0.200), dark: (0.847, 0.835, 0.788))  // #3A3833 / #D8D5C9
    public static let ink3 = adaptiveColor(light: (0.420, 0.408, 0.384), dark: (0.592, 0.580, 0.549))  // #6B6862 / #97948C
    public static let ink4 = adaptiveColor(light: (0.592, 0.580, 0.549), dark: (0.420, 0.408, 0.384))  // #97948C / #6B6862

    // Accent (forest green)
    public static let forest     = adaptiveColor(light: (0.106, 0.369, 0.247), dark: (0.420, 0.694, 0.549))  // #1B5E3F / #6BB18C
    public static let accentSoft = adaptiveColor(light: (0.910, 0.941, 0.922), dark: (0.122, 0.227, 0.173))  // #E8F0EB / #1F3A2C
    public static let accentLine = adaptiveColor(light: (0.722, 0.831, 0.757), dark: (0.180, 0.325, 0.251))  // #B8D4C1 / #2E5340

    // Warning (burnt orange)
    public static let warning     = adaptiveColor(light: (0.722, 0.455, 0.173), dark: (0.890, 0.655, 0.369))  // #B8742C / #E3A75E
    public static let warningSoft = adaptiveColor(light: (0.961, 0.925, 0.871), dark: (0.227, 0.165, 0.078))  // #F5ECDE / #3A2A14

    // Danger (muted red)
    public static let danger = adaptiveColor(light: (0.545, 0.180, 0.180), dark: (0.839, 0.471, 0.471))  // #8B2E2E / #D67878
}

// MARK: - Storage Category Colors

public enum CategoryColor {
    public static let apps      = Color(red: 0.173, green: 0.373, blue: 0.290)  // #2C5F4A
    public static let documents = Color(red: 0.420, green: 0.557, blue: 0.353)  // #6B8E5A
    public static let media     = Color(red: 0.722, green: 0.455, blue: 0.173)  // #B8742C
    public static let system    = Color(red: 0.592, green: 0.580, blue: 0.549)  // #97948C
    public static let other     = Color(red: 0.788, green: 0.773, blue: 0.722)  // #C9C5B8
}

// MARK: - Typography

public enum PareFont {
    /// Display — Fraunces for screen titles + large numbers.
    /// Falls back to the system serif design when Fraunces is not installed.
    public static func display(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        if fontAvailable("Fraunces") {
            return .custom("Fraunces", size: size).weight(weight)
        }
        return .system(size: size, weight: weight, design: .serif)
    }

    /// Body / UI — Inter.
    /// Falls back to the default system font (SF Pro) when Inter is not installed.
    public static func body(_ size: CGFloat = 13, weight: Font.Weight = .regular) -> Font {
        if fontAvailable("Inter") {
            return .custom("Inter", size: size).weight(weight)
        }
        return .system(size: size, weight: weight, design: .default)
    }

    /// Mono — JetBrains Mono for paths, sizes, percentages.
    /// Falls back to the system monospaced design when JetBrains Mono is not installed.
    public static func mono(_ size: CGFloat = 12, weight: Font.Weight = .regular) -> Font {
        if fontAvailable("JetBrainsMono-Regular") {
            return .custom("JetBrainsMono-Regular", size: size).weight(weight)
        }
        return .system(size: size, weight: weight, design: .monospaced)
    }

    /// Section label style — mono, uppercase, small.
    public static let sectionLabel = mono(10, weight: .medium)

    private static func fontAvailable(_ name: String) -> Bool {
        NSFont(name: name, size: 12) != nil
    }
}

// MARK: - Spacing

public enum PareSpacing {
    public static let xs: CGFloat = 4
    public static let sm: CGFloat = 8
    public static let md: CGFloat = 12
    public static let lg: CGFloat = 24
    public static let xl: CGFloat = 32
    public static let xxl: CGFloat = 40
}

// MARK: - Corner Radius

public enum PareRadius {
    public static let standard: CGFloat = 10
    public static let large: CGFloat = 14
    public static let small: CGFloat = 6
}

// MARK: - Shadows (refined for depth)

public struct PareShadow: ViewModifier {
    public enum Level { case small, medium, large }
    let level: Level

    public func body(content: Content) -> some View {
        switch level {
        case .small:
            content
                .shadow(color: Color.black.opacity(0.03), radius: 1, x: 0, y: 1)
                .shadow(color: Color.black.opacity(0.02), radius: 3, x: 0, y: 2)
        case .medium:
            content
                .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
                .shadow(color: Color.black.opacity(0.03), radius: 12, x: 0, y: 6)
        case .large:
            content
                .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 4)
                .shadow(color: Color.black.opacity(0.04), radius: 40, x: 0, y: 16)
        }
    }
}

public extension View {
    func pareShadow(_ level: PareShadow.Level) -> some View {
        modifier(PareShadow(level: level))
    }
}

// MARK: - Card Style (refined with subtle inner glow)

public struct PareCardStyle: ViewModifier {
    var radius: CGFloat = PareRadius.standard

    public func body(content: Content) -> some View {
        content
            .background(PareColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(PareColor.line, lineWidth: 0.5)
            )
            .shadow(color: Color.black.opacity(0.03), radius: 1, x: 0, y: 1)
    }
}

public extension View {
    func pareCard(radius: CGFloat = PareRadius.standard) -> some View {
        modifier(PareCardStyle(radius: radius))
    }
}

// MARK: - View Transitions

public extension AnyTransition {
    static var pareSlide: AnyTransition {
        .asymmetric(
            insertion: .opacity.combined(with: .offset(y: 6)),
            removal: .opacity
        )
    }
}

// MARK: - Hover Card Modifier

public struct HoverLift: ViewModifier {
    @State private var isHovered = false
    let maxLift: CGFloat

    public init(maxLift: CGFloat = 2) { self.maxLift = maxLift }

    public func body(content: Content) -> some View {
        content
            .offset(y: isHovered ? -maxLift : 0)
            .shadow(color: Color.black.opacity(isHovered ? 0.08 : 0.03), radius: isHovered ? 12 : 2, x: 0, y: isHovered ? 6 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isHovered)
            .onHover { isHovered = $0 }
    }
}

public extension View {
    func hoverLift(_ maxLift: CGFloat = 2) -> some View {
        modifier(HoverLift(maxLift: maxLift))
    }
}
