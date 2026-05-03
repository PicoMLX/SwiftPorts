import ArgumentParser
import GitHub

extension RepositoryReference: ExpressibleByArgument {
    public init?(argument: String) {
        do {
            try self.init(parsing: argument)
        } catch {
            return nil
        }
    }
}
