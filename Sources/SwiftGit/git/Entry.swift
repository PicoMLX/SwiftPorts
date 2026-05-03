import Foundation
import ArgumentParser
import GitCommand

@main
struct Entry {
    static func main() async {
        do {
            // Real git accepts attached short-option-with-value forms
            // like `-U3` (= `-U 3`). ArgumentParser doesn't support
            // those for typed options, so split them out before parsing.
            let argv = Self.preprocess(Array(CommandLine.arguments.dropFirst()))
            var cmd = try GitCommand.parseAsRoot(argv)
            if var asyncCmd = cmd as? any AsyncParsableCommand {
                try await asyncCmd.run()
            } else {
                try cmd.run()
            }
        } catch let cli as CLIError {
            cli.emitAndExit()
        } catch {
            // Hand off to ArgumentParser's default formatter for usage
            // errors / validation failures; preserves help output etc.
            GitCommand.exit(withError: error)
        }
    }

    /// Split git's attached short-option-with-value forms into separate
    /// tokens so ArgumentParser can parse them. Today: `-U<n>` →
    /// `-U <n>`. Add more shorts here if needed.
    static func preprocess(_ args: [String]) -> [String] {
        var out: [String] = []
        out.reserveCapacity(args.count)
        for arg in args {
            if arg.count > 2, arg.hasPrefix("-U"),
               arg.dropFirst(2).allSatisfy(\.isNumber) {
                out.append("-U")
                out.append(String(arg.dropFirst(2)))
            } else {
                out.append(arg)
            }
        }
        return out
    }
}
