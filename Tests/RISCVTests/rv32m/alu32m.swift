import Testing

import RISCV

//===============================================
// ALU tests
struct RV32mALUTests {
    // ALU helper:
    // init RV32im machine, PC=0x80000000, set x1/x2, decode+execute instr,
    // assert x1/x2 unchanged, x3 == expected, PC == addr+4.
    func ALU(_ instr: Int32, _ x1: Int64, _ x2: Int64, _ x3: Int64) throws {
        // Init MachineState
        let addr: Int64 = 0x80000000
        var mstate = InitMachineState(.empty, .RV32im, true)
        mstate = mstate.setPC(addr)
        mstate = mstate.setRegister(1, x1)
        mstate = mstate.setRegister(2, x2)

        let executor = try #require(Decoder.Decode(mstate, instr))
        mstate = executor(mstate)
        #expect(mstate.getRegister(1) == x1)
        #expect(mstate.getRegister(2) == x2)
        #expect(mstate.getRegister(3) == x3)
        #expect(mstate.PC == addr + 4)
    }

    // F# header: (x3, x1, x2). Tuples here are (x1, x2, x3).
    @Test("MUL: x3 = x2 * x1", arguments: [
        (Int64(10), Int64(20), Int64(200)),
        (Int64(20), Int64(0), Int64(0)),
        (Int64(-10), Int64(20), Int64(-200)),
        (Int64(10), Int64(-20), Int64(-200)),
        (Int64(-10), Int64(-20), Int64(200)),
        (Int64(Int32(bitPattern: 0xFFFFFFFF)), Int64(10), Int64(-10)),
        (Int64(-10), Int64(0), Int64(0)),
        (Int64(Int32.min), Int64(-1), Int64(Int32.min)),
        (Int64(Int32.min), Int64(1), Int64(Int32.min)),
        (Int64(Int32.min), Int64(-10), Int64(0)),
        (Int64(Int32.min), Int64(10), Int64(0)),
        (Int64(0x7FFFFFFF), Int64(10), Int64(-10)),
        (Int64(10), Int64(0x7FFFFFFF), Int64(-10)),
        (Int64(0x7FFFFFFF), Int64(Int32.min), Int64(Int32.min)),
        (Int64(0x7FFFFFFF), Int64(0x7FFFFFFF), Int64(1)),
        (Int64(Int32.min), Int64(Int32.min), Int64(0)),
        (Int64(0x00007e00), Int64(Int32(bitPattern: 0xb6db6db7)), Int64(0x00001200)),
        (Int64(0x00007fc0), Int64(Int32(bitPattern: 0xb6db6db7)), Int64(0x00001240)),
        (Int64(0x00000000), Int64(0x00000000), Int64(0x00000000)),
        (Int64(0x00000001), Int64(0x00000001), Int64(0x00000001)),
        (Int64(0x00000003), Int64(0x00000007), Int64(0x00000015)),
        (Int64(0x00000000), Int64(Int32(bitPattern: 0xffff8000)), Int64(0x00000000)),
        (Int64(Int32.min), Int64(0x00000000), Int64(0x00000000)),
        (Int64(Int32.min), Int64(Int32(bitPattern: 0xffff8000)), Int64(0x00000000)),
        (Int64(Int32(bitPattern: 0xaaaaaaab)), Int64(0x0002fe7d), Int64(0x0000ff7f)),
        (Int64(0x0002fe7d), Int64(Int32(bitPattern: 0xaaaaaaab)), Int64(0x0000ff7f)),
        (Int64(Int32(bitPattern: 0xff000000)), Int64(Int32(bitPattern: 0xff000000)), Int64(0x00000000)),
        (Int64(Int32(bitPattern: 0xffffffff)), Int64(Int32(bitPattern: 0xffffffff)), Int64(0x00000001)),
        (Int64(Int32(bitPattern: 0xffffffff)), Int64(0x00000001), Int64(Int32(bitPattern: 0xffffffff))),
        (Int64(0x00000001), Int64(Int32(bitPattern: 0xffffffff)), Int64(Int32(bitPattern: 0xffffffff))),
    ])
    func MUL(_ x1: Int64, _ x2: Int64, _ x3: Int64) throws {
        try ALU(0x021101b3, x1, x2, x3)
    }

