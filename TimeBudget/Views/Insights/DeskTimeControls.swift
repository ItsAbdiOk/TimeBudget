import SwiftUI

// MARK: - View Mode Picker

struct DeskTimeViewModePicker: View {
    @Binding var viewMode: DeskTimeViewModel.ViewMode

    var body: some View {
        HStack(spacing: 0) {
            ForEach(DeskTimeViewModel.ViewMode.allCases, id: \.self) { mode in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { viewMode = mode }
                } label: {
                    Text(mode.rawValue)
                        .font(.system(size: 13, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(viewMode == mode ? Color(.systemBackground) : Color.clear)
                                .shadow(color: viewMode == mode ? .black.opacity(0.08) : .clear, radius: 2, y: 1)
                        )
                        .foregroundStyle(viewMode == mode ? Color.primary : Color(.secondaryLabel))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

// MARK: - Device Filter Pills

struct DeskTimeDeviceFilterPills: View {
    @Binding var selectedDevice: AWSourceDevice?
    let totalMinutes: Int
    let macMinutes: Int
    let iphoneMinutes: Int

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                devicePill(label: "All Devices", icon: "circle.grid.2x2", device: nil, minutes: totalMinutes)
                devicePill(label: "Mac", icon: "desktopcomputer", device: .mac, minutes: macMinutes)
                devicePill(label: "iPhone", icon: "iphone", device: .iphone, minutes: iphoneMinutes)
            }
        }
    }

    private func devicePill(label: String, icon: String, device: AWSourceDevice?, minutes: Int) -> some View {
        let isSelected = selectedDevice == device
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedDevice = device
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                Text(label)
                    .font(.system(size: 13, weight: .semibold))
                Text(DeskTimeViewModel.formatMinutes(minutes))
                    .font(.system(size: 11))
                    .opacity(0.7)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 100, style: .continuous)
                    .fill(isSelected ? Color.blue.opacity(0.15) : Color(.secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 100, style: .continuous)
                    .stroke(isSelected ? Color.blue.opacity(0.3) : Color.clear, lineWidth: 1)
            )
            .foregroundStyle(isSelected ? .blue : Color(.secondaryLabel))
        }
        .buttonStyle(.plain)
    }
}

#Preview("View Mode Picker") {
    @Previewable @State var mode: DeskTimeViewModel.ViewMode = .daily
    DeskTimeViewModePicker(viewMode: $mode)
        .padding()
}

#Preview("Device Filter Pills") {
    @Previewable @State var device: AWSourceDevice? = nil
    DeskTimeDeviceFilterPills(
        selectedDevice: $device,
        totalMinutes: 320,
        macMinutes: 240,
        iphoneMinutes: 80
    )
    .padding()
}
