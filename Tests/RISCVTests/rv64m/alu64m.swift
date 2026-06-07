import Testing

import RISCV

//===============================================
// ALU `x64` tests
struct RV64mALUTests {
    func ALU(_ instr: UInt32, _ x1: Int64, _ x2: Int64, _ x3: Int64) throws {
        // Init MachineState
        let addr: Int64 = 0x80000000
        var mstate = InitMachineState(MemoryMap.empty, .RV64im, true)
        mstate = mstate.setPC(addr)
        mstate = mstate.setRegister(1, x1)
        mstate = mstate.setRegister(2, x2)

        let executor = try #require(Decoder.Decode(mstate, Int32(bitPattern: instr)))
        mstate = executor(mstate)
        #expect(mstate.getRegister(1) == x1)
        #expect(mstate.getRegister(2) == x2)
        #expect(mstate.getRegister(3) == x3)
        #expect(mstate.PC == addr + 4)
    }

    @Test("MUL: x3 = x2 * x1", arguments: [
        (Int64(200), Int64(10), Int64(20)),
        (Int64(0x1200), Int64(0x7e00), Int64(0x6db6db6db6db6db7)),
        (Int64(0x1240), Int64(0x7fc0), Int64(0x6db6db6db6db6db7)),
        (Int64(0x00000000), Int64(0x00000000), Int64(0x00000000)),
        (Int64(0x00000001), Int64(0x00000001), Int64(0x00000001)),
        (Int64(0x00000015), Int64(0x00000003), Int64(0x00000007)),
        (Int64(0), Int64(0), Int64(bitPattern: 0xffffffffffff8000)),
        (Int64(0), Int64(bitPattern: 0xffffffff80000000), Int64(0)),
        (Int64(0x0000400000000000), Int64(bitPattern: 0xffffffff80000000), Int64(bitPattern: 0xffffffffffff8000)),
        (Int64(0xff7f), Int64(bitPattern: 0xaaaaaaaaaaaaaaab), Int64(0x2fe7d)),
        (Int64(0xff7f), Int64(0x2fe7d), Int64(bitPattern: 0xaaaaaaaaaaaaaaab)),
    ])
    func MUL(_ x3: Int64, _ x2: Int64, _ x1: Int64) throws {
        try ALU(0x021101b3, x1, x2, x3)
    }

    @Test("MULW: x3 = x2 * x1", arguments: [
        (Int64(0x00000000), Int64(0x00000000), Int64(0x00000000)),
        (Int64(0x00000001), Int64(0x00000001), Int64(0x00000001)),
        (Int64(0x00000015), Int64(0x00000003), Int64(0x00000007)),
        (Int64(0), Int64(0), Int64(bitPattern: 0xffffffffffff8000)),
        (Int64(0), Int64(bitPattern: 0xffffffff80000000), Int64(0)),
        (Int64(0), Int64(bitPattern: 0xffffffff80000000), Int64(bitPattern: 0xffffffffffff8000)),
    ])
    func MULW(_ x3: Int64, _ x2: Int64, _ x1: Int64) throws {
        try ALU(0x021101bb, x1, x2, x3)
    }

    @Test("MULH: x3 = half (x2 * x1)", arguments: [
        (Int64(0x00000000), Int64(0x00000000), Int64(0x00000000)),
        (Int64(0x00000000), Int64(0x00000001), Int64(0x00000001)),
        (Int64(0x00000000), Int64(0x00000003), Int64(0x00000007)),
        (Int64(0), Int64(0), Int64(bitPattern: 0xffffffffffff8000)),
        (Int64(0), Int64(bitPattern: 0xffffffff80000000), Int64(0)),
        (Int64(0), Int64(bitPattern: 0xffffffff80000000), Int64(bitPattern: 0xffffffffffff8000)),
    ])
    func MULH(_ x3: Int64, _ x2: Int64, _ x1: Int64) throws {
        try ALU(0x021111b3, x1, x2, x3)
    }

    @Test("WMULHU: x3 = half (unsign x2 * unsign x1)", arguments: [
        (Int64(0x00000000), Int64(0x00000000), Int64(0x00000000)),
        (Int64(0x00000000), Int64(0x00000001), Int64(0x00000001)),
        (Int64(0x00000000), Int64(0x00000003), Int64(0x00000007)),
        (Int64(0), Int64(0), Int64(bitPattern: 0xffffffffffff8000)),
        (Int64(0), Int64(bitPattern: 0xffffffff80000000), Int64(0)),
        (Int64(bitPattern: 0xffffffff7fff8000), Int64(bitPattern: 0xffffffff80000000), Int64(bitPattern: 0xffffffffffff8000)),
        (Int64(0x1fefe), Int64(bitPattern: 0xaaaaaaaaaaaaaaab), Int64(0x2fe7d)),
        (Int64(0x1fefe), Int64(0x2fe7d), Int64(bitPattern: 0xaaaaaaaaaaaaaaab)),
    ])
    func WMULHU(_ x3: Int64, _ x2: Int64, _ x1: Int64) throws {
        try ALU(0x021131b3, x1, x2, x3)
    }

