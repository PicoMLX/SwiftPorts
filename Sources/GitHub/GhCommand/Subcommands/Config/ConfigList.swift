import ArgumentParser
import Foundation
import GitHub

struct ConfigList: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: "Print every set config key and its value."
    )

    func run() async throws {
        let store = ConfigFileStore()
        let file = try store.read()
        if file.values.isEmpty {
            print("(no config set; \(store.path.path))")
            return
        }
        for key in file.values.keys.sorted() {
            if let value = file[key] {
                print("\(key)=\(value)")
            }
        }
    }
}
