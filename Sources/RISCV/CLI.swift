// Replica of riscv-fs `CLI.fs` (module ISA.RISCV.CLI)

import Foundation

public struct AppConfig: Sendable, Equatable {
    public var Verbosity: Bool?
    public var Arch: Architecture?
    public var Files: [String]?

    public static var Default: AppConfig {
        AppConfig(
            Verbosity: false,
            Arch: nil,
            Files: nil
        )
    }

    public var CheckRequired: Bool {
        if Files == nil || Arch == nil {
            false
        } else {
            true
        }
    }
}

public enum CliResult {
    case Result(AppConfig)
    case Error
    case NotFound(AppConfig)
}

public enum CliStatus: Equatable {
    case Success(AppConfig)
    case Stopped
    case Failed
}

public struct CliOptions: Sendable {
    public var Key: String?
    public var LongKey: String?
    public var Value: String?
    public var Multiple: Bool
    public var HelpMessage: String
    public var StopExecution: Bool
    public var Handler: @Sendable (String, AppConfig) -> AppConfig

    public static var Default: CliOptions {
        CliOptions(
            Key: nil,
            LongKey: nil,
            Value: nil,
            Multiple: false,
            HelpMessage: "",
            StopExecution: false,
            Handler: { _, cfg in cfg }
        )
    }

    public func printHelpMessage() {
        let msg =
            if let key = Key, let longKey = LongKey {
                "-\(key), --\(longKey)"
            } else if let key = Key {
                "-\(key)\t"
            } else if let longKey = LongKey {
                "--\(longKey)\t"
            } else if let value = Value {
                "<\(value)>"
            } else {
                ""
            }
        print(padRight("", 5) + padRight(msg, 20) + " " + HelpMessage)
    }
}

public enum CLI {
    public static let version = "v0.1.0"
    public static let author = "(c) \(Calendar.current.component(.year, from: Date())) by Evgeny Ukhanov"
    public static let about = "RISC-V Simulator for Formal RISC-V ISA implementation\n\(version) \(author)"

    /// Helper for print Usage info
    public static func CliUsage(_ cliArgs: [CliOptions]) {
        print(about)
        print(padRight("", 5) + "USAGE:\n" + padRight("", 5) + "risc-v [OPTIONS] file...\nOPTIONS")
        for arg in cliArgs {
            arg.printHelpMessage()
        }
    }

    // Fetch arguments to App config data.
    // A single walk over an index into `argv` with an explicit leftover accumulator
    // (the reference's tail-recursive loop): preserves the exact
    // (CliResult * leftover-argv) contract for every option shape and runs in O(n)
    // time and O(1) stack.
    public static func fetchArgs(_ argv: [String], _ opts: CliOptions, _ cfg: AppConfig) -> (CliResult, [String]) {
        let n = argv.count
        // Match `opts` against the token at index `i` (i < n), returning the partial result
        // and how many tokens it consumed (0 when it matched nothing).
        func tryMatch(_ i: Int, _ cfg: AppConfig) -> (CliResult, Int) {
            let arg = argv[i]
            // An option taking a <value> consumes the NEXT token, unless it is missing or
            // itself looks like an option (dash-prefixed) -> parse Error.
            func matchValue() -> (CliResult, Int) {
                if i + 1 < n {
                    let arg2 = argv[i + 1]
                    if arg2.hasPrefix("-") {
                        return (.Error, 0)
                    }
                    return (.Result(opts.Handler(arg2, cfg)), 2)
                }
                return (.Error, 0)
            }
            if let key = opts.Key {
                if "-\(key)" == arg {
                    return opts.Value != nil ? matchValue() : (.Result(opts.Handler(arg, cfg)), 1)
                } else if let longKey = opts.LongKey, "--\(longKey)" == arg {
                    return opts.Value != nil ? matchValue() : (.Result(opts.Handler(arg, cfg)), 1)
                }
                return (.NotFound(cfg), 0)
            } else if let longKey = opts.LongKey {
                if "--\(longKey)" == arg {
                    return opts.Value != nil ? matchValue() : (.Result(opts.Handler(arg, cfg)), 1)
                }
                return (.NotFound(cfg), 0)
            } else if opts.Value != nil {
                // A value-only (FILE) option must not swallow an unknown option:
                // a dash-prefixed token is a parse error, not a file name.
                if arg.hasPrefix("-") {
                    return (.Error, 0)
                }
                return (.Result(opts.Handler(arg, cfg)), 1)
            }
            return (.NotFound(cfg), 0)
        }
        // `leftover` keeps, in original order, the tokens this option did not consume (handed
        // to the next option). `matched` records whether the option matched at least once: a
        // Multiple option that consumes every token ends on the empty base case and must still
        // report Result (not NotFound).
        var leftover: [String] = []
        var i = 0
        var cfg = cfg
        var matched = false
        while i < n {
            let arg = argv[i]
            let (cfgRes, consumed) = tryMatch(i, cfg)
            switch cfgRes {
            case let .Result(res) where opts.Multiple && n - (i + consumed) > 0:
                // Consumed `consumed` tokens; keep scanning the rest for further matches.
                i += consumed
                cfg = res
                matched = true
            case let .NotFound(res):
                // Not for this option: preserve the token and continue with the rest.
                leftover.append(arg)
                i += 1
                cfg = res
            default:
                // Terminal: a non-Multiple Result, an Error, or a Multiple match that
                // consumed the remainder. Leftover = preserved tokens ++ the unconsumed tail.
                leftover.append(contentsOf: argv[(i + consumed)...])
                return (cfgRes, leftover)
            }
        }
        let result: CliResult = matched ? .Result(cfg) : .NotFound(cfg)
        return (result, leftover)
    }

