import SwiftUI

struct CompactColorPickerPanel: View {
    @Binding var selectedHex: String
    @Binding var savedHexes: [String]

    @State private var hue: Double
    @State private var saturation: Double
    @State private var brightness: Double
    @State private var hexText: String
    @State private var isSynchronizing = false

    private let swatchColumns = Array(repeating: GridItem(.fixed(24), spacing: 8), count: 8)
    private let maxSwatches = 40

    init(selectedHex: Binding<String>, savedHexes: Binding<[String]>) {
        _selectedHex = selectedHex
        _savedHexes = savedHexes

        let color = NSColor(hex: selectedHex.wrappedValue) ?? .systemYellow
        let components = color.hsbaComponents
        _hue = State(initialValue: components.hue)
        _saturation = State(initialValue: components.saturation)
        _brightness = State(initialValue: components.brightness)
        _hexText = State(initialValue: color.hexString.replacingOccurrences(of: "#", with: ""))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SaturationBrightnessField(
                hue: $hue,
                saturation: $saturation,
                brightness: $brightness
            )
            .frame(width: 272, height: 168)

            HueSlider(hue: $hue)
                .frame(width: 272, height: 26)

            VStack(alignment: .leading, spacing: 8) {
                Text("HEX")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.black.opacity(0.62))

                HStack(spacing: 8) {
                    Text("#")
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Color.black.opacity(0.72))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(panelFieldBackground)

                    TextField("F9822B", text: hexTextBinding)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(panelFieldBackground)
                }
            }

            Divider()
                .overlay(Color.black.opacity(0.08))

            VStack(alignment: .leading, spacing: 10) {
                Text("颜色库")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.black.opacity(0.62))

                HStack(alignment: .top, spacing: 8) {
                    Button(action: appendCurrentColorToLibrary) {
                        Image(systemName: "plus")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.primary)
                            .frame(width: 24, height: 24)
                            .background(
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .fill(Color.black.opacity(0.05))
                            )
                    }
                    .buttonStyle(.plain)
                    .help("把当前颜色加入颜色库")

                    LazyVGrid(columns: swatchColumns, alignment: .leading, spacing: 8) {
                        ForEach(savedHexes, id: \.self) { hex in
                            Button {
                                apply(hex: hex)
                            } label: {
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .fill(Color(hex: hex))
                                    .frame(width: 24, height: 24)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                                            .stroke(
                                                hex == selectedHex ? Color.accentColor.opacity(0.9) : Color.black.opacity(0.14),
                                                lineWidth: hex == selectedHex ? 1.6 : 0.8
                                            )
                                    )
                                    .shadow(color: .black.opacity(0.24), radius: 2, y: 1)
                            }
                            .buttonStyle(.plain)
                            .help(hex)
                        }
                    }
                }
            }
        }
        .padding(14)
        .frame(width: 300)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.black.opacity(0.08), lineWidth: 0.8)
        )
        .shadow(color: .black.opacity(0.22), radius: 16, y: 8)
        .onChange(of: hue) { _, _ in
            updateSelectedHexFromComponents()
        }
        .onChange(of: saturation) { _, _ in
            updateSelectedHexFromComponents()
        }
        .onChange(of: brightness) { _, _ in
            updateSelectedHexFromComponents()
        }
    }

    private var panelFieldBackground: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(Color.black.opacity(0.04))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.black.opacity(0.08), lineWidth: 0.8)
            )
    }

    private var hexTextBinding: Binding<String> {
        Binding(
            get: { hexText },
            set: { newValue in
                handleHexTextChange(newValue)
            }
        )
    }

    private func handleHexTextChange(_ newValue: String) {
        guard !isSynchronizing else { return }

        let filtered = String(newValue.uppercased().filter(\.isHexDigit).prefix(6))
        isSynchronizing = true
        hexText = filtered
        isSynchronizing = false

        guard filtered.count == 6 else { return }
        apply(hex: "#\(filtered)")
    }

    private func updateSelectedHexFromComponents() {
        guard !isSynchronizing else { return }
        let newHex = NSColor(hue: hue, saturation: saturation, brightness: brightness).hexString
        isSynchronizing = true
        if selectedHex != newHex {
            selectedHex = newHex
        }
        hexText = newHex.replacingOccurrences(of: "#", with: "")
        isSynchronizing = false
    }

    private func apply(hex: String) {
        guard let normalized = hex.normalizedHexColor, let color = NSColor(hex: normalized) else { return }
        let components = color.hsbaComponents
        isSynchronizing = true
        selectedHex = normalized
        hue = components.hue
        saturation = components.saturation
        brightness = components.brightness
        hexText = normalized.replacingOccurrences(of: "#", with: "")
        isSynchronizing = false
    }

    private func appendCurrentColorToLibrary() {
        let normalized = selectedHex.normalizedHexColor ?? selectedHex
        var next = savedHexes.filter { $0 != normalized }
        next.insert(normalized, at: 0)
        savedHexes = Array(next.prefix(maxSwatches))
    }
}

private struct SaturationBrightnessField: View {
    @Binding var hue: Double
    @Binding var saturation: Double
    @Binding var brightness: Double

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size

            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(hue: hue, saturation: 1, brightness: 1))

                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [.white, .white.opacity(0)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )

                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [.clear, .black],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                Circle()
                    .strokeBorder(.white, lineWidth: 3)
                    .background(Circle().fill(Color.clear))
                    .frame(width: 18, height: 18)
                    .shadow(color: .black.opacity(0.35), radius: 3, y: 1)
                    .position(
                        x: max(9, min(size.width - 9, saturation * size.width)),
                        y: max(9, min(size.height - 9, (1 - brightness) * size.height))
                    )
            }
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        updateSelection(at: value.location, size: size)
                    }
            )
        }
    }

    private func updateSelection(at location: CGPoint, size: CGSize) {
        let clampedX = max(0, min(size.width, location.x))
        let clampedY = max(0, min(size.height, location.y))
        saturation = clampedX / max(size.width, 1)
        brightness = 1 - (clampedY / max(size.height, 1))
    }
}

private struct HueSlider: View {
    @Binding var hue: Double

    private let gradientColors: [Color] = stride(from: 0.0, through: 1.0, by: 1.0 / 6.0).map {
        Color(hue: $0, saturation: 1, brightness: 1)
    }

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width

            ZStack {
                Capsule(style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: gradientColors,
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )

                Circle()
                    .strokeBorder(.white, lineWidth: 3)
                    .background(Circle().fill(Color.clear))
                    .frame(width: 18, height: 18)
                    .shadow(color: .black.opacity(0.35), radius: 3, y: 1)
                    .position(x: max(9, min(width - 9, hue * width)), y: geometry.size.height / 2)
            }
            .contentShape(Capsule(style: .continuous))
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let clampedX = max(0, min(width, value.location.x))
                        hue = clampedX / max(width, 1)
                    }
            )
        }
    }
}
