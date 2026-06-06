import Testing
import Foundation

import RISCV

//===============================================
// App / Run / main integration tests
struct UnitAppTests {
    // ELF32 whose PT_LOAD at 0x80000000 is: addi x5,x0,42 ; jal x0,0 (self-loop => Stopped)
    static let progElf: [UInt8] = [
        // ELF header
        0x7F, 0x45, 0x4C, 0x46, 0x01, 0x01, 0x01, 0x00, 0, 0, 0, 0, 0, 0, 0, 0,
        0x02, 0x00, 0xF3, 0x00, 0x01, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x80,
        0x34, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00,
        0x34, 0x00, 0x20, 0x00, 0x01, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x01, 0x00, 0x00, 0x00,
        0x54, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x80,
        0x00, 0x00, 0x00, 0x80,
        0x08, 0x00, 0x00, 0x00,
        0x08, 0x00, 0x00, 0x00,
        0x05, 0x00, 0x00, 0x00,
        0x00, 0x10, 0x00, 0x00,
        // prog: addi x5,x0,42 ; jal x0,0
        0x93, 0x02, 0xA0, 0x02, 0x6F, 0x00, 0x00, 0x00,
    ]

    func withElf(_ bytes: [UInt8], _ f: (String) throws -> Void) throws {
        let path = NSTemporaryDirectory() + UUID().uuidString
        defer { try? FileManager.default.removeItem(atPath: path) }
        try Data(bytes).write(to: URL(fileURLWithPath: path))
        try f(path)
    }

    @Test("Run.Run loads an ELF and runs to Stopped (verbose)")
    func RunRunLoadsElfToStopped() throws {
        try withElf(UnitAppTests.progElf) { path in
            var cfg = AppConfig.Default
            cfg.Arch = .RV32i
            cfg.Files = [path]
            cfg.Verbosity = true
            let res = try Run.Run(cfg)
            #expect(res.RunState == .Stopped)
            #expect(res.getRegister(5) == 42)
        }
    }

    @Test("main: help returns 0")
    func mainHelpReturns0() {
        #expect(Program.main(["-h"]) == 0)
    }

    @Test("main: failed parse returns 0")
    func mainFailedParseReturns0() {
        #expect(Program.main(["-A"]) == 0)
    }

    @Test("main: missing required params returns 0")
    func mainMissingRequiredReturns0() {
        #expect(Program.main(["-v"]) == 0)
    }

    @Test("main: full run returns 0")
    func mainFullRunReturns0() throws {
        try withElf(UnitAppTests.progElf) { path in
            #expect(Program.main(["-A", "rv32i", path]) == 0)
        }
    }

    @Test("runCycle traps on an illegal instruction")
    func runCycleTrapsOnIllegal() {
        var m = InitMachineState(.empty, .RV32i, false).setRunState(.Run)
        m = m.storeMemoryWord(0x80000000, 0)
        m = Run.runCycle(m)
        guard case .Trap(.InstructionDecode) = m.RunState else {
            Issue.record("expected InstructionDecode trap, got \(m.RunState)")
            return
        }
    }

    @Test("runSteps aborts a non-terminating program with StepLimit")
    func runStepsAbortsNonTerminating() {
        // jal x0,+4 ; jal x0,-4  -> infinite 2-instruction loop (neither targets its own PC)
        var m = InitMachineState(.empty, .RV32i, false).setRunState(.Run)
        m = m.storeMemoryWord(0x80000000, Int64(Int32(bitPattern: 0x0040006f)))
        m = m.storeMemoryWord(0x80000004, Int64(Int32(bitPattern: 0xffdff06f)))
        #expect(Run.runSteps(50, m).RunState == .Trap(.StepLimit))
    }

    @Test("main: a malformed ELF is reported without crashing")
    func mainMalformedElfReported() throws {
        try withElf([0, 1, 2, 3]) { path in
            #expect(Program.main(["-A", "rv32i", path]) == 0)
        }
    }

    @Test("runSteps completes when the budget equals the instruction count")
    func runStepsBudgetEqualsCount() {
        let prog: [Int64] = [0x00500093, 0x00700113, 0x002081b3, 0x00100073]  // 4 instrs, ebreak last
        var m = InitMachineState(.empty, .RV32i, false).setRunState(.Run)
        for (i, w) in prog.enumerated() {
            m = m.storeMemoryWord(0x80000000 + Int64(i * 4), w)
        }
        #expect(Run.runSteps(4, m).RunState == .Trap(.EBreak))
        #expect(Run.runSteps(3, m).RunState == .Trap(.StepLimit))
    }

    @Test("runSteps 0 immediately hits StepLimit")
    func runSteps0HitsStepLimit() {
        let m = InitMachineState(.empty, .RV32i, false).setRunState(.Run)
        #expect(Run.runSteps(0, m).RunState == .Trap(.StepLimit))
    }

    // Tthe PC starts at the ELF entry point (e_entry), not a hardcoded 0x80000000.
    // Patch progElf's e_entry (file offset 0x18) to 0x80000004 so execution starts at the
    // second instruction (jal x0,0 self-loop), skipping `addi x5,x0,42`; x5 must stay 0.
    @Test("Run.Run starts execution at the ELF entry point")
    func runRunStartsAtEntryPoint() throws {
        var elf = UnitAppTests.progElf
        elf[0x18] = 0x04; elf[0x19] = 0x00; elf[0x1A] = 0x00; elf[0x1B] = 0x80
        try withElf(elf) { path in
            var cfg = AppConfig.Default
            cfg.Arch = .RV32i
            cfg.Files = [path]
            cfg.Verbosity = false
            let res = try Run.Run(cfg)
            #expect(res.PC == 0x80000004)                 // started at the entry point and self-looped there
            #expect(res.RunState == .Stopped)
            #expect(res.getRegister(5) == 0)              // the addi at 0x80000000 was skipped
        }
    }
}
