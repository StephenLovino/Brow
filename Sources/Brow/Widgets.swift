import SwiftUI
import IOKit.ps

struct DrawerView: View {
    @StateObject private var battery = BatteryMonitor()

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(context.date, format: .dateTime.hour().minute())
                        .font(.system(size: 26, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                    Text(context.date, format: .dateTime.weekday(.wide).day().month(.wide))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))
                }

                Spacer()

                if let level = battery.level {
                    BatteryBadge(level: level, charging: battery.isCharging)
                }
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 22)
            .padding(.vertical, 10)
        }
    }
}

struct BatteryBadge: View {
    let level: Int
    let charging: Bool

    var body: some View {
        HStack(spacing: 6) {
            Text("\(level)%")
                .font(.system(size: 13, weight: .semibold))
                .monospacedDigit()
            Image(systemName: charging ? "battery.100percent.bolt" : symbol)
                .font(.system(size: 18))
                .foregroundStyle(level <= 20 && !charging ? Color.red : Color.white)
        }
    }

    private var symbol: String {
        switch level {
        case ..<13: "battery.0percent"
        case ..<38: "battery.25percent"
        case ..<63: "battery.50percent"
        case ..<88: "battery.75percent"
        default: "battery.100percent"
        }
    }
}

final class BatteryMonitor: ObservableObject {
    /// Nil on Macs without an internal battery.
    @Published private(set) var level: Int?
    @Published private(set) var isCharging = false

    private var timer: Timer?

    init() {
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    deinit {
        timer?.invalidate()
    }

    private func refresh() {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef]
        else {
            level = nil
            return
        }

        for source in sources {
            guard let description = IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue() as? [String: Any],
                  description[kIOPSTypeKey] as? String == kIOPSInternalBatteryType,
                  let current = description[kIOPSCurrentCapacityKey] as? Int,
                  let max = description[kIOPSMaxCapacityKey] as? Int, max > 0
            else { continue }

            level = current * 100 / max
            isCharging = description[kIOPSIsChargingKey] as? Bool ?? false
            return
        }
        level = nil
    }
}