    @Test("WMULHSU: x3 = half (sign x2 * unsign x1)", arguments: [
        (Int64(0x00000000), Int64(0x00000000), Int64(0x00000000)),
        (Int64(0x00000000), Int64(0x00000001), Int64(0x00000001)),
        (Int64(0x00000000), Int64(0x00000003), Int64(0x00000007)),
        (Int64(0), Int64(0), Int64(bitPattern: 0xffffffffffff8000)),
        (Int64(0), Int64(bitPattern: 0xffffffff80000000), Int64(0)),
        (Int64(bitPattern: 0xffffffff80000000), Int64(bitPattern: 0xffffffff80000000), Int64(bitPattern: 0xffffffffffff8000)),
        (Int64(0xFC), Int64(0xFCCCAAA), Int64(0x100000000000)),
    ])
    func WMULHSU(_ x3: Int64, _ x2: Int64, _ x1: Int64) throws {
        try ALU(0x021121b3, x1, x2, x3)
    }

    @Test("DIV: x3 = x2 / x1", arguments: [
        (Int64(3), Int64(20), Int64(6)),
        (Int64(-3), Int64(-20), Int64(6)),
        (Int64(-3), Int64(20), Int64(-6)),
        (Int64(3), Int64(-20), Int64(-6)),
        (Int64(bitPattern: 0x8000000000000000), Int64(bitPattern: 0x8000000000000000), Int64(1)),
        (Int64(bitPattern: 0x8000000000000000), Int64(bitPattern: 0x8000000000000000), Int64(-1)),
        (Int64(-1), Int64(bitPattern: 0x8000000000000000), Int64(0)),
        (Int64(-1), Int64(1), Int64(0)),
        (Int64(-1), Int64(0), Int64(0)),
    ])
    func DIV(_ x3: Int64, _ x2: Int64, _ x1: Int64) throws {
        try ALU(0x021141b3, x1, x2, x3)
    }

    @Test("DIVW: x3 = x2 / x1", arguments: [
        (Int64(3), Int64(20), Int64(6)),
        (Int64(-3), Int64(-20), Int64(6)),
        (Int64(-3), Int64(20), Int64(-6)),
        (Int64(3), Int64(-20), Int64(-6)),
        (Int64(Int32.min), Int64(Int32.min), Int64(1)),
        (Int64(Int32.min), Int64(Int32.min), Int64(-1)),
        (Int64(-1), Int64(Int32.min), Int64(0)),
        (Int64(-1), Int64(1), Int64(0)),
        (Int64(-1), Int64(0), Int64(0)),
    ])
    func DIVW(_ x3: Int64, _ x2: Int64, _ x1: Int64) throws {
        try ALU(0x021141bb, x1, x2, x3)
    }

    @Test("DIVU: x3 = (unsign x2) / (unsign x1)", arguments: [
        (Int64(3), Int64(20), Int64(6)),
        (Int64(3074457345618258599), Int64(-20), Int64(6)),
        (Int64(0), Int64(20), Int64(-6)),
        (Int64(0), Int64(-20), Int64(-6)),
        (Int64(bitPattern: 0x8000000000000000), Int64(bitPattern: 0x8000000000000000), Int64(1)),
        (Int64(0), Int64(bitPattern: 0x8000000000000000), Int64(-1)),
        (Int64(-1), Int64(bitPattern: 0x8000000000000000), Int64(0)),
        (Int64(-1), Int64(1), Int64(0)),
        (Int64(-1), Int64(0), Int64(0)),
    ])
    func DIVU(_ x3: Int64, _ x2: Int64, _ x1: Int64) throws {
        try ALU(0x021151b3, x1, x2, x3)
    }

    @Test("DIVUW: x3 = unsign x2 / unsign x1", arguments: [
        (Int64(3), Int64(20), Int64(6)),
        (Int64(0), Int64(20), Int64(-6)),
        (Int64(0), Int64(-20), Int64(-6)),
        (Int64(Int32.min), Int64(Int32.min), Int64(1)),
        (Int64(0), Int64(Int32.min), Int64(-1)),
        (Int64(-1), Int64(Int32.min), Int64(0)),
        (Int64(-1), Int64(1), Int64(0)),
        (Int64(-1), Int64(0), Int64(0)),
    ])
    func DIVUW(_ x3: Int64, _ x2: Int64, _ x1: Int64) throws {
        try ALU(0x021151bb, x1, x2, x3)
    }

