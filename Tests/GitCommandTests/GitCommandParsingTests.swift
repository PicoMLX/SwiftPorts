import Foundation
import Testing
import ArgumentParser
@testable import GitCommand

@Suite("GitCommand argv parsing")
struct GitCommandParsingTests {

    /// Resolve a subcommand from `["git", ...]` and return the parsed
    /// instance for assertion. Mirrors how ArgumentParser would dispatch
    /// at runtime.
    private func parse<T: ParsableCommand>(_ argv: [String], as type: T.Type) throws -> T {
        let parsed = try GitCommand.parseAsRoot(argv)
        let cmd = try #require(parsed as? T)
        return cmd
    }

    @Test("clone: URL only")
    func cloneURLOnly() throws {
        let cmd = try parse(["clone", "https://github.com/o/r.git"], as: Clone.self)
        #expect(cmd.url == "https://github.com/o/r.git")
        #expect(cmd.directory == nil)
    }

    @Test("clone: URL + directory")
    func cloneWithDirectory() throws {
        let cmd = try parse(
            ["clone", "https://github.com/o/r.git", "/tmp/r"], as: Clone.self)
        #expect(cmd.url == "https://github.com/o/r.git")
        #expect(cmd.directory == "/tmp/r")
    }

    @Test("fetch: defaults to origin")
    func fetchDefaultRemote() throws {
        let cmd = try parse(["fetch", "main"], as: Fetch.self)
        #expect(cmd.remote == "origin")
        #expect(cmd.refspec == "main")
    }

    @Test("fetch: --remote overrides default")
    func fetchExplicit() throws {
        let cmd = try parse(["fetch", "--remote", "upstream", "main"], as: Fetch.self)
        #expect(cmd.remote == "upstream")
        #expect(cmd.refspec == "main")
    }

    @Test("checkout: ref")
    func checkout() throws {
        let cmd = try parse(["checkout", "feature/x"], as: Checkout.self)
        #expect(cmd.ref == "feature/x")
    }

    @Test("push: bare refspec defaults to origin")
    func pushDefault() throws {
        let cmd = try parse(["push", "main"], as: Push.self)
        #expect(cmd.remote == "origin")
        #expect(cmd.refspec == "main")
        #expect(cmd.setUpstream == false)
    }

    @Test("push: -u sets upstream flag")
    func pushSetUpstreamShort() throws {
        let cmd = try parse(["push", "-u", "main"], as: Push.self)
        #expect(cmd.setUpstream == true)
        #expect(cmd.remote == "origin")
        #expect(cmd.refspec == "main")
    }

    @Test("push: --set-upstream + --remote long form")
    func pushSetUpstreamLong() throws {
        let cmd = try parse(
            ["push", "--set-upstream", "--remote", "upstream", "main"], as: Push.self)
        #expect(cmd.setUpstream == true)
        #expect(cmd.remote == "upstream")
        #expect(cmd.refspec == "main")
    }

    @Test("remote add: name + URL")
    func remoteAdd() throws {
        let cmd = try parse(
            ["remote", "add", "origin", "https://github.com/o/r.git"], as: RemoteAdd.self)
        #expect(cmd.name == "origin")
        #expect(cmd.url == "https://github.com/o/r.git")
    }

    @Test("remote get-url: name")
    func remoteGetURL() throws {
        let cmd = try parse(["remote", "get-url", "origin"], as: RemoteGetURL.self)
        #expect(cmd.name == "origin")
    }

    @Test("branch: --upstream")
    func branchUpstream() throws {
        let cmd = try parse(["branch", "--upstream", "main"], as: Branch.self)
        #expect(cmd.upstream == "main")
    }

    @Test("branch: --show-current")
    func branchShowCurrent() throws {
        let cmd = try parse(["branch", "--show-current"], as: Branch.self)
        #expect(cmd.showCurrent == true)
    }

    @Test("version: parses to VersionCommand")
    func version() throws {
        _ = try parse(["version"], as: VersionCommand.self)
    }

    @Test("commit: -m message")
    func commitMessage() throws {
        let cmd = try parse(["commit", "-m", "init"], as: Commit.self)
        #expect(cmd.message == "init")
        #expect(cmd.author == nil)
        #expect(cmd.allowEmpty == false)
    }

