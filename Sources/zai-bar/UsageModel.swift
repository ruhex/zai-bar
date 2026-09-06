import Foundation
import SwiftUI
import AppKit
import os

private let log = Logger(subsystem: "com.github.ruhex.zai-bar", category: "refresh")

enum LoadState: Equatable {
    case idle
    case loading
    case loaded
    case error(String)
}

@MainActor
@Observable
final class UsageModel {
    var limits: [Limit] = []
    var level: String?
    var state: LoadState = .idle
    var lastUpdated: Date?
    var keyIsSet: Bool = false

    private var autoRefreshTask: Task<Void, Never>?
    /// Keeps App Nap from suspending the 5-minute refresh timer while the
    /// windowless app sits in the background.
    private var napActivity: NSObjectProtocol?
    private var wakeObserver: NSObjectProtocol?
    /// In-flight quota fetch. A newer request (key change, wake, popover open)
    /// cancels it so a stale response can never overwrite current state.
    private var fetchTask: Task<Void, Never>?

    init() {
        keyIsSet = Keychain.shared.load() != nil
        napActivity = ProcessInfo.processInfo.beginActivity(
            options: .userInitiatedAllowingIdleSystemSleep,
            reason: "zai-bar periodic quota refresh")
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in await self?.refresh() }
        }
        Task { @MainActor [weak self] in
            guard let self else { return }
            await self.refresh()
            self.startAutoRefresh()
        }
    }

    // MARK: Key management

    func setKey(_ raw: String) {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard Keychain.shared.save(trimmed) else {
            state = .error("Keychain write failed")
            return
        }
        keyIsSet = true
        // Don't show the previous key's quota while the new one loads.
        limits = []
        level = nil
        lastUpdated = nil
        state = .loading
        Task { await refresh() }
    }

    func clearKey() {
        fetchTask?.cancel()
        fetchTask = nil
        Keychain.shared.delete()
        keyIsSet = false
        limits = []
        level = nil
        lastUpdated = nil
        state = .idle
    }

    // MARK: Fetching

    /// Fetches fresh quota, replacing any in-flight fetch.
    func refresh() async {
        fetchTask?.cancel()
        if let t = fetchTask { await t.value }
        let task = Task { @MainActor in await self.refreshOnce() }
        fetchTask = task
        await task.value
    }

    private func refreshOnce() async {
        guard let key = Keychain.shared.load() else {
            keyIsSet = false
            state = .error("No API key set.")
            return
        }
        if limits.isEmpty { state = .loading }
        do {
            let r = try await ZAIClient.shared.quotaLimit(apiKey: key)
            guard !Task.isCancelled else { return }
            // 5h tokens → weekly tokens → web tools (see Limit.displayOrder).
            self.limits = (r.data?.limits ?? []).sorted { $0.displayOrder < $1.displayOrder }
            self.level = r.data?.level
            self.lastUpdated = Date()
            self.state = .loaded
            log.info("refresh ok: \(self.limits.count) limits, 5h pct=\(self.headlinePercentage ?? -1)")
        } catch is CancellationError {
            // Fetch was superseded (key change / newer refresh): keep current state.
        } catch let e as URLError where e.code == .cancelled {
            // Same — URLSession surfaces cancellation as URLError.
        } catch let e as ZAIError {
            guard !Task.isCancelled else { return }
            log.error("refresh failed: \(e.errorDescription ?? "?", privacy: .public)")
            self.state = .error(e.errorDescription ?? "error")
        } catch {
            guard !Task.isCancelled else { return }
            log.error("refresh failed: \(error.localizedDescription, privacy: .public)")
            self.state = .error(error.localizedDescription)
        }
    }

    func startAutoRefresh() {
        autoRefreshTask?.cancel()
        autoRefreshTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(300))
                if Task.isCancelled { break }
                await self?.refresh()
            }
        }
    }

    /// What the tray shows: the **5-hour token window** % — the resource that
    /// depletes fastest while coding, so it's the most actionable number at a
    /// glance. Falls back to the weekly token window, then to any token window.
    var headlinePercentage: Double? {
        let tokens = limits.filter { $0.type == "TOKENS_LIMIT" }
        if let p = tokens.first(where: { $0.unit == 3 })?.percentage { return p } // 5h
        if let p = tokens.first(where: { $0.unit == 6 })?.percentage { return p } // weekly
        return tokens.compactMap { $0.percentage }.max()
    }
}
