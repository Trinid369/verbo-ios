// DesignSystem.swift
// Sistema visual do VERBO — cores, tipografia, componentes reutilizáveis
// Trinid © 2026

import SwiftUI

// MARK: - Cores

extension Color {
    static let vBackground   = Color("vBackground",   bundle: nil).resolvedOr(Color(hex: "0D0D12"))
    static let vSurface      = Color("vSurface",      bundle: nil).resolvedOr(Color(hex: "16161E"))
    static let vSurface2     = Color("vSurface2",     bundle: nil).resolvedOr(Color(hex: "1E1E2A"))
    static let vSurface3     = Color("vSurface3",     bundle: nil).resolvedOr(Color(hex: "252535"))
    static let vAccent       = Color("vAccent",       bundle: nil).resolvedOr(Color(hex: "6C63FF"))
    static let vAccentSoft   = Color("vAccentSoft",   bundle: nil).resolvedOr(Color(hex: "6C63FF").opacity(0.15))
    static let vTextPrimary  = Color("vTextPrimary",  bundle: nil).resolvedOr(Color(hex: "F0F0F8"))
    static let vTextSecondary = Color("vTextSecondary", bundle: nil).resolvedOr(Color(hex: "9090A8"))
    static let vTextTertiary = Color("vTextTertiary", bundle: nil).resolvedOr(Color(hex: "505060"))
    static let vBorder       = Color("vBorder",       bundle: nil).resolvedOr(Color(hex: "2A2A3A"))
    static let vGreen        = Color(hex: "34D399")
    static let vRed          = Color(hex: "F87171")
    static let vOrange       = Color(hex: "FBBF24")
    static let vPurple       = Color(hex: "A78BFA")
    static let vCyan         = Color(hex: "67E8F9")

    // Gradiente principal
    static let vGradient = LinearGradient(
        colors: [Color(hex: "6C63FF"), Color(hex: "A78BFA")],
        startPoint: .topLeading, endPoint: .bottomTrailing)

    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: (a,r,g,b) = (255,(int>>8)*17,(int>>4&0xF)*17,(int&0xF)*17)
        case 6: (a,r,g,b) = (255,int>>16,int>>8&0xFF,int&0xFF)
        case 8: (a,r,g,b) = (int>>24,int>>16&0xFF,int>>8&0xFF,int&0xFF)
        default:(a,r,g,b) = (255,0,0,0)
        }
        self.init(.sRGB, red: Double(r)/255, green: Double(g)/255, blue: Double(b)/255, opacity: Double(a)/255)
    }

    func resolvedOr(_ fallback: Color) -> Color { fallback }
}

private extension Color {
    static func resolvedOr(_ fallback: Color) -> Color { fallback }
}

// MARK: - Tipografia

extension Font {
    static let vLargeTitle  = Font.system(size: 28, weight: .bold,    design: .rounded)
    static let vTitle       = Font.system(size: 20, weight: .semibold, design: .rounded)
    static let vTitle2      = Font.system(size: 17, weight: .semibold, design: .rounded)
    static let vBody        = Font.system(size: 15, weight: .regular,  design: .default)
    static let vBodyMedium  = Font.system(size: 15, weight: .medium,   design: .default)
    static let vCaption     = Font.system(size: 12, weight: .regular,  design: .monospaced)
    static let vCaption2    = Font.system(size: 11, weight: .medium,   design: .default)
    static let vMono        = Font.system(size: 13, weight: .regular,  design: .monospaced)
}

// MARK: - Componentes Reutilizáveis

// Badge do agente
struct AgentBadge: View {
    let agentID: String
    @EnvironmentObject var engine: VERBOEngine

    var meta: (name: String, icon: String, description: String) {
        engine.agentMeta(for: agentID)
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: meta.icon)
                .font(.system(size: 9, weight: .semibold))
            Text(meta.name)
                .font(.vCaption2)
                .fontWeight(.semibold)
        }
        .foregroundColor(agentColor(agentID))
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(agentColor(agentID).opacity(0.12))
        .cornerRadius(6)
    }

    private func agentColor(_ id: String) -> Color {
        switch id {
        case "orchestrator": return .vAccent
        case "operator":     return .vOrange
        case "message":      return .vGreen
        case "mail":         return .vCyan
        case "calendar":     return .vPurple
        case "researcher":   return Color(hex: "F472B6")
        case "social":       return Color(hex: "FB923C")
        case "coder":        return Color(hex: "34D399")
        case "guardian":     return .vRed
        case "memory":       return Color(hex: "60A5FA")
        case "builder":      return .vGreen
        default:             return .vTextSecondary
        }
    }
}

