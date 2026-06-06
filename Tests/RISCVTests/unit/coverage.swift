// Targeted tests for paths the ported reference suite does not reach:
// double-word memory API, page-boundary crossing in MemoryMap, bitmap-word
// straddling, bulk storeRange, ELF loader error branches, and decode misses.

import Foundation
import Testing
@testable import RISCV

struct UnitCoverageTests {
    // ---- MachineState double-word store/load (used by LD/SD once I64 lands) ----

    @Test("storeMemoryDoubleWord / loadMemoryDoubleWord round-trip")
    func doubleWordRoundTrip() {
        var m = InitMachineState(.empty, .RV64i, false)
        m = m.storeMemoryDoubleWord(0x100, Int64(bitPattern: 0xC3B6_B5B4_B3B2_A10F))
        #expect(m.loadMemoryDoubleWord(0x100) == Int64(bitPattern: 0xC3B6_B5B4_B3B2_A10F))
    }

    // ---- MemoryMap page-boundary crossing (4 KiB pages) ----

    @Test("multi-byte store/load across a page boundary round-trips")
    func crossPageRoundTrip() {
        var m = InitMachineState(.empty, .RV64i, false)
        // 0xFFC..0x1003 straddles the page-0/page-1 boundary.
        m = m.storeMemoryDoubleWord(0xFFC, 0x1122_3344_5566_7788)
        #expect(m.loadMemoryDoubleWord(0xFFC) == 0x1122_3344_5566_7788)
        #expect(m.loadMemoryWord(0xFFE) == 0x3344_5566)
    }

    @Test("cross-page load with the unmapped tail returns nil")
    func crossPageUnmappedTail() {
        var m = InitMachineState(.empty, .RV64i, false)
        m = m.storeMemoryWord(0xFFC, 0x11223344) // only the head page is mapped
        #expect(m.loadMemoryDoubleWord(0xFFC) == nil)
    }

    @Test("cross-page load with the unmapped head returns nil")
    func crossPageUnmappedHead() {
        var m = InitMachineState(.empty, .RV64i, false)
        m = m.storeMemoryWord(0x1000, 0x11223344) // only the tail page is mapped
        #expect(m.loadMemoryDoubleWord(0xFFC) == nil)
    }

    // ---- mapped-bitmap word straddling (a 64-bit word covers 64 bytes) ----

    @Test("load straddling two bitmap words round-trips")
    func bitmapWordStraddle() {
        var m = InitMachineState(.empty, .RV64i, false)
        // Offsets 60..67 cross the boundary between bitmap word 0 and word 1.
        m = m.storeMemoryDoubleWord(60, 0x0102_0304_0506_0708)
        #expect(m.loadMemoryDoubleWord(60) == 0x0102_0304_0506_0708)
    }

    @Test("load straddling two bitmap words with an unmapped tail returns nil")
    func bitmapWordStraddleUnmapped() {
        var m = InitMachineState(.empty, .RV64i, false)
        m = m.storeMemoryWord(60, 0x01020304) // bytes 60..63 only — word 1 untouched
        #expect(m.loadMemoryDoubleWord(60) == nil)
    }

    @Test("single-word bitmap check fails on an unmapped middle byte")
    func bitmapSingleWordGap() {
        var m = InitMachineState(.empty, .RV64i, false)
        m = m.storeMemoryByte(0x10, 0xAA)
        m = m.storeMemoryByte(0x13, 0xBB) // 0x11/0x12 unmapped
        #expect(m.loadMemoryWord(0x10) == nil)
    }

    // ---- bulk storeRange over multiple pages (the ELF segment path) ----

    @Test("storeRange spanning two pages maps every byte")
    func storeRangeTwoPages() {
        var mem = MemoryMap.empty
        let data = (0 ..< 300).map { UInt8(truncatingIfNeeded: $0) }
        mem.storeRange(4000, data)
        #expect(mem.count == 300)
        #expect(mem[4000] == 0)
        #expect(mem[4096] == UInt8(truncatingIfNeeded: 96))
        #expect(mem[4299] == UInt8(truncatingIfNeeded: 299))
        #expect(mem[4300] == nil)
        // Overlapping re-store must not double-count.
        mem.storeRange(4000, data)
        #expect(mem.count == 300)
    }

