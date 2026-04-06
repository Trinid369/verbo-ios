// BackgroundTaskManager.swift
// Gerenciamento de tarefas em segundo plano — proactive monitoring, learning sync
// Trinid © 2026

import BackgroundTasks
import UserNotifications
import Foundation

// MARK: - Task Identifiers

enum VERBOTaskID {
    static let proactiveCheck = "com.trinid.verbo.proactive-check"
    static let profileSync    = "com.trinid.verbo.profile-sync"
    static let metricsRefresh = "com.trinid.verbo.metrics-refresh"
}

// MARK: - Background Task Manager

final class BackgroundTaskManager {
    static let shared = BackgroundTaskManager()
    private init() {}

    // MARK: Registration

    func registerTasks() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: VERBOTaskID.proactiveCheck,
            using: nil
        ) { task in
            self.handleProactiveCheck(task: task as! BGAppRefreshTask)
        }

        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: VERBOTaskID.profileSync,
            using: nil
        ) { task in
            self.handleProfileSync(task: task as! BGProcessingTask)
        }

        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: VERBOTaskID.metricsRefresh,
            using: nil
        ) { task in
            self.handleMetricsRefresh(task: task as! BGAppRefreshTask)
        }
    }

    // MARK: Scheduling

    func scheduleProactiveCheck() {
        let request = BGAppRefreshTaskRequest(identifier: VERBOTaskID.proactiveCheck)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // 15 min
        try? BGTaskScheduler.shared.submit(request)
    }

    func scheduleProfileSync() {
        let request = BGProcessingTaskRequest(identifier: VERBOTaskID.profileSync)
        request.requiresNetworkConnectivity = false
        request.requiresExternalPower       = false
        request.earliestBeginDate = Date(timeIntervalSinceNow: 60 * 60) // 1 hour
        try? BGTaskScheduler.shared.submit(request)
    }

    func scheduleMetricsRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: VERBOTaskID.metricsRefresh)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 30 * 60) // 30 min
        try? BGTaskScheduler.shared.submit(request)
    }

    // MARK: Handlers

    private func handleProactiveCheck(task: BGAppRefreshTask) {
        scheduleProactiveCheck() // Re-schedule immediately

        let worker = BGProactiveWorker.shared
        Task {
            await worker.runBackgroundCheck()
            task.setTaskCompleted(success: true)
        }

        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }
    }

    private func handleProfileSync(task: BGProcessingTask) {
        scheduleProfileSync()

        Task {
            UserMemoryStore.shared.compactProfile()
            task.setTaskCompleted(success: true)
        }

        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }
    }

    private func handleMetricsRefresh(task: BGAppRefreshTask) {
        scheduleMetricsRefresh()

        Task {
            await MarketMetricsCache.shared.refresh()
            task.setTaskCompleted(success: true)
        }

        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }
    }
}

// MARK: - Background Proactive Worker (separate from the foreground ProactiveMonitor)
// ProactiveMonitor (foreground, @MainActor) is defined in SpecialistAgents.swift
// BGProactiveWorker handles background-only work (UNNotifications, market alerts)

final class BGProactiveWorker {
    static let shared = BGProactiveWorker()
    private var timer: Timer?

    private init() {}

    func start() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            Task { await self?.runForegroundCheck() }
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    func stop() { timer?.invalidate(); timer = nil }

    private func runForegroundCheck() async {
        let hour = Calendar.current.component(.hour, from: Date())
        let min  = Calendar.current.component(.minute, from: Date())

        // Morning brief: 8:00–8:05
        if hour == 8 && min < 5 {
            await sendMorningBrief()
        }
        // Evening wrap: 20:00–20:05
        if hour == 20 && min < 5 {
            await sendEveningWrap()
        }
        // Market hours alert: 9:00, 14:00
        if (hour == 9 || hour == 14) && min < 5 {
            await checkMarketAlert()
        }
    }

    func runBackgroundCheck() async {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour >= 8 && hour <= 22 {
            await checkUrgentItems()
        }
    }

    // MARK: Proactive Actions

    private func sendMorningBrief() async {
        let content = UNMutableNotificationContent()
        content.title = "☀️ Bom dia, VERBO aqui"
        content.body  = "Toque para ver seu resumo matinal: mercado, agenda e prioridades do dia."
        content.sound = .default
        content.userInfo = ["action": "morning_brief"]
        await scheduleNotification(content, id: "morning_\(dayString())")
    }

    private func sendEveningWrap() async {
        let content = UNMutableNotificationContent()
        content.title = "🌙 Resumo do dia"
        content.body  = "Como foi seu dia? Toque para ver o wrap-up: tarefas, mercado e amanhã."
        content.sound = .default
        content.userInfo = ["action": "evening_wrap"]
        await scheduleNotification(content, id: "evening_\(dayString())")
    }

    private func checkMarketAlert() async {
        // Check if any watched asset has significant move
        let cache = await MarketMetricsCache.shared.latestData
        guard let btcChange = cache["btc_change_24h"] as? Double,
              abs(btcChange) > 5.0 else { return }

        let dir    = btcChange > 0 ? "📈" : "📉"
        let pct    = String(format: "%.1f%%", abs(btcChange))
        let content = UNMutableNotificationContent()
        content.title = "\(dir) Alerta de Mercado"
        content.body  = "BTC \(btcChange > 0 ? "subiu" : "caiu") \(pct) nas últimas 24h"
        content.sound = .default
        await scheduleNotification(content, id: "market_\(hourString())")
    }

    private func checkUrgentItems() async {
        // Placeholder: in production, check calendar for upcoming meetings
        let now      = Date()
        let calendar = Calendar.current
        // If 15 min before an hour boundary, send prep alert
        let min      = calendar.component(.minute, from: now)
        guard min >= 45 else { return }
        // Could integrate with CalendarAgent to check real events
    }

    // MARK: Helpers

    private func scheduleNotification(_ content: UNMutableNotificationContent, id: String) async {
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        try? await UNUserNotificationCenter.current().add(request)
    }

    private func dayString() -> String {
        let f = DateFormatter(); f.dateFormat = "yyyyMMdd"; return f.string(from: Date())
    }
    private func hourString() -> String {
        let f = DateFormatter(); f.dateFormat = "yyyyMMddHH"; return f.string(from: Date())
    }
}

// MARK: - Market Metrics Cache

actor MarketMetricsCache {
    static let shared = MarketMetricsCache()
    private(set) var latestData: [String: Any] = [:]
    private var lastRefresh: Date = .distantPast

    func refresh() async {
        guard Date().timeIntervalSince(lastRefresh) > 300 else { return }
        // In production: fetch from Binance/AGREX APIs
        // Using static mock for now
        latestData = [
            "btc_price":     65_420.0,
            "btc_change_24h": 2.3,
            "eth_price":      3_102.0,
            "eth_change_24h": -1.1,
            "soy_price":      148.5,
            "usd_brl":         5.12
        ]
        lastRefresh = Date()
    }
}

// MARK: - UserMemoryStore extension for background

extension UserMemoryStore {
    func compactProfile() {
        // Keep top 50 interests, top 20 contacts, top 20 agents
        if profile.interests.count > 50 {
            profile.interests = Array(profile.interests.prefix(50))
        }
        if profile.contacts.count > 20 {
            let trimmed = profile.contacts.prefix(20)
            profile.contacts = Dictionary(uniqueKeysWithValues: trimmed)
        }
        save()
    }
}
