// NodeManager.swift
import Foundation
import Combine
import SwiftUI
import Network   // NEW

struct Node: Identifiable, Codable {
    let id: UUID
    var name: String
    var host: String
    var lastBlock: Int?
    var lastPeerCount: Int?
    var isSyncing: Bool?
    var isLagging: Bool
    var consecutiveFailures: Int
    var lastStatusMessage: String?

    init(id: UUID = UUID(), name: String, host: String) {
        self.id = id
        self.name = name
        self.host = host
        self.lastBlock = nil
        self.lastPeerCount = nil
        self.isSyncing = nil
        self.isLagging = false
        self.consecutiveFailures = 0
        self.lastStatusMessage = nil
    }
}

@MainActor
class NodeManager: ObservableObject {
    static let shared = NodeManager()
    @Published var nodes: [Node] = []

    private let storageKey = "nodes_storage"

    // NEW — sauvegarde du dernier block milestone
    private let lastNotifiedBlockKey = "last_notified_block"
    private var lastNotifiedBlock: Int {
        get { UserDefaults.standard.integer(forKey: lastNotifiedBlockKey) }
        set { UserDefaults.standard.set(newValue, forKey: lastNotifiedBlockKey) }
    }

    private init() { load() }

    func addNode(name: String, host: String) {
        nodes.append(Node(name: name, host: host))
        save()
    }

    func remove(at offsets: IndexSet) {
        nodes.remove(atOffsets: offsets)
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(nodes) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let arr = try? JSONDecoder().decode([Node].self, from: data) {
            nodes = arr
        }
    }

    private func canRunChecks() -> Bool {
        if !NetworkMonitor.shared.isConnected {
            NotificationManager.shared.notify(
                title: "Internet indisponible",
                body: "Le monitoring des nœuds est temporairement arrêté."
            )
            return false
        }
        return true
    }

    func checkNodesOnce() async {

        guard canRunChecks() else { return }

        var newNodes = nodes
        var maxBlock = 0

        for i in newNodes.indices {
            let status = await NodeNetwork.fetchStatus(for: newNodes[i])
            if status.success {
                newNodes[i].lastBlock = status.lastBlock
                newNodes[i].lastPeerCount = status.peerCount
                newNodes[i].isSyncing = status.isSyncing
                newNodes[i].consecutiveFailures = 0

                if let b = status.lastBlock {
                    maxBlock = max(maxBlock, b)
                }
            } else {
                newNodes[i].consecutiveFailures += 1
            }
        }

        for i in newNodes.indices {
            if let blk = newNodes[i].lastBlock, maxBlock > 0 {
                let lag = maxBlock - blk
                newNodes[i].isLagging = lag > 20
            }
            if newNodes[i].consecutiveFailures >= 2 {
                NotificationManager.shared.notify(
                    title: "Node down",
                    body: "\(newNodes[i].name) unreachable twice"
                )
            }
            if newNodes[i].isLagging {
                NotificationManager.shared.notify(
                    title: "Node lagging",
                    body: "\(newNodes[i].name) is >20 blocks behind"
                )
            }
        }

        // --------------------------------------------------------------------------------
        // 🎉 NEW — Notif tous les 1000 blocks
        // --------------------------------------------------------------------------------
        if maxBlock > 0 {

            let currentMilestone = (maxBlock / 1000) * 1000

            if currentMilestone > lastNotifiedBlock {
                lastNotifiedBlock = currentMilestone

                NotificationManager.shared.notify(
                    title: "Blockchain milestone",
                    body: "Hey! Right now we are at block \(maxBlock)"
                )

                print("🚀 New 1000-block milestone reached: \(currentMilestone)")
            }
        }

        nodes = newNodes
        save()
    }

    func checkNodesInBackground(completion: @escaping ()->Void) {
        Task {
            await checkNodesOnce()
            completion()
        }
    }
}
