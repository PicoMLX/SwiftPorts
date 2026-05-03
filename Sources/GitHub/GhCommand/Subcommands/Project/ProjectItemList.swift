import ArgumentParser
import Foundation
import GitHub

struct ProjectItemList: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "item-list",
        abstract: "List items in a ProjectV2 project."
    )

    @Argument(help: "Project number.")
    var number: Int

    @Option(name: [.customShort("o"), .customLong("owner")],
            help: "User or organization login. Omit for your own.")
    var owner: String?

    @Flag(name: [.long, .customLong("org")],
          help: "Treat OWNER as an organization (otherwise tries user).")
    var asOrg: Bool = false

    @Option(name: [.short, .customLong("limit")],
            help: "Maximum items to fetch.")
    var limit: Int = 30

    @Flag(name: .long, help: "Print as JSON array.")
    var json: Bool = false

    func run() async throws {
        let client = try await CommandContext.graphQLClient()
        let connection: ProjectV2ItemConnection

        if let owner {
            if asOrg {
                let response: OrgProjectItemsResponse = try await client.query(
                    ProjectQueries.orgProjectItems,
                    variables: ["login": .string(owner),
                                "number": .int(number),
                                "first": .int(min(limit, 100))])
                guard let p = response.organization?.projectV2 else {
                    throw ValidationError(
                        "No project #\(number) on org '\(owner)'.")
                }
                connection = p.items
            } else {
                let response: UserProjectItemsResponse = try await client.query(
                    ProjectQueries.userProjectItems,
                    variables: ["login": .string(owner),
                                "number": .int(number),
                                "first": .int(min(limit, 100))])
                guard let p = response.user?.projectV2 else {
                    throw ValidationError(
                        "No project #\(number) on user '\(owner)'.")
                }
                connection = p.items
            }
        } else {
            let response: ViewerProjectItemsResponse = try await client.query(
                ProjectQueries.viewerProjectItems,
                variables: ["number": .int(number),
                            "first": .int(min(limit, 100))])
            guard let p = response.viewer.projectV2 else {
                throw ValidationError("No project #\(number) for current user.")
            }
            connection = p.items
        }

        let trimmed = Array(connection.nodes.prefix(limit))
        if json {
            print(try CodableOutput.prettyJSON(trimmed))
            return
        }
        if trimmed.isEmpty {
            print("No items.")
            return
        }
        print("Showing \(trimmed.count) of \(connection.totalCount) items.")
        for item in trimmed {
            let summary = describe(item)
            print("\(item.type.rawValue)\t\(summary)")
        }
    }

    private func describe(_ item: ProjectV2Item) -> String {
        switch item.content {
        case .issue(let i): return "#\(i.number) \(i.state) \(i.title)"
        case .pullRequest(let p): return "#\(p.number) \(p.state) \(p.title)"
        case .draftIssue(let d): return "(draft) \(d.title)"
        case .unknown, nil: return "(redacted or unknown)"
        }
    }
}
