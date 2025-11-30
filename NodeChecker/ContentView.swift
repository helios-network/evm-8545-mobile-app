
// ContentView.swift
import SwiftUI
import Combine   // ← obligatoire pour Timer.publish + autoconnect

struct ContentView: View {
    @StateObject var mgr = NodeManager.shared
    @State var showAdd = false
    @State var name=""
    @State var host=""
    @State var timer = Timer.publish(every:60,on:.main,in:.common).autoconnect()

    var body: some View {
        NavigationView {
            List {
                ForEach(mgr.nodes) { n in NodeRow(node:n) }
                    .onDelete(perform: mgr.remove)
            }
            .navigationTitle("Nodes").toolbar {
                Button {
                    showAdd = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .onAppear {
            Task{ await mgr.checkNodesOnce() }
        }
        .onReceive(timer) { _ in Task{ await mgr.checkNodesOnce() } }
        .sheet(isPresented:$showAdd) {
            Form {
                TextField("Name",text:$name)
                TextField("Host",text:$host)
                Button("Add") {
                    mgr.addNode(name:name.isEmpty ? host : name, host:host)
                    name="";host="";showAdd=false
                }
            }
        }
    }
}

struct NodeRow: View {
    let node: Node
    var body: some View {
        VStack(alignment:.leading) {
            Text(node.name).font(.headline)
            Text(node.host).font(.subheadline)
            if let b=node.lastBlock { Text("Block: \(b)") }
        }
    }
}
