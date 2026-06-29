import SwiftUI
import AppKit

struct ContentView: View {
    @Environment(UsageModel.self) private var model
    @State private var showSettings = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            Divider()
            if !model.keyIsSet {
                SettingsForm()
            } else if showSettings {
                SettingsForm(onDone: { showSettings = false })
            } else {
                bodyContent
                Divider()
                PeakHoursView()
                Divider()
                footer
                AboutLine()
                    .padding(.top, 2)
            }
        }
        .padding(14)
    }

    // MARK: Subviews

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("z.ai coding plan").font(.headline)
                Text(planLabel.uppercased())
                    .font(.caption).fontWeight(.semibold).foregroundStyle(.secondary)
            }
            Spacer()
            if model.state == .loading { ProgressView().controlSize(.small) }
        }
    }

    private var planLabel: String {
        let l = model.level?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return l.isEmpty ? "coding plan" : l
    }

    @ViewBuilder
    private var bodyContent: some View {
        if case .error(let m) = model.state, model.limits.isEmpty {
            Label(m, systemImage: "exclamationmark.triangle.fill")
                .font(.caption).foregroundStyle(.orange)
        } else if model.limits.isEmpty {
            Text("Waiting for data…").foregroundStyle(.secondary).font(.callout)
        } else {
            VStack(alignment: .leading, spacing: 12) {
                if case .error(let m) = model.state {
                    Label(m, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption2).foregroundStyle(.orange)
                }
                ForEach(model.limits) { LimitRow(limit: $0) }
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 10) {
            if let d = model.lastUpdated {
                Text("updated \(d.formatted(.dateTime.hour().minute()))")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                Task { await model.refresh() }
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            Button("Settings") { showSettings = true }.buttonStyle(.borderless)
            Button("Quit", role: .destructive) { NSApp.terminate(nil) }
                .buttonStyle(.borderless)
        }
    }
}

// MARK: - Limit row

struct LimitRow: View {
    let limit: Limit

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(limit.kindLabel).font(.subheadline).fontWeight(.medium)
                Spacer()
                TimelineView(.periodic(from: .now, by: 30)) { ctx in
                    Text("reset in \(countdownString(to: limit.resetDate, now: ctx.date))")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }

            if let pct = limit.percentage {
                ProgressView(value: pct, total: 100)
                    .tint(statusColor(forPercentage: pct))
                HStack {
                    Text("\(Int(pct.rounded()))% used").font(.caption)
                    Spacer()
                    if let used = limit.currentValue, let total = limit.usage {
                        Text("\(compactNumber(used)) / \(compactNumber(total))")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }

            if let details = limit.usageDetails, !details.isEmpty, let total = limit.usage {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(details) { d in detailRow(d, total: total) }
                }
                .padding(.top, 2)
            }
        }
    }

    @ViewBuilder
    private func detailRow(_ d: UsageDetail, total: Double) -> some View {
        let v = d.usage ?? 0
        let frac = total > 0 ? min(1.0, v / total) : 0
        HStack(spacing: 6) {
            Text(d.modelCode ?? "?")
                .frame(width: 90, alignment: .leading)
            ZStack(alignment: .leading) {
                Capsule().fill(Color.gray.opacity(0.18))
                Capsule().fill(Color.accentColor.opacity(0.6))
                    .scaleEffect(x: frac, y: 1, anchor: .leading)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 6)
            Text(compactNumber(v)).frame(width: 46, alignment: .trailing)
        }
        .font(.caption2).foregroundStyle(.secondary)
    }
}

// MARK: - Settings

struct SettingsForm: View {
    @Environment(UsageModel.self) private var model
    @State private var keyInput = ""
    var onDone: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("z.ai API key").font(.subheadline).fontWeight(.medium)
            SecureField("paste your id.secret key", text: $keyInput)
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled()

            HStack {
                Button("Save & connect") {
                    model.setKey(keyInput)
                    keyInput = ""
                    onDone?()
                }
                .disabled(keyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Spacer()
                if model.keyIsSet {
                    Button("Remove key", role: .destructive) { model.clearKey() }
                }
            }
            Text("Stored in the macOS Keychain. Used only to call api.z.ai.")
                .font(.caption2).foregroundStyle(.secondary)
        }
    }
}

// MARK: - Peak hours

struct PeakHoursView: View {
    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { ctx in
            row(now: ctx.date)
        }
    }

    @ViewBuilder
    private func row(now: Date) -> some View {
        let peak = PeakHours.isPeak(at: now)
        let mult = PeakHours.advancedMultiplier(at: now)
        let promo = PeakHours.promoActive(at: now)
        let offPeak = promo ? 1 : 2
        let (start, end) = PeakHours.window(at: now)
        let tf = Date.FormatStyle.dateTime.hour().minute()

        HStack(alignment: .top, spacing: 8) {
            Image(systemName: peak ? "sun.max.fill" : "moon.stars.fill")
                .foregroundStyle(peak ? Color.orange : Color.indigo)
                .font(.callout)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 2) {
                Text("Peak hours \(start.formatted(tf))–\(end.formatted(tf)) (local)")
                    .font(.caption).fontWeight(.medium)
                Text(peak
                     ? "Now peak — GLM-5.2 / 5-Turbo tokens \(mult)×"
                     : "Now off-peak — GLM-5.2 / 5-Turbo tokens \(mult)×\(promo ? " (promo)" : "")")
                    .font(.caption2).foregroundStyle(.secondary)
                Text("3× in peak · \(offPeak)× off-peak · GLM-4.7 always 1× · 14:00–18:00 UTC+8")
                    .font(.caption2).foregroundStyle(.tertiary)
            }
        }
    }
}

// MARK: - About

struct AboutLine: View {
    @Environment(\.openURL) private var openURL

    var body: some View {
        HStack(spacing: 6) {
            Text("\(BuildInfo.name) v\(BuildInfo.version)")
            Text("·").foregroundStyle(.tertiary)
            Text(buildLabel)
            Spacer()
            if let url = BuildInfo.repoURL.flatMap(URL.init(string:)) {
                Button {
                    openURL(url)
                } label: {
                    Label("Source", systemImage: "arrow.up.right.square")
                }
                .buttonStyle(.borderless)
            }
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
    }

    private var buildLabel: String {
        if BuildInfo.commit == "dev" { return "dev build" }
        let date = BuildInfo.commitDate.isEmpty ? "" : " · \(BuildInfo.commitDate)"
        return "build \(BuildInfo.commit)\(date)"
    }
}

// MARK: - Menu bar label

struct MenuLabel: View {
    let pct: Double?
    let state: LoadState
    let hasKey: Bool

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "bolt.fill")
            if !hasKey {
                Text("z.ai")
            } else if case .error = state {
                Image(systemName: "exclamationmark.triangle.fill")
            } else if let p = pct {
                Text("\(Int(p.rounded()))%")
            } else if state == .loading {
                Image(systemName: "ellipsis")
            } else {
                Text("—")
            }
        }
        .foregroundColor(color)
    }

    private var color: Color {
        if case .error = state { return .orange }
        if let p = pct { return statusColor(forPercentage: p) }
        return .secondary
    }
}
