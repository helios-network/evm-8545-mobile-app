
// NodeNetwork.swift
import Foundation

struct NodeStatusResult {
    let success: Bool
    let lastBlock: Int?
    let peerCount: Int?
    let isSyncing: Bool?
}

enum NodeNetwork {
    static func fetchStatus(for node: Node) async -> NodeStatusResult {
        guard let url = URL(string: "http://\(node.host):8545") else {
            return NodeStatusResult(success:false,lastBlock:nil,peerCount:nil,isSyncing:nil)
        }
        do {
            let peer = try await sendRpc("net_peerCount", url)
            let block = try await sendRpc("eth_blockNumber", url)
            let sync = try await sendRpc("eth_syncing", url)

            let pc = hexToInt(peer as? String)
            let bn = hexToInt(block as? String)
            let isSync: Bool? = (sync as? Bool) ?? (sync != nil ? true : nil)

            return NodeStatusResult(success:true,lastBlock:bn,peerCount:pc,isSyncing:isSync)
        } catch {
            return NodeStatusResult(success:false,lastBlock:nil,peerCount:nil,isSyncing:nil)
        }
    }

    static func sendRpc(_ method: String,_ url: URL) async throws -> Any? {
        var req = URLRequest(url:url)
        req.httpMethod="POST"
        req.addValue("application/json", forHTTPHeaderField:"Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject:[
            "jsonrpc":"2.0","method":method,"params":[],"id":1
        ])
        let (d,r) = try await URLSession.shared.data(for:req)
        guard let h = r as? HTTPURLResponse, h.statusCode==200 else { throw URLError(.badServerResponse) }
        let json = try JSONSerialization.jsonObject(with: d, options: [])
        guard let dict = json as? [String: Any] else {
            return nil
        }
        return dict["result"]
    }

    static func hexToInt(_ hex:String?) -> Int? {
        guard var h = hex else { return nil }
        if h.hasPrefix("0x") { h = String(h.dropFirst(2)) }
        return Int(h, radix:16)
    }
}
