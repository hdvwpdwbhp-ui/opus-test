//
//  Theme.swift
//  Tanzen mit Tatiana Drexler
//
//  Glass Hubble Design System
//

import SwiftUI

// MARK: - Color Tokens
extension Color {
    // Primary Colors - Champagner/Gold Akzent (etwas gedämpfter)
    static let tdAccent = Color("AccentGold")
    static let tdAccentLight = Color("AccentGoldLight")
    
    // Background Colors
    static let tdBackground = Color("Background")
    static let tdBackgroundSecondary = Color("BackgroundSecondary")
    
    // Glass Colors - weniger hell
    static let tdGlassBackground = Color.black.opacity(0.05)
    static let tdGlassBorder = Color.gray.opacity(0.2)
    static let tdGlassShadow = Color.black.opacity(0.08)
    
    // Text Colors
    static let tdTextPrimary = Color("TextPrimary")
    static let tdTextSecondary = Color("TextSecondary")
    static let tdTextOnAccent = Color.white
    
    // Semantic Colors
    static let tdSuccess = Color.green
    static let tdError = Color.red
    static let tdWarning = Color.orange
    
    // Fallback implementations for colors - wärmere, sanftere Töne
    static var accentGold: Color {
        Color(red: 0.78, green: 0.65, blue: 0.45)
    }
    
    static var accentGoldLight: Color {
        Color(red: 0.88, green: 0.78, blue: 0.58)
    }
}

// MARK: - Spacing Tokens
struct TDSpacing {
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48
    static let xxxl: CGFloat = 64
}

// MARK: - Corner Radius Tokens
struct TDRadius {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
    static let full: CGFloat = 9999
}

// MARK: - Shadow Tokens
struct TDShadow {
    static let sm = Shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
    static let md = Shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 4)
    static let lg = Shadow(color: .black.opacity(0.16), radius: 16, x: 0, y: 8)
    static let glow = Shadow(color: Color.accentGold.opacity(0.4), radius: 12, x: 0, y: 0)
    
    struct Shadow {
        let color: Color
        let radius: CGFloat
        let x: CGFloat
        let y: CGFloat
    }
}

// MARK: - Typography
struct TDTypography {
    static let largeTitle = Font.system(size: 34, weight: .bold, design: .rounded)
    static let title1 = Font.system(size: 28, weight: .bold, design: .rounded)
    static let title2 = Font.system(size: 22, weight: .semibold, design: .rounded)
    static let title3 = Font.system(size: 20, weight: .semibold, design: .rounded)
    static let headline = Font.system(size: 17, weight: .semibold, design: .rounded)
    static let body = Font.system(size: 17, weight: .regular, design: .rounded)
    static let callout = Font.system(size: 16, weight: .regular, design: .rounded)
    static let subheadline = Font.system(size: 15, weight: .regular, design: .rounded)
    static let footnote = Font.system(size: 13, weight: .regular, design: .rounded)
    static let caption1 = Font.system(size: 12, weight: .regular, design: .rounded)
    static let caption2 = Font.system(size: 11, weight: .regular, design: .rounded)
}

// MARK: - Animation Tokens
struct TDAnimation {
    static let quick = Animation.easeInOut(duration: 0.2)
    static let normal = Animation.easeInOut(duration: 0.3)
    static let slow = Animation.easeInOut(duration: 0.5)
    static let spring = Animation.spring(response: 0.4, dampingFraction: 0.7)
    static let bouncy = Animation.spring(response: 0.5, dampingFraction: 0.6)
}

// MARK: - Glass Effect Modifier
struct GlassBackground: ViewModifier {
    var cornerRadius: CGFloat = TDRadius.lg
    var opacity: Double = 0.7
    
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color(white: 0.97))
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(white: 0.98),
                                        Color(white: 0.94)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(Color.gray.opacity(0.15), lineWidth: 1)
                    )
            )
            .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
    }
}

extension View {
    func glassBackground(cornerRadius: CGFloat = TDRadius.lg, opacity: Double = 0.15) -> some View {
        modifier(GlassBackground(cornerRadius: cornerRadius, opacity: opacity))
    }
}

// MARK: - Primary Button Style
struct TDPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(TDTypography.headline)
            .foregroundColor(.white)
            .padding(.horizontal, TDSpacing.lg)
            .padding(.vertical, TDSpacing.md)
            .background(
                LinearGradient(
                    colors: isEnabled
                        ? [Color.accentGold, Color.accentGoldLight]
                        : [Color.gray.opacity(0.5), Color.gray.opacity(0.3)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: TDRadius.md))
            .shadow(
                color: isEnabled ? Color.accentGold.opacity(0.4) : Color.clear,
                radius: configuration.isPressed ? 4 : 8,
                x: 0,
                y: configuration.isPressed ? 2 : 4
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(TDAnimation.quick, value: configuration.isPressed)
    }
}

// MARK: - Secondary Button Style
struct TDSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(TDTypography.headline)
            .foregroundColor(Color.accentGold)
            .padding(.horizontal, TDSpacing.lg)
            .padding(.vertical, TDSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: TDRadius.md)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: TDRadius.md)
                            .stroke(Color.accentGold.opacity(0.5), lineWidth: 1.5)
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(TDAnimation.quick, value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == TDPrimaryButtonStyle {
    static var tdPrimary: TDPrimaryButtonStyle { TDPrimaryButtonStyle() }
}

extension ButtonStyle where Self == TDSecondaryButtonStyle {
    static var tdSecondary: TDSecondaryButtonStyle { TDSecondaryButtonStyle() }
}

// MARK: - Gradient Backgrounds
struct TDGradients {
    // Sanfter, cremefarbener Hintergrund - nicht zu hell
    static var mainBackground: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.96, green: 0.94, blue: 0.91),
                Color(red: 0.92, green: 0.89, blue: 0.85)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
    
    static var darkBackground: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.12, green: 0.10, blue: 0.18),
                Color(red: 0.08, green: 0.06, blue: 0.12)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
    
    static var cardHighlight: LinearGradient {
        LinearGradient(
            colors: [
                Color.white.opacity(0.15),
                Color.white.opacity(0.03)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
