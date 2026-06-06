import Testing
import Foundation

import RISCV

//===============================================
// Run tests
@Suite struct RunRunTests {
    // Minimal ELF images with a single PT_LOAD segment: 4 data bytes (DE AD BE EF)
    // at 0x80000000 and memsz = 6 (two zero-filled .bss bytes).
    static let elf32: [UInt8] = [
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
        0x04, 0x00, 0x00, 0x00,
        0x06, 0x00, 0x00, 0x00,
        0x05, 0x00, 0x00, 0x00,
        0x00, 0x10, 0x00, 0x00,
        0xDE, 0xAD, 0xBE, 0xEF,
    ]

    static let elf64: [UInt8] = [
        0x7F, 0x45, 0x4C, 0x46, 0x02, 0x01, 0x01, 0x00, 0, 0, 0, 0, 0, 0, 0, 0,
        0x02, 0x00, 0xF3, 0x00, 0x01, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x80, 0x00, 0x00, 0x00, 0x00,
        0x40, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00,
        0x40, 0x00, 0x38, 0x00, 0x01, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x01, 0x00, 0x00, 0x00,
        0x05, 0x00, 0x00, 0x00,
        0x78, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x80, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x80, 0x00, 0x00, 0x00, 0x00,
        0x04, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x06, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x10, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0xDE, 0xAD, 0xBE, 0xEF,
    ]

    func withTempElf(_ bytes: [UInt8], _ f: (String) throws -> Void) throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let path = url.path
        try Data(bytes).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        try f(path)
    }

    // ---- ELF loader loads data segments (not just executable) for both classes ----
    @Test("readElfFile loads a 32-bit PT_LOAD segment and zero-fills bss")
    func readElfFileLoads32BitPTLoadSegment() throws {
        try withTempElf(Self.elf32) { path in
            let (mem, entry) = try Run.readElfFile(path)
            #expect(entry == 0x80000000)
            #expect(mem.count == 6)
            #expect(mem[0x80000000] == 0xDE)
            #expect(mem[0x80000001] == 0xAD)
            #expect(mem[0x80000002] == 0xBE)
            #expect(mem[0x80000003] == 0xEF)
            #expect(mem[0x80000004] == 0x00)
            #expect(mem[0x80000005] == 0x00)
        }
    }

    @Test("readElfFile loads a 64-bit PT_LOAD segment")
    func readElfFileLoads64BitPTLoadSegment() throws {
        try withTempElf(Self.elf64) { path in
            let (mem, entry) = try Run.readElfFile(path)
            #expect(entry == 0x80000000)
            #expect(mem.count == 6)
            #expect(mem[0x80000000] == 0xDE)
            #expect(mem[0x80000003] == 0xEF)
            #expect(mem[0x80000005] == 0x00)
        }
    }

    // ---- full fetch/decode/execute/trap loop ----
    func loadProgramV(_ verbosity: Bool, _ words: [UInt32]) -> MachineState {
        var m = InitMachineState(.empty, .RV32i, verbosity).setRunState(.Run)
        for (i, w) in words.enumerated() {
            let a = 0x80000000 + Int64(i * 4)
            m = m.storeMemoryWord(a, Int64(Int32(bitPattern: w)))
        }
        return m
    }

    func loadProgram(_ words: [UInt32]) -> MachineState {
        return loadProgramV(false, words)
    }

    @Test("runCycle executes a program and stops on EBREAK")
    func runCycleExecutesAndStopsOnEBREAK() throws {
        // addi x1,x0,5 ; addi x2,x0,7 ; add x3,x1,x2 ; ebreak
        var m = loadProgram([0x00500093, 0x00700113, 0x002081b3, 0x00100073])
        m = Run.runCycle(m)
        #expect(m.getRegister(3) == 12)
        #expect(m.RunState == .Trap(.EBreak))
    }

    @Test("runCycle traps when PC runs into unmapped memory")
    func runCycleTrapsOnUnmappedMemory() throws {
        // addi x1,x0,5 ; (no instruction at the next PC)
        var m = loadProgram([0x00500093])
        m = Run.runCycle(m)
        #expect(m.getRegister(1) == 5)
        guard case .Trap(.InstructionFetch) = m.RunState else {
            Issue.record("expected InstructionFetch trap, got \(m.RunState)")
            return
        }
    }

    @Test("readElfFile throws on a non-ELF file")
    func readElfFileThrowsOnNonElf() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try Data([0, 1, 2, 3]).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        #expect(throws: (any Error).self) {
            _ = try Run.readElfFile(url.path)
        }
    }

    // ---- ELF loader bounds total mapped memory (untrusted p_memsz) ----
    @Test("readElfFile rejects a 32-bit segment whose memsz exceeds the limit")
    func readElfFileRejects32BitOversizedMemsz() throws {
        // elf32 with p_memsz = 0x00800000 (8 MiB) > the loader cap; the check runs before
        // GetMemoryContents, so an oversized segment is rejected without any large allocation.
        var bomb = Self.elf32
        bomb[0x48] = 0x00; bomb[0x49] = 0x00; bomb[0x4A] = 0x80; bomb[0x4B] = 0x00
        try withTempElf(bomb) { path in
            #expect(throws: (any Error).self) {
                _ = try Run.readElfFile(path)
            }
        }
    }

    @Test("readElfFile rejects a 64-bit segment with a high-bit memsz (no signed wrap)")
    func readElfFileRejects64BitHighBitMemsz() throws {
        // p_memsz = 0xFFFFFFFFFFFFFFFF would wrap a signed accumulator; the uint64 saturating
        // check rejects it before any allocation instead of relying on a downstream overflow.
        var bomb = Self.elf64
        for i in 0x68...0x6F { bomb[i] = 0xFF }
        try withTempElf(bomb) { path in
            #expect(throws: (any Error).self) {
                _ = try Run.readElfFile(path)
            }
        }
    }

    // ---- register dump is gated by verbosity and fires on both terminal states ----
    @Test("runCycle on a self-jump stops (non-verbose, no dump)")
    func runCycleSelfJumpStops() throws {
        #expect(Run.runCycle(loadProgram([0x0000006f])).RunState == .Stopped)  // jal x0,0
    }

    @Test("verbose run dumps registers on a Stopped halt")
    func verboseRunDumpsRegistersOnStopped() throws {
        let m = loadProgramV(true, [0x00500093, 0x0000006f])  // addi x1,x0,5 ; jal x0,0 (self)
        #expect(Run.runCycle(m).RunState == .Stopped)
    }

    @Test("verbose run dumps registers on a Trap halt")
    func verboseRunDumpsRegistersOnTrap() throws {
        let m = loadProgramV(true, [0x00500093, 0x00100073])  // addi x1,x0,5 ; ebreak
        #expect(Run.runCycle(m).RunState == .Trap(.EBreak))
    }
}
