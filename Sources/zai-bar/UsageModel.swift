import Foundation
import SwiftUI

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

    private var refreshTask: Task<Void, Never>?

    init() {
        keyIsSet = Keychain.shared.load() != nil
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
        Keychain.shared.save(trimmed)
        keyIsSet = true
        Task { await refresh() }
    }

    func clearKey() {
        Keychain.shared.delete()
        keyIsSet = false
        limits = []
        level = nil
        lastUpdated = nil
        state = .idle
    }

    // MARK: Fetching

    func refresh() async {
        guard let key = Keychain.shared.load() else {
            keyIsSet = false
            state = .error("No API key set.")
            return
        }
        if limits.isEmpty { state = .loading }
        do {
            let r = try await ZAIClient.shared.quotaLimit(apiKey: key)
            // 5h tokens → weekly tokens → web tools (see Limit.displayOrder).
            self.limits = (r.data?.limits ?? []).sorted { $0.displayOrder < $1.displayOrder }
            self.level = r.data?.level
            self.lastUpdated = Date()
            self.state = .loaded
        } catch let e as ZAIError {
            self.state = .error(e.errorDescription ?? "error")
        } catch {
            self.state = .error(error.localizedDescription)
        }
    }

    func startAutoRefresh() {
        refreshTask?.cancel()
        refreshTask = Task { @MainActor [weak self] in
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