    // ---- Decoder returns nil for an undecodable instruction ----

    @Test("Decoder.Decode returns nil for an illegal instruction")
    func decoderNilOnIllegal() {
        let m = InitMachineState(.empty, .RV32i, false)
        #expect(Decoder.Decode(m, 0) == nil)
    }

    // ---- remaining decode wildcard arms (per-opcode unsupported funct3/funct7) ----

    @Test("I decode: unsupported load/store/ALU function codes return None")
    func decodeWildcardArms() {
        let m32 = InitMachineState(.empty, .RV32i, false)
        #expect(DecodeI.Decode(m32, 0x00003083) == InstructionI.None) // load  funct3=011 (LD - not base I)
        #expect(DecodeI.Decode(m32, 0x00003023) == InstructionI.None) // store funct3=011 (SD - not base I)
        #expect(DecodeI.Decode(m32, 0x02000033) == InstructionI.None) // ALU funct7=0000001 (MUL - not base I)
    }

    // ---- IALIGN: a C-extension machine aligns instructions to 2 bytes ----

    @Test("instrAlign is 2 with the C extension and 4 without")
    func instrAlignByArch() {
        #expect(InitMachineState(.empty, .RV32ic, false).instrAlign == 2)
        #expect(InitMachineState(.empty, .RV32i, false).instrAlign == 4)
    }

    // ---- XLEN-wrapping load over unmapped memory traps (per-byte slow path) ----

    @Test("RV32 wrapping load over unmapped memory returns nil")
    func wrappingLoadUnmapped() {
        let m = InitMachineState(.empty, .RV32i, false)
        // 4-byte read at 0xFFFFFFFE wraps past 2^32 — and nothing is mapped.
        #expect(m.loadMemoryWord(0xFFFF_FFFE) == nil)
    }

    // ---- ELF loader error branches ----

    /// The minimal valid ELF32 fixture from the reference run tests.
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

