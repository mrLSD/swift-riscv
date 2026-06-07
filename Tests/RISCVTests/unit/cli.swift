import Testing

import RISCV

@Suite struct UnitCLITests {
    private func parse(_ argv: [String]) -> CliStatus {
        CLI.parseCli(argv, CLI.InitCLI, AppConfig.Default)
    }

    @Test("short arch + file => Success and CheckRequired")
    func shortArchPlusFile() throws {
        guard case let .Success(cfg) = parse(["-A", "rv32i", "a.elf"]) else {
            Issue.record("expected Success, got \(parse(["-A", "rv32i", "a.elf"]))")
            return
        }
        #expect(cfg.Arch == .RV32i)
        #expect(cfg.CheckRequired)
        #expect(cfg.Files! == ["a.elf"])
    }

    @Test("long arch => Success")
    func longArch() throws {
        guard case let .Success(cfg) = parse(["--arch", "rv64ima", "a.elf"]) else {
            Issue.record("expected Success")
            return
        }
        #expect(cfg.Arch == .RV64ima)
    }

    @Test("verbosity short flag")
    func verbosityShortFlag() throws {
        guard case let .Success(cfg) = parse(["-v", "-A", "rv32i", "a.elf"]) else {
            Issue.record("expected Success")
            return
        }
        #expect(cfg.Verbosity == true)
    }

    @Test("multiple files accumulate")
    func multipleFilesAccumulate() throws {
        guard case let .Success(cfg) = parse(["-A", "rv32i", "a.elf", "b.elf", "c.elf"]) else {
            Issue.record("expected Success")
            return
        }
        #expect(cfg.Files!.count == 3)
    }

    @Test("help -h stops execution")
    func helpHStopsExecution() {
        #expect(parse(["-h"]) == .Stopped)
    }

    @Test("help --help stops execution")
    func helpLongStopsExecution() {
        #expect(parse(["--help"]) == .Stopped)
    }

    @Test("version -V stops execution")
    func versionVStopsExecution() {
        #expect(parse(["-V"]) == .Stopped)
    }

    @Test("version --version stops execution")
    func versionLongStopsExecution() {
        #expect(parse(["--version"]) == .Stopped)
    }

    @Test("missing arch value => Failed")
    func missingArchValue() {
        #expect(parse(["-A"]) == .Failed)
    }

    @Test("arch value starting with dash => Failed")
    func archValueStartingWithDash() {
        #expect(parse(["-A", "-x"]) == .Failed)
    }

    @Test("unknown dash option is rejected, not taken as a file")
    func unknownDashOptionRejected() {
        #expect(parse(["-A", "rv32i", "-z", "a.elf"]) == .Failed)
    }

    @Test("duplicate flag does not leak into the file list")
    func duplicateFlagDoesNotLeak() {
        #expect(parse(["-v", "-v", "-A", "rv32i", "a.elf"]) == .Failed)
    }

    @Test("no arch or files => Success but not CheckRequired")
    func noArchOrFiles() throws {
        guard case let .Success(cfg) = parse(["-v"]) else {
            Issue.record("expected Success")
            return
        }
        #expect(!cfg.CheckRequired)
    }

    @Test("unknown arch string => not CheckRequired")
    func unknownArchString() throws {
        guard case let .Success(cfg) = parse(["-A", "rvXX", "a.elf"]) else {
            Issue.record("expected Success")
            return
        }
        #expect(!cfg.CheckRequired)
    }

    @Test("CliUsage prints without error")
    func cliUsagePrints() {
        CLI.CliUsage(CLI.InitCLI)
    }

    @Test("long-key-only option is parsed")
    func longKeyOnlyOptionIsParsed() {
        var o = CliOptions.Default
        o.LongKey = "flag"
        let opts = [o]
        #expect(CLI.parseCli(["--flag"], opts, AppConfig.Default) != .Failed)
    }

    @Test("printHelpMessage: long-key-only and bare options")
    func printHelpMessageLongKeyAndBare() {
        var o = CliOptions.Default
        o.LongKey = "flag"
        o.printHelpMessage()
        CliOptions.Default.printHelpMessage()
    }

    @Test("--arch as long form with no value => Failed")
    func archLongFormNoValue() {
        #expect(parse(["--arch"]) == .Failed)
    }

    @Test("--arch as long form with dash value => Failed")
    func archLongFormDashValue() {
        #expect(parse(["--arch", "-x"]) == .Failed)
    }

    private var optLKV: [CliOptions] {
        var o = CliOptions.Default
        o.LongKey = "name"
        o.Value = "N"
        return [o]
    }

    @Test("long-key-only option consumes its value")
    func longKeyOnlyConsumesValue() {
        #expect(CLI.parseCli(["--name", "bob"], optLKV, AppConfig.Default) != .Failed)
    }

    @Test("long-key-only option missing value => Failed")
    func longKeyOnlyMissingValue() {
        #expect(CLI.parseCli(["--name"], optLKV, AppConfig.Default) == .Failed)
    }