    // F# header: (x3, x1, x2). Tuples here are (x1, x2, x3).
    @Test("MULH: x3 = half (x2 * x1)", arguments: [
        (Int64(0x00000000), Int64(0x00000000), Int64(0x00000000)),
        (Int64(0x00000001), Int64(0x00000001), Int64(0x00000000)),
        (Int64(0x00000003), Int64(0x00000007), Int64(0x00000000)),
        (Int64(0x00000000), Int64(Int32(bitPattern: 0xffff8000)), Int64(0x00000000)),
        (Int64(Int32.min), Int64(0x00000000), Int64(0x00000000)),
        (Int64(Int32(bitPattern: 0xaaaaaaab)), Int64(0x0002fe7d), Int64(Int32(bitPattern: 0xffff0081))),
        (Int64(0x0002fe7d), Int64(Int32(bitPattern: 0xaaaaaaab)), Int64(Int32(bitPattern: 0xffff0081))),
        (Int64(Int32(bitPattern: 0xff000000)), Int64(Int32(bitPattern: 0xff000000)), Int64(0x00010000)),
        (Int64(Int32(bitPattern: 0xffffffff)), Int64(Int32(bitPattern: 0xffffffff)), Int64(0x00000000)),
        (Int64(Int32(bitPattern: 0xffffffff)), Int64(0x00000001), Int64(Int32(bitPattern: 0xffffffff))),
        (Int64(0x00000001), Int64(Int32(bitPattern: 0xffffffff)), Int64(Int32(bitPattern: 0xffffffff))),
    ])
    func MULH(_ x1: Int64, _ x2: Int64, _ x3: Int64) throws {
        try ALU(0x021111b3, x1, x2, x3)
    }

    // F# header: (x3, x2, x1). Tuples here are (x1, x2, x3).
    @Test("MULHSU: x3 = half (sign x2 * unsign x1)", arguments: [
        (Int64(0x00000000), Int64(0x00000000), Int64(0x00000000)),
        (Int64(0x00000001), Int64(0x00000001), Int64(0x00000000)),
        (Int64(0x00000007), Int64(0x00000003), Int64(0x00000000)),
        (Int64(Int32(bitPattern: 0xffff8000)), Int64(0x00000000), Int64(0x00000000)),
        (Int64(0x00000000), Int64(Int32.min), Int64(0x00000000)),
        (Int64(Int32(bitPattern: 0xffff8000)), Int64(Int32.min), Int64(Int32(bitPattern: 0x80004000))),
        (Int64(0x0002fe7d), Int64(Int32(bitPattern: 0xaaaaaaab)), Int64(Int32(bitPattern: 0xffff0081))),
        (Int64(Int32(bitPattern: 0xaaaaaaab)), Int64(0x0002fe7d), Int64(0x0001fefe)),
        (Int64(Int32(bitPattern: 0xff000000)), Int64(Int32(bitPattern: 0xff000000)), Int64(Int32(bitPattern: 0xff010000))),
        (Int64(Int32(bitPattern: 0xffffffff)), Int64(Int32(bitPattern: 0xffffffff)), Int64(Int32(bitPattern: 0xffffffff))),
        (Int64(0x00000001), Int64(Int32(bitPattern: 0xffffffff)), Int64(Int32(bitPattern: 0xffffffff))),
        (Int64(Int32(bitPattern: 0xffffffff)), Int64(0x00000001), Int64(0x00000000)),
    ])
    func MULHSU(_ x1: Int64, _ x2: Int64, _ x3: Int64) throws {
        try ALU(0x021121b3, x1, x2, x3)
    }

    // F# header: (x3, x1, x2). Tuples here are (x1, x2, x3).
    @Test("MULHU: x3 = half (unsign x2 * unsign x1)", arguments: [
        (Int64(0x00000000), Int64(0x00000000), Int64(0x00000000)),
        (Int64(0x00000001), Int64(0x00000001), Int64(0x00000000)),
        (Int64(0x00000003), Int64(0x00000007), Int64(0x00000000)),
        (Int64(0x00000000), Int64(Int32(bitPattern: 0xffff8000)), Int64(0x00000000)),
        (Int64(Int32.min), Int64(0x00000000), Int64(0x00000000)),
        (Int64(Int32.min), Int64(Int32(bitPattern: 0xffff8000)), Int64(0x7fffc000)),
        (Int64(Int32(bitPattern: 0xaaaaaaab)), Int64(0x0002fe7d), Int64(0x0001fefe)),
        (Int64(0x0002fe7d), Int64(Int32(bitPattern: 0xaaaaaaab)), Int64(0x0001fefe)),
        (Int64(Int32(bitPattern: 0xff000000)), Int64(Int32(bitPattern: 0xff000000)), Int64(Int32(bitPattern: 0xfe010000))),
        (Int64(Int32(bitPattern: 0xffffffff)), Int64(Int32(bitPattern: 0xffffffff)), Int64(Int32(bitPattern: 0xfffffffe))),
        (Int64(Int32(bitPattern: 0xffffffff)), Int64(0x00000001), Int64(0x00000000)),
        (Int64(0x00000001), Int64(Int32(bitPattern: 0xffffffff)), Int64(0x00000000)),
    ])
    func MULHU(_ x1: Int64, _ x2: Int64, _ x3: Int64) throws {
        try ALU(0x021131b3, x1, x2, x3)
    }