    /// Parse CLI with specific params
    public static func parseCli(_ argv: [String], _ opts: [CliOptions], _ cfg: AppConfig) -> CliStatus {
        if opts.count < 1 {
            return .Success(cfg)
        }
        let opt = opts[0]
        let opts = opts.count > 1 ? Array(opts.dropFirst()) : []
        let (resCfg, newArgv) = fetchArgs(argv, opt, cfg)
        switch resCfg {
        case .Error:
            return .Failed
        case let .NotFound(cfg):
            return parseCli(newArgv, opts, cfg)
        case let .Result(cfg):
            if opt.StopExecution {
                return .Stopped
            } else {
                return parseCli(newArgv, opts, cfg)
            }
        }
    }

    /// Init CLI options and arguments
    public static let InitCLI: [CliOptions] = {
        var archOpt = CliOptions.Default
        archOpt.Key = "A"
        archOpt.LongKey = "arch"
        archOpt.Value = "ARCH"
        archOpt.HelpMessage = "RISC-V architecture (required). Available: rv32i, rv32im, rv32ia, rv32ima, rv32ic, rv32imc, rv32iac, rv32imac, rv64i, rv64im, rv64ia, rv64ima, rv64ic, rv64imc, rv64iac, rv64imac"
        archOpt.Handler = { arg, cfg in
            var cfg = cfg
            cfg.Arch = Architecture.fromString(arg)
            return cfg
        }

        var verbosityOpt = CliOptions.Default
        verbosityOpt.Key = "v"
        verbosityOpt.HelpMessage = "Verbosity output"
        verbosityOpt.Handler = { _, cfg in
            var cfg = cfg
            cfg.Verbosity = true
            return cfg
        }

        var helpOpt = CliOptions.Default
        helpOpt.Key = "h"
        helpOpt.LongKey = "help"
        helpOpt.HelpMessage = "Print help message"
        helpOpt.StopExecution = true
        helpOpt.Handler = { _, cfg in
            CliUsage(InitCLI)
            return cfg
        }

        var versionOpt = CliOptions.Default
        versionOpt.Key = "V"
        versionOpt.LongKey = "version"
        versionOpt.HelpMessage = "Application version"
        versionOpt.StopExecution = true
        versionOpt.Handler = { _, cfg in
            print(about)
            return cfg
        }

        var filesOpt = CliOptions.Default
        filesOpt.HelpMessage = "Files to executions"
        filesOpt.Value = "FILE"
        filesOpt.Multiple = true
        filesOpt.Handler = { arg, cfg in
            var cfg = cfg
            let res = cfg.Files ?? []
            cfg.Files = res + [arg]
            return cfg
        }

        return [archOpt, verbosityOpt, helpOpt, versionOpt, filesOpt]
    }()
}
