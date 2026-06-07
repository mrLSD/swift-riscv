// Replica of riscv-fs `Program.fs` (module main)
//
// The application entry logic lives here, in the library, so it is fully testable;
// the executable target is a one-line trampoline into `Program.main`.

public enum Program {
    @discardableResult
    public static func main(_ argv: [String]) -> Int32 {
        let cfg = CLI.parseCli(argv, CLI.InitCLI, AppConfig.Default)
        switch cfg {
        case .Failed:
            print("Failed parse CLI params. Print --help")
        case .Stopped:
            ()
        case let .Success(x):
            if !x.CheckRequired {
                print("Wrong parameters put --help to get more information")
            } else {
                do {
                    let res = try Run.Run(x)
                    print("Result state: \(res.RunState)")
                } catch {
                    // CheckRequired above guarantees Files is non-nil and non-empty here,
                    // so indexing [0] is safe.
                    print("Error: failed to load or run '\(x.Files![0])': \(error)")
                }
            }
        }
        return 0 // return an integer exit code
    }
}