    @Test("commit: --message + --allow-empty")
    func commitAllowEmpty() throws {
        let cmd = try parse(
            ["commit", "--message", "stub", "--allow-empty"], as: Commit.self)
        #expect(cmd.message == "stub")
        #expect(cmd.allowEmpty == true)
    }

    @Test("commit: --author parses Name <email>")
    func commitAuthor() throws {
        let cmd = try parse(
            ["commit", "-m", "x", "--author", "Jane Doe <jane@example.com>"],
            as: Commit.self)
        let parsed = try Commit.parseAuthor(cmd.author ?? "")
        #expect(parsed.name == "Jane Doe")
        #expect(parsed.email == "jane@example.com")
    }

    @Test("commit: malformed --author rejected")
    func commitAuthorMalformed() {
        #expect(throws: (any Error).self) {
            _ = try Commit.parseAuthor("Jane Doe jane@example.com")
        }
    }

    @Test("add: -A stages everything")
    func addAll() throws {
        let cmd = try parse(["add", "-A"], as: Add.self)
        #expect(cmd.all == true)
        #expect(cmd.paths.isEmpty)
    }

    @Test("add: explicit paths")
    func addPaths() throws {
        let cmd = try parse(["add", "a.txt", "b.txt"], as: Add.self)
        #expect(cmd.all == false)
        #expect(cmd.force == false)
        #expect(cmd.paths == ["a.txt", "b.txt"])
    }

    @Test("add: -f sets force flag")
    func addForce() throws {
        let cmd = try parse(["add", "-f", "ignored.log"], as: Add.self)
        #expect(cmd.force == true)
        #expect(cmd.paths == ["ignored.log"])
    }

    @Test("add: bare invocation rejected at parse time")
    func addBareRejected() {
        #expect(throws: (any Error).self) {
            _ = try GitCommand.parseAsRoot(["add"])
        }
    }

    @Test("add: -A with paths rejected at parse time")
    func addAllWithPathsRejected() {
        #expect(throws: (any Error).self) {
            _ = try GitCommand.parseAsRoot(["add", "-A", "a.txt"])
        }
    }

    @Test("stash push: -m message + flags")
    func stashPushMessage() throws {
        let cmd = try parse(
            ["stash", "push", "-m", "wip", "-u", "--keep-index"], as: StashPush.self)
        #expect(cmd.message == "wip")
        #expect(cmd.includeUntracked == true)
        #expect(cmd.keepIndex == true)
        #expect(cmd.all == false)
    }

    @Test("stash defaults to push subcommand")
    func stashDefaultIsPush() throws {
        let cmd = try parse(["stash"], as: StashPush.self)
        #expect(cmd.message == nil)
        #expect(cmd.includeUntracked == false)
    }

    @Test("stash apply with index")
    func stashApplyIndexed() throws {
        let cmd = try parse(["stash", "apply", "stash@{2}"], as: StashApply.self)
        #expect(cmd.stash == "stash@{2}")
        let parsed = try parseStashIndex(cmd.stash)
        #expect(parsed == 2)
    }

    @Test("stash pop --index reinstates index")
    func stashPopIndex() throws {
        let cmd = try parse(["stash", "pop", "--index", "1"], as: StashPop.self)
        #expect(cmd.reinstateIndex == true)
        #expect(cmd.stash == "1")
        #expect(try parseStashIndex(cmd.stash) == 1)
    }

    @Test("stash branch: name + reference")
    func stashBranchParse() throws {
        let cmd = try parse(
            ["stash", "branch", "feature/wip", "stash@{0}"], as: StashBranch.self)
        #expect(cmd.name == "feature/wip")
        #expect(cmd.stash == "stash@{0}")
    }

    @Test("stash drop without arg defaults to 0")
    func stashDropDefault() throws {
        let cmd = try parse(["stash", "drop"], as: StashDrop.self)
        #expect(cmd.stash == nil)
        #expect(try parseStashIndex(cmd.stash) == 0)
    }

    @Test("invalid stash reference rejected")
    func stashIndexInvalid() {
        #expect(throws: (any Error).self) {
            _ = try parseStashIndex("stash@{abc}")
        }
        #expect(throws: (any Error).self) {
            _ = try parseStashIndex("garbage")
        }
    }

    @Test("diff: bare invocation parses cleanly")
    func diffBare() throws {
        let cmd = try parse(["diff"], as: Diff.self)
        #expect(cmd.cached == false)
        #expect(cmd.stat == false)
        #expect(cmd.rest.isEmpty)
    }

    @Test("diff: --cached")
    func diffCached() throws {
        let cmd = try parse(["diff", "--cached"], as: Diff.self)
        #expect(cmd.cached == true)
    }

    @Test("diff: --staged is an alias for --cached")
    func diffStaged() throws {
        let cmd = try parse(["diff", "--staged"], as: Diff.self)
        #expect(cmd.cached == true)
    }

    @Test("diff: --stat")
    func diffStat() throws {
        let cmd = try parse(["diff", "--stat"], as: Diff.self)
        #expect(cmd.stat == true)
    }

    @Test("diff: --name-only / --name-status")
    func diffNameForms() throws {
        let only = try parse(["diff", "--name-only"], as: Diff.self)
        #expect(only.nameOnly == true)
        let status = try parse(["diff", "--name-status"], as: Diff.self)
        #expect(status.nameStatus == true)
    }

    @Test("diff: positional refs collected in rest")
    func diffPositionalRefs() throws {
        let cmd = try parse(["diff", "HEAD~1", "HEAD"], as: Diff.self)
        let split = try Diff.split(cmd.rest)
        #expect(split.refs == ["HEAD~1", "HEAD"])
        #expect(split.paths.isEmpty)
    }

    @Test("diff: -- splits refs from paths")
    func diffPathSeparator() throws {
        let cmd = try parse(["diff", "main", "--", "a.txt", "b.txt"], as: Diff.self)
        let split = try Diff.split(cmd.rest)
        #expect(split.refs == ["main"])
        #expect(split.paths == ["a.txt", "b.txt"])
    }

    @Test("diff: --shortstat / --numstat / --raw / -p flags")
    func diffNewFormatFlags() throws {
        #expect(try parse(["diff", "--shortstat"], as: Diff.self).shortStat == true)
        #expect(try parse(["diff", "--numstat"], as: Diff.self).numStat == true)
        #expect(try parse(["diff", "--raw"], as: Diff.self).raw == true)
        #expect(try parse(["diff", "-p"], as: Diff.self).patch == true)
    }

    @Test("diff: --unified / -U <n>")
    func diffUnifiedFlag() throws {
        let long = try parse(["diff", "--unified", "5"], as: Diff.self)
        #expect(long.unified == 5)
        let short = try parse(["diff", "-U", "0"], as: Diff.self)
        #expect(short.unified == 0)
    }

    @Test("diff: a..b expands to two refs (asymmetric)")
    func diffRangeAsymmetric() throws {
        let (refs, sym) = try Diff.expandRanges(["HEAD~1..HEAD"])
        #expect(refs == ["HEAD~1", "HEAD"])
        #expect(sym == false)
    }

    @Test("diff: a...b expands to two refs (symmetric)")
    func diffRangeSymmetric() throws {
        let (refs, sym) = try Diff.expandRanges(["main...feature"])
        #expect(refs == ["main", "feature"])
        #expect(sym == true)
    }

    @Test("diff: invalid range rejected")
    func diffRangeInvalid() {
        #expect(throws: (any Error).self) {
            _ = try Diff.expandRanges(["..HEAD"])
        }
        #expect(throws: (any Error).self) {
            _ = try Diff.expandRanges(["HEAD.."])
        }
    }

    @Test("diff: multiple ranges rejected")
    func diffMultipleRanges() {
        #expect(throws: (any Error).self) {
            _ = try Diff.expandRanges(["a..b", "c..d"])
        }
    }

    @Test("merge: ref + --no-ff")
    func mergeNoFF() throws {
        let cmd = try parse(["merge", "--no-ff", "feature"], as: Merge.self)
        #expect(cmd.noFF == true)
        #expect(cmd.ref == "feature")
    }

    @Test("merge: --ff-only")
    func mergeFFOnly() throws {
        let cmd = try parse(["merge", "--ff-only", "feature"], as: Merge.self)
        #expect(cmd.ffOnly == true)
    }

    @Test("merge: rejects multiple ff modes")
    func mergeFFModesExclusive() {
        #expect(throws: (any Error).self) {
            _ = try GitCommand.parseAsRoot(["merge", "--no-ff", "--ff-only", "feature"])
        }
    }

    @Test("pull: defaults remote to origin")
    func pullDefaults() throws {
        let cmd = try parse(["pull"], as: Pull.self)
        #expect(cmd.remote == "origin")
        #expect(cmd.branch == nil)
    }

    @Test("pull: explicit remote + branch")
    func pullExplicit() throws {
        let cmd = try parse(["pull", "upstream", "main"], as: Pull.self)
        #expect(cmd.remote == "upstream")
        #expect(cmd.branch == "main")
    }

    @Test("pull: --no-ff carried through")
    func pullNoFF() throws {
        let cmd = try parse(["pull", "--no-ff"], as: Pull.self)
        #expect(cmd.noFF == true)
    }

    @Test("rebase: <upstream>")
    func rebaseUpstream() throws {
        let cmd = try parse(["rebase", "main"], as: Rebase.self)
        #expect(cmd.upstream == "main")
        #expect(cmd.continueRebase == false)
        #expect(cmd.abort == false)
    }

    @Test("rebase: --onto NEWBASE upstream")
    func rebaseOnto() throws {
        let cmd = try parse(
            ["rebase", "--onto", "main", "feature~3"], as: Rebase.self)
        #expect(cmd.onto == "main")
        #expect(cmd.upstream == "feature~3")
    }

    @Test("rebase: --continue")
    func rebaseContinue() throws {
        let cmd = try parse(["rebase", "--continue"], as: Rebase.self)
        #expect(cmd.continueRebase == true)
    }

    @Test("rebase: --abort")
    func rebaseAbort() throws {
        let cmd = try parse(["rebase", "--abort"], as: Rebase.self)
        #expect(cmd.abort == true)
    }

    @Test("rebase: --continue and --abort mutually exclusive")
    func rebaseContinueAbortExclusive() {
        #expect(throws: (any Error).self) {
            _ = try GitCommand.parseAsRoot(["rebase", "--continue", "--abort"])
        }
    }

    @Test("rebase: bare invocation rejected (needs upstream)")
    func rebaseBareRejected() {
        #expect(throws: (any Error).self) {
            _ = try GitCommand.parseAsRoot(["rebase"])
        }
    }

    @Test("rebase: --abort + upstream rejected")
    func rebaseAbortWithUpstream() {
        #expect(throws: (any Error).self) {
            _ = try GitCommand.parseAsRoot(["rebase", "--abort", "main"])
        }
    }

    @Test("rebase: --skip")
    func rebaseSkip() throws {
        let cmd = try parse(["rebase", "--skip"], as: Rebase.self)
        #expect(cmd.skip == true)
        #expect(cmd.continueRebase == false)
        #expect(cmd.abort == false)
    }

    @Test("rebase: --skip + --continue mutually exclusive")
    func rebaseSkipContinueExclusive() {
        #expect(throws: (any Error).self) {
            _ = try GitCommand.parseAsRoot(["rebase", "--skip", "--continue"])
        }
    }

    @Test("pull: --rebase")
    func pullRebase() throws {
        let cmd = try parse(["pull", "--rebase"], as: Pull.self)
        #expect(cmd.rebase == true)
    }

    @Test("pull: -r short form for --rebase")
    func pullRebaseShort() throws {
        let cmd = try parse(["pull", "-r"], as: Pull.self)
        #expect(cmd.rebase == true)
    }

    @Test("pull: --rebase + --no-ff rejected")
    func pullRebaseFFExclusive() {
        #expect(throws: (any Error).self) {
            _ = try GitCommand.parseAsRoot(["pull", "--rebase", "--no-ff"])
        }
    }

    @Test("missing subcommand exits non-zero")
    func missingSubcommandFails() {
        #expect(throws: (any Error).self) {
            _ = try GitCommand.parseAsRoot(["bogus"])
        }
    }
}