    // DIVUW must use only the low 32 bits of each operand (upper bits ignored).
    @Test("DIVUW: only low 32 bits", arguments: [
        (Int64(2), Int64(0x0000000100000005), Int64(2)),
        (Int64(5), Int64(11), Int64(0x0000000100000002)),
        (Int64(-1), Int64(20), Int64(0x0000000100000000)),
    ])
    func DIVUW_lowBits(_ x3: Int64, _ x2: Int64, _ x1: Int64) throws {
        try ALU(0x021151bb, x1, x2, x3)
    }

    @Test("REM: x3 = x2 % x1", arguments: [
        (Int64(2), Int64(20), Int64(6)),
        (Int64(-2), Int64(-20), Int64(6)),
        (Int64(2), Int64(20), Int64(-6)),
        (Int64(-2), Int64(-20), Int64(-6)),
        (Int64(0), Int64(bitPattern: 0x8000000000000000), Int64(1)),
        (Int64(0), Int64(bitPattern: 0x8000000000000000), Int64(-1)),
        (Int64(bitPattern: 0x8000000000000000), Int64(bitPattern: 0x8000000000000000), Int64(0)),
        (Int64(1), Int64(1), Int64(0)),
        (Int64(0), Int64(0), Int64(0)),
    ])
    func REM(_ x3: Int64, _ x2: Int64, _ x1: Int64) throws {
        try ALU(0x021161b3, x1, x2, x3)
    }

    @Test("REMW: x3 = x2 % x1", arguments: [
        (Int64(2), Int64(20), Int64(6)),
        (Int64(-2), Int64(-20), Int64(6)),
        (Int64(2), Int64(20), Int64(-6)),
        (Int64(-2), Int64(-20), Int64(-6)),
        (Int64(0), Int64(Int32.min), Int64(1)),
        (Int64(0), Int64(Int32.min), Int64(-1)),
        (Int64(Int32.min), Int64(Int32.min), Int64(0)),
        (Int64(1), Int64(1), Int64(0)),
        (Int64(0), Int64(0), Int64(0)),
        (Int64(bitPattern: 0xfffffffffffff897), Int64(bitPattern: 0xfffffffffffff897), Int64(0)),
    ])
    func REMW(_ x3: Int64, _ x2: Int64, _ x1: Int64) throws {
        try ALU(0x021161bb, x1, x2, x3)
    }

    @Test("x64-REMU: x3 = (unsign x2) % (unsign x1)", arguments: [
        (Int64(2), Int64(20), Int64(6)),
        (Int64(2), Int64(-20), Int64(6)),
        (Int64(20), Int64(20), Int64(-6)),
        (Int64(-20), Int64(-20), Int64(-6)),
        (Int64(0), Int64(bitPattern: 0x8000000000000000), Int64(1)),
        (Int64(bitPattern: 0x8000000000000000), Int64(bitPattern: 0x8000000000000000), Int64(-1)),
        (Int64(bitPattern: 0x8000000000000000), Int64(bitPattern: 0x8000000000000000), Int64(0)),
        (Int64(1), Int64(1), Int64(0)),
        (Int64(0), Int64(0), Int64(0)),
    ])
    func REMU(_ x3: Int64, _ x2: Int64, _ x1: Int64) throws {
        try ALU(0x021171b3, x1, x2, x3)
    }

    @Test("REMUW: x3 = unsign x2 % unsign x1", arguments: [
        (Int64(2), Int64(20), Int64(6)),
        (Int64(2), Int64(-20), Int64(6)),
        (Int64(20), Int64(20), Int64(-6)),
        (Int64(-20), Int64(-20), Int64(-6)),
        (Int64(0), Int64(Int32.min), Int64(1)),
        (Int64(Int32.min), Int64(Int32.min), Int64(-1)),
        (Int64(Int32.min), Int64(Int32.min), Int64(0)),
        (Int64(1), Int64(1), Int64(0)),
        (Int64(0), Int64(0), Int64(0)),
    ])
    func REMUW(_ x3: Int64, _ x2: Int64, _ x1: Int64) throws {
        try ALU(0x021171bb, x1, x2, x3)
    }

    // REMUW must use only the low 32 bits of each operand (upper bits ignored).
    @Test("REMUW: only low 32 bits", arguments: [
        (Int64(5), Int64(0x0000000100000005), Int64(100)),
        (Int64(5), Int64(0x0000000200000005), Int64(0x0000000100000000)),
    ])
    func REMUW_lowBits(_ x3: Int64, _ x2: Int64, _ x1: Int64) throws {
        try ALU(0x021171bb, x1, x2, x3)
    }
}