    func withTempFile(_ bytes: [UInt8], _ body: (String) throws -> Void) throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try Data(bytes).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        try body(url.path)
    }

    @Test("readElfFile throws on a truncated ELF header")
    func truncatedHeaderThrows() throws {
        // Valid magic, but the file ends before e_entry can be read.
        try withTempFile([0x7F, 0x45, 0x4C, 0x46, 0x01, 0x01, 0x01, 0x00]) { path in
            #expect(throws: ElfLoadError.self) { try Run.readElfFile(path) }
        }
    }

    @Test("readElfFile rejects a segment whose file size exceeds its memory size")
    func fileszOverMemszThrows() throws {
        var bomb = Self.elf32
        bomb[0x48] = 0x02 // p_memsz = 2 < p_filesz = 4
        bomb[0x49] = 0x00
        try withTempFile(bomb) { path in
            #expect(throws: ElfLoadError.self) { try Run.readElfFile(path) }
        }
    }

    @Test("readElfFile rejects a segment whose data lies outside the file")
    func segmentOutsideFileThrows() throws {
        var bomb = Self.elf32
        bomb[0x38] = 0xF0 // p_offset = 0xF0, beyond the 88-byte file
        try withTempFile(bomb) { path in
            #expect(throws: ElfLoadError.self) { try Run.readElfFile(path) }
        }
    }

    @Test("readElfFile rejects a file larger than the read cap before loading it")
    func oversizedFileRejected() throws {
        // 16 MiB + 1 of zeros — over `maxFileBytes`, rejected on its size alone.
        try withTempFile([UInt8](repeating: 0, count: 16 * 1024 * 1024 + 1)) { path in
            #expect(throws: ElfLoadError.self) { try Run.readElfFile(path) }
        }
    }

    @Test("readElfFile rejects a non-regular file (FIFO)")
    func nonRegularFileRejected() throws {
        let path = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path
        #expect(mkfifo(path, 0o644) == 0)
        defer { unlink(path) }
        #expect(throws: ElfLoadError.self) { try Run.readElfFile(path) }
    }

    // ---- fetchInstruction fallback when the full word is unreadable ----

    @Test("fetch of a compressed instruction in the last two mapped bytes succeeds")
    func fetchCompressedAtMemoryEdge() {
        var m = InitMachineState(.empty, .RV32i, false)
        m = m.storeMemoryHalfWord(0x8000_0000, 0x0001) // inst[1:0] != 11 -> 16-bit
        #expect(Run.fetchInstruction(m) == 0x0001)
    }

    @Test("fetch of a 32-bit instruction with only two mapped bytes fails")
    func fetchTruncatedWordFails() {
        var m = InitMachineState(.empty, .RV32i, false)
        m = m.storeMemoryHalfWord(0x8000_0000, 0x0003) // inst[1:0] = 11 -> needs 4 bytes
        #expect(Run.fetchInstruction(m) == nil)
    }

    @Test("readElfFile skips non-PT_LOAD segments")
    func nonLoadSegmentSkipped() throws {
        var notes = Self.elf32
        notes[0x34] = 0x04 // p_type = PT_NOTE — not loadable
        try withTempFile(notes) { path in
            let (mem, entry) = try Run.readElfFile(path)
            #expect(mem.count == 0)
            #expect(entry == 0x8000_0000)
        }
    }

    // ---- C.LD delegates to ExecuteI64.execLD: unmapped address traps ----

    @Test("C.LD from unmapped memory traps with MemAddress")
    func cLDUnmappedTraps() {
        let m = InitMachineState(.empty, .RV64ic, false).setRunState(.Run)
        let r = ExecuteC.Execute(.C_LD(rd: 9, rs1: 8, imm: 0), m)
        guard case .Trap(.MemAddress) = r.RunState else {
            Issue.record("expected MemAddress trap, got \(r.RunState)")
            return
        }
    }

    // ---- public reservation API (exec paths use the fused internal transitions) ----

    @Test("setReservation / clearReservation round-trip")
    func reservationAPI() {
        var m = InitMachineState(.empty, .RV64ia, false)
        m = m.setReservation(0x40, 8)
        #expect(m.Reservation?.0 == 0x40)
        #expect(m.Reservation?.1 == 8)
        m = m.clearReservation()
        #expect(m.Reservation == nil)
    }

    // ---- extension decoders: words outside their opcode space (the gated Decoder
    // no longer routes every miss through every decoder, so cover directly) ----

    @Test("extension decoders return None for words outside their opcode space")
    func decodersOuterDefaults() {
        let m64 = InitMachineState(.empty, .RV64ima, false)
        let m32c = InitMachineState(.empty, .RV32ic, false)
        #expect(DecodeM64.Decode(m64, 0x00000013) == InstructionM64.None) // addi — not OP-32
        #expect(DecodeA64.Decode(0x00000013) == InstructionA64.None) // addi — not AMO
        #expect(DecodeC.Decode(m32c, 0x00000013) == InstructionC.None) // 32-bit word — not compressed
    }

    @Test("word illegal in every extension is gated to nil on RV64ia")
    func decoderNilThroughA64Gate() {
        // 0x2800302f: AMO opcode with unknown funct5 — A misses (funct3), A64 misses
        // (funct5), M/C absent -> the rv64-true + A64-None fall-through yields nil.
        #expect(Decoder.Decode(InitMachineState(.empty, .RV64ia, false), Int32(bitPattern: 0x2800302f)) == nil)
    }

    // ---- formatting helpers ----

    @Test("printHelpMessage pads a long option name without truncation")
    func longOptionHelpMessage() {
        var opt = CliOptions.Default
        opt.LongKey = "a-very-long-option-name-over-twenty-chars"
        opt.HelpMessage = "long"
        opt.printHelpMessage() // exercises the no-padding (already wide) branch
        #expect(padRight("wider-than-needed", 5) == "wider-than-needed")
        #expect(padRight("ab", 4) == "ab  ")
    }
}