    // F# header: (x3, x2, x1). Tuples here are (x1, x2, x3).
    @Test("DIV: x3 = x2 / x1", arguments: [
        (Int64(2), Int64(4), Int64(2)),
        (Int64(2), Int64(5), Int64(2)),
        (Int64(2), Int64(6), Int64(3)),
        (Int64(4), Int64(15), Int64(3)),
        (Int64(3), Int64(-1), Int64(0)),
        (Int64(-3), Int64(1), Int64(0)),
        (Int64(-2), Int64(4), Int64(-2)),
        (Int64(2), Int64(-4), Int64(-2)),
        (Int64(-2), Int64(-4), Int64(2)),
        (Int64(2), Int64(0), Int64(0)),
        (Int64(0), Int64(2), Int64(-1)),
        (Int64(-1), Int64(Int32.min), Int64(Int32.min)),
        (Int64(1), Int64(Int32.min), Int64(Int32.min)),
        (Int64(0), Int64(Int32.min), Int64(-1)),
        (Int64(0), Int64(1), Int64(-1)),
        (Int64(0), Int64(0), Int64(-1)),
    ])
    func DIV(_ x1: Int64, _ x2: Int64, _ x3: Int64) throws {
        try ALU(0x021141b3, x1, x2, x3)
    }

    // F# header: (x3, x2, x1). Tuples here are (x1, x2, x3).
    @Test("DIVU: x3 = (unsign x2) / (unsign x1)", arguments: [
        (Int64(2), Int64(4), Int64(2)),
        (Int64(2), Int64(5), Int64(2)),
        (Int64(2), Int64(6), Int64(3)),
        (Int64(4), Int64(15), Int64(3)),
        (Int64(3), Int64(1), Int64(0)),
        (Int64(3), Int64(-1), Int64(0x55555555)),
        (Int64(-3), Int64(1), Int64(0)),
        (Int64(-2), Int64(4), Int64(0)),
        (Int64(6), Int64(-20), Int64(715827879)),
        (Int64(-2), Int64(-4), Int64(0)),
        (Int64(2), Int64(0), Int64(0)),
        (Int64(0), Int64(2), Int64(Int32(bitPattern: 0xFFFFFFFF))),
        (Int64(2), Int64(-10), Int64(0x7FFFFFFB)),
        (Int64(1), Int64(Int32.min), Int64(Int32.min)),
        (Int64(-1), Int64(Int32.min), Int64(0)),
        (Int64(0), Int64(Int32.min), Int64(-1)),
    ])
    func DIVU(_ x1: Int64, _ x2: Int64, _ x3: Int64) throws {
        try ALU(0x021151b3, x1, x2, x3)
    }

    // F# header: (x3, x2, x1). Tuples here are (x1, x2, x3).
    @Test("REM: x3 = x2 % x1", arguments: [
        (Int64(6), Int64(20), Int64(2)),
        (Int64(6), Int64(-20), Int64(-2)),
        (Int64(-6), Int64(20), Int64(2)),
        (Int64(-6), Int64(-20), Int64(-2)),
        (Int64(1), Int64(Int32.min), Int64(0)),
        (Int64(-1), Int64(Int32.min), Int64(0)),
        (Int64(0), Int64(Int32.min), Int64(Int32.min)),
        (Int64(0), Int64(1), Int64(1)),
        (Int64(0), Int64(0), Int64(0)),
    ])
    func REM(_ x1: Int64, _ x2: Int64, _ x3: Int64) throws {
        try ALU(0x021161b3, x1, x2, x3)
    }

    // F# header: (x3, x2, x1). Tuples here are (x1, x2, x3).
    @Test("REMU: x3 = (unsign x2) % (unsign x1)", arguments: [
        (Int64(6), Int64(20), Int64(2)),
        (Int64(6), Int64(-20), Int64(2)),
        (Int64(-6), Int64(20), Int64(20)),
        (Int64(-6), Int64(-20), Int64(-20)),
        (Int64(1), Int64(Int32.min), Int64(0)),
        (Int64(-1), Int64(Int32.min), Int64(Int32.min)),
        (Int64(0), Int64(Int32.min), Int64(Int32.min)),
        (Int64(0), Int64(1), Int64(1)),
        (Int64(0), Int64(0), Int64(0)),
    ])
    func REMU(_ x1: Int64, _ x2: Int64, _ x3: Int64) throws {
        try ALU(0x021171b3, x1, x2, x3)
    }
}
