// Branch-outcome completion: Swift's coverage instrumentation has no branch
// counters, so these were found by auditing region execution counts — every
// boolean decision in the library must exercise BOTH outcomes. Each test below
// drives a previously one-sided branch.

import Testing
@testable import RISCV

struct UnitBranchCovTests {
    let m32 = InitMachineState(.empty, .RV32i, false)

    // ---- DecodeI: shamt_ok == false on the SLLI/SRLI arms (bit25 set on RV32) ----
    // (The SRAI arm's shamt_ok-false is already exercised by 0x42005013.)

    @Test("SLLI guard false: bit25 set on RV32 forces shamt_ok false -> None")
    func decodeSLLIShamtOkFalse() {
        #expect(DecodeI.Decode(m32, Int32(bitPattern: 0x02001013)) == InstructionI.None)
    }

    @Test("SRLI guard false: bit25 set on RV32 forces shamt_ok false -> None")
    func decodeSRLIShamtOkFalse() {
        #expect(DecodeI.Decode(m32, Int32(bitPattern: 0x02005013)) == InstructionI.None)
    }

    // ---- DecodeI: ALU where-guard false for every funct3 (bad funct7 -> None) ----
    // ADD/SUB guard-false and SRL guard-false are already exercised (0x02000033 and
    // the SRA encodings); these cover the remaining arms.

    @Test("ALU guard false: bad funct7 falls through to None for each funct3", arguments: [
        UInt32(0x401111B3), // SLL  shape, funct7=0100000
        UInt32(0x401121B3), // SLT  shape, funct7=0100000
        UInt32(0x401131B3), // SLTU shape, funct7=0100000
        UInt32(0x401141B3), // XOR  shape, funct7=0100000
        UInt32(0x021151B3), // SRA/SRL shape, funct7=0000001 (neither SRL nor SRA)
        UInt32(0x401161B3), // OR   shape, funct7=0100000
        UInt32(0x401171B3), // AND  shape, funct7=0100000
    ])
    func decodeALUGuardFalse(instr: UInt32) {
        #expect(DecodeI.Decode(m32, Int32(bitPattern: instr)) == InstructionI.None)
    }

    // ---- CLI: CliUsage over an empty option array (zero loop iterations) ----

    @Test("CliUsage with no options runs the option loop zero times")
    func cliUsageEmptyOptions() {
        CLI.CliUsage([]) // header lines only; printHelpMessage never called
    }

    // ---- MemoryMap: overwriting an already-mapped byte must not grow count ----

    @Test("setByte on an already-mapped address does not increment count")
    func setByteOverwriteKeepsCount() {
        var mem = MemoryMap.empty
        mem.setByte(5, 1)
        mem.setByte(5, 2)
        #expect(mem.count == 1)
        #expect(mem[5] == 2)
    }

    // ---- MemoryMap: bitmap-word straddle with the FIRST word's bytes unmapped ----
    // (The mapped-head/unmapped-tail direction is covered elsewhere; this drives the
    // short-circuit of the && in isMappedRange's two-word path.)

    @Test("straddling load with an unmapped head word returns nil")
    func bitmapStraddleUnmappedHead() {
        var m = InitMachineState(.empty, .RV64i, false)
        m = m.storeMemoryWord(64, 0x01020304) // bytes 64..67 (bitmap word 1) only
        #expect(m.loadMemoryDoubleWord(60) == nil) // bytes 60..63 (word 0) unmapped
    }

    // ---- MemoryMap: storeRange of an empty byte run (zero loop iterations) ----

    @Test("storeRange with empty data maps nothing")
    func storeRangeEmpty() {
        var mem = MemoryMap.empty
        mem.storeRange(0x100, [])
        #expect(mem.count == 0)
        #expect(mem[0x100] == nil)
    }

    // ---- Run: ELF with phnum == 0 (program-header loop runs zero times) ----

    @Test("readElfFile with zero program headers yields empty memory")
    func elfZeroProgramHeaders() throws {
        var elf = UnitCoverageTests.elf32
        elf[0x2C] = 0 // e_phnum = 0
        let cov = UnitCoverageTests()
        try cov.withTempFile(elf) { path in
            let (mem, entry) = try Run.readElfFile(path)
            #expect(mem.count == 0)
            #expect(entry == 0x8000_0000)
        }
    }
}