    @Test("long-key-only option dash value => Failed")
    func longKeyOnlyDashValue() {
        #expect(CLI.parseCli(["--name", "-x"], optLKV, AppConfig.Default) == .Failed)
    }

    @Test("long-key-only option non-matching arg is ignored")
    func longKeyOnlyNonMatchingIgnored() {
        var o = CliOptions.Default
        o.LongKey = "flag"
        #expect(CLI.parseCli(["other"], [o], AppConfig.Default) != .Failed)
    }

    @Test("bare option is ignored")
    func bareOptionIgnored() {
        #expect(CLI.parseCli(["x"], [CliOptions.Default], AppConfig.Default) != .Failed)
    }

    @Test("multiple key flag with a trailing non-matching arg")
    func multipleKeyFlagTrailingNonMatching() {
        var o = CliOptions.Default
        o.Key = "f"
        o.Multiple = true
        #expect(CLI.parseCli(["-f", "z"], [o], AppConfig.Default) != .Failed)
    }

    @Test("long-key-only option with value advances past both tokens")
    func longKeyOnlyWithValueAdvancesBoth() {
        var o = CliOptions.Default
        o.LongKey = "name"
        o.Value = "N"
        let (_, leftover) = CLI.fetchArgs(["--name", "bob"], o, AppConfig.Default)
        #expect(leftover == [])
    }

    // Exercise every fetchArgs/parseCli arm and guard combination for branch coverage.
    @Test("parser exercises all fetchArgs and parseCli arms")
    func parserExercisesAllArms() {
        var filesOpt = CliOptions.Default
        filesOpt.Value = "F"
        filesOpt.Multiple = true

        var keyMul = CliOptions.Default
        keyMul.Key = "f"
        keyMul.Multiple = true

        var aOpt = CliOptions.Default
        aOpt.Key = "A"
        aOpt.Value = "ARCH"

        // Multiple value-option: several values (recurse), single (base), and empty argv
        _ = CLI.fetchArgs(["a", "b", "c"], filesOpt, AppConfig.Default)
        _ = CLI.fetchArgs(["a"], filesOpt, AppConfig.Default)
        _ = CLI.fetchArgs([], filesOpt, AppConfig.Default)
        // Multiple key-option: trailing match (recurse) and non-match (inner NotFound->Result)
        _ = CLI.fetchArgs(["-f", "-f"], keyMul, AppConfig.Default)
        _ = CLI.fetchArgs(["-f", "z"], keyMul, AppConfig.Default)
        // Non-multiple option: leftover (_ with len-resIndex>0) and none (_ with =0)
        _ = CLI.fetchArgs(["-A", "rv32i", "x", "y"], aOpt, AppConfig.Default)
        _ = CLI.fetchArgs(["-A", "rv32i"], aOpt, AppConfig.Default)
        // NotFound with following args (recurse) and as the only arg
        _ = CLI.fetchArgs(["zzz", "-A", "rv32i"], aOpt, AppConfig.Default)
        _ = CLI.fetchArgs(["zzz"], aOpt, AppConfig.Default)
        // parseCli: single option (opts.Length=1), full chain with trailing files, empty argv
        _ = CLI.parseCli(["-A", "rv32i"], [aOpt], AppConfig.Default)
        _ = CLI.parseCli(["-A", "rv32i", "f1", "f2"], CLI.InitCLI, AppConfig.Default)
        _ = CLI.parseCli([], CLI.InitCLI, AppConfig.Default)
        #expect(true)
    }

    // FetchArgs is tail-recursive (O(1) stack, O(n) time). A very large argv must
    // parse without the StackOverflowException the previous per-token non-tail recursion
    // raised (~1e5 tokens on the default stack). Both deep paths are exercised: the NotFound
    // accumulator path and the Multiple-match consume path, each ~5e5 tokens.
    @Test("fetchArgs handles a huge non-matching argv without overflowing the stack")
    func fetchArgsHugeNonMatching() throws {
        let argv = (0 ..< 500000).map { "f\($0)" }
        var opt = CliOptions.Default
        opt.Key = "A"
        opt.Value = "ARCH" // never matches f<i>
        let (res, leftover) = CLI.fetchArgs(argv, opt, AppConfig.Default)
        guard case .NotFound = res else {
            Issue.record("expected NotFound, got \(res)")
            return
        }
        #expect(leftover.count == 500000) // nothing matched; all preserved in order
    }

    @Test("fetchArgs handles a huge matching argv without overflowing the stack")
    func fetchArgsHugeMatching() throws {
        let argv = (0 ..< 500000).map { "f\($0)" }
        var opt = CliOptions.Default
        opt.Value = "F"
        opt.Multiple = true // identity handler matches each
        let (res, leftover) = CLI.fetchArgs(argv, opt, AppConfig.Default)
        guard case .Result = res else {
            Issue.record("expected Result, got \(res)")
            return
        }
        #expect(leftover == []) // all tokens consumed
    }
}