// Indicador Φ (ACCU)
struct PhiIndicator: View {
    let value: Double
    var compact = false

    var color: Color {
        if value < 0.3 { return .vGreen }
        if value < 0.5 { return .vOrange }
        return .vRed
    }

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: compact ? 5 : 6, height: compact ? 5 : 6)
                .shadow(color: color.opacity(0.6), radius: 3)
            if !compact {
                Text("Φ \(String(format: "%.3f", value))")
                    .font(.vCaption)
                    .foregroundColor(.vTextSecondary)
            }
        }
    }
}

// Card de estatística
struct StatCard: View {
    let title: String
    let value: String
    let icon : String
    var color: Color = .vAccent
    var trend: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(color)
                Spacer()
                if let t = trend {
                    Text(t)
                        .font(.vCaption2)
                        .foregroundColor(t.hasPrefix("+") ? .vGreen : .vRed)
                }
            }
            Text(value)
                .font(.vTitle)
                .foregroundColor(.vTextPrimary)
            Text(title)
                .font(.vCaption2)
                .foregroundColor(.vTextSecondary)
        }
        .padding(14)
        .background(Color.vSurface2)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.vBorder, lineWidth: 0.5))
    }
}

// Botão primário
struct VERBOButton: View {
    let title  : String
    let icon   : String?
    let action : () -> Void
    var style  : ButtonStyle = .primary
    var isLoading = false

    enum ButtonStyle { case primary, secondary, destructive }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .tint(style == .primary ? .white : .vAccent)
                        .scaleEffect(0.8)
                } else if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                }
                Text(title)
                    .font(.vBodyMedium)
            }
            .foregroundColor(foregroundColor)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(backgroundColor)
            .cornerRadius(12)
        }
        .disabled(isLoading)
    }

    private var foregroundColor: Color {
        switch style {
        case .primary:     return .white
        case .secondary:   return .vAccent
        case .destructive: return .vRed
        }
    }
    private var backgroundColor: Color {
        switch style {
        case .primary:     return .vAccent
        case .secondary:   return .vAccentSoft
        case .destructive: return .vRed.opacity(0.15)
        }
    }
}

// Campo de texto VERBO
struct VERBOTextField: View {
    let placeholder : String
    @Binding var text: String
    var icon         : String? = nil
    var isSecure     = false
    var keyboardType : UIKeyboardType = .default

    var body: some View {
        HStack(spacing: 10) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(.vTextTertiary)
                    .frame(width: 20)
            }
            if isSecure {
                SecureField(placeholder, text: $text)
                    .font(.vBody)
                    .foregroundColor(.vTextPrimary)
            } else {
                TextField(placeholder, text: $text)
                    .font(.vBody)
                    .foregroundColor(.vTextPrimary)
                    .keyboardType(keyboardType)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.vSurface2)
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.vBorder, lineWidth: 0.5))
    }
}

// Empty State
struct EmptyStateView: View {
    let icon    : String
    let title   : String
    let subtitle: String
    var action  : (() -> Void)? = nil
    var actionLabel = "Começar"

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundColor(.vTextTertiary)
            Text(title)
                .font(.vTitle2)
                .foregroundColor(.vTextPrimary)
            Text(subtitle)
                .font(.vBody)
                .foregroundColor(.vTextSecondary)
                .multilineTextAlignment(.center)
            if let action {
                Button(action: action) {
                    Label(actionLabel, systemImage: "arrow.right")
                        .font(.vBodyMedium)
                        .foregroundColor(.vAccent)
                }
                .padding(.top, 4)
            }
        }
        .padding(32)
    }
}

// Section Header
struct SectionHeader: View {
    let title: String
    var trailing: String? = nil
    var trailingAction: (() -> Void)? = nil

    var body: some View {
        HStack {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(.vTextTertiary)
                .tracking(1.2)
            Spacer()
            if let trailing, let action = trailingAction {
                Button(action: action) {
                    Text(trailing)
                        .font(.vCaption2)
                        .foregroundColor(.vAccent)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 6)
    }
}

// Corner radius helper
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCornerShape(radius: radius, corners: corners))
    }
}

private struct RoundedCornerShape: Shape {
    var radius  : CGFloat
    var corners : UIRectCorner
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect,
                                byRoundingCorners: corners,
                                cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}

// Pulse animation
struct PulseCircle: View {
    @State private var scale = 1.0
    var color: Color = .vAccent
    var size: CGFloat = 8

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .scaleEffect(scale)
            .shadow(color: color.opacity(0.5), radius: scale * 4)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                    scale = 1.4
                }
            }
    }
}
