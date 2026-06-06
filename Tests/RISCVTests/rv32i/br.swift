import Testing

import RISCV

//===============================================
// Branch tests
@Suite struct RV32iBranchTests {
    func Branch(_ instr: UInt32, _ x1: Int64, _ x2: Int64, _ resultAddr: Int64) throws {
        // Init MachineState
        let addr: Int64 = 0x80000000
        var mstate = InitMachineState(.empty, .RV32i, true)
        mstate = mstate.setPC(addr)
        mstate = mstate.setRegister(1, x1)
        mstate = mstate.setRegister(2, x2)

        let executor = try #require(Decoder.Decode(mstate, Int32(bitPattern: instr)))
        mstate = executor(mstate)
        #expect(mstate.getRegister(1) == x1)
        #expect(mstate.getRegister(2) == x2)
        #expect(mstate.PC == resultAddr)
    }

    @Test("BEQ: x1 == x2", arguments: [
        (UInt32(0x02208863), Int64(5), Int64(10), Int64(0x80000004)),
        (UInt32(0x02208863), Int64(5), Int64(-5), Int64(0x80000004)),
        (UInt32(0x02208863), Int64(5), Int64(5), Int64(0x80000030)),
        (UInt32(0x02208863), Int64(-5), Int64(-5), Int64(0x80000030)),
        (UInt32(0xfe208ee3), Int64(5), Int64(10), Int64(0x80000004)),
        (UInt32(0xfe208ee3), Int64(5), Int64(-5), Int64(0x80000004)),
        (UInt32(0xfe208ee3), Int64(5), Int64(5), Int64(0x7ffffffc)),
        (UInt32(0xfe208ee3), Int64(-5), Int64(-5), Int64(0x7ffffffc)),
    ])
    func BEQ(_ instr: UInt32, _ x1: Int64, _ x2: Int64, _ addrRes: Int64) throws {
        try Branch(instr, x1, x2, addrRes)
    }

    @Test("BNE: x1 <> x2", arguments: [
        (UInt32(0x02209463), Int64(5), Int64(10), Int64(0x80000028)),
        (UInt32(0x02209463), Int64(5), Int64(-5), Int64(0x80000028)),
        (UInt32(0x02209463), Int64(5), Int64(5), Int64(0x80000004)),
        (UInt32(0x02209463), Int64(-5), Int64(-5), Int64(0x80000004)),
        (UInt32(0xfe209ae3), Int64(5), Int64(10), Int64(0x7ffffff4)),
        (UInt32(0xfe209ae3), Int64(5), Int64(-5), Int64(0x7ffffff4)),
        (UInt32(0xfe209ae3), Int64(5), Int64(5), Int64(0x80000004)),
        (UInt32(0xfe209ae3), Int64(-5), Int64(-5), Int64(0x80000004)),
    ])
    func BNE(_ instr: UInt32, _ x1: Int64, _ x2: Int64, _ addrRes: Int64) throws {
        try Branch(instr, x1, x2, addrRes)
    }

    @Test("BLT: x1 < x2", arguments: [
        (UInt32(0x0220c063), Int64(5), Int64(10), Int64(0x80000020)),
        (UInt32(0x0220c063), Int64(-5), Int64(10), Int64(0x80000020)),
        (UInt32(0x0220c063), Int64(5), Int64(-5), Int64(0x80000004)),
        (UInt32(0x0220c063), Int64(5), Int64(5), Int64(0x80000004)),
        (UInt32(0x0220c063), Int64(-5), Int64(-5), Int64(0x80000004)),
        (UInt32(0x0220c063), Int64(-5), Int64(-1), Int64(0x80000020)),
        (UInt32(0x0220c063), Int64(-5), Int64(-10), Int64(0x80000004)),
        (UInt32(0xfe20c6e3), Int64(5), Int64(10), Int64(0x7fffffec)),
        (UInt32(0xfe20c6e3), Int64(-5), Int64(10), Int64(0x7fffffec)),
        (UInt32(0xfe20c6e3), Int64(5), Int64(-5), Int64(0x80000004)),
        (UInt32(0xfe20c6e3), Int64(5), Int64(5), Int64(0x80000004)),
        (UInt32(0xfe20c6e3), Int64(-5), Int64(-5), Int64(0x80000004)),
        (UInt32(0xfe20c6e3), Int64(-5), Int64(-1), Int64(0x7fffffec)),
        (UInt32(0xfe20c6e3), Int64(-5), Int64(-10), Int64(0x80000004)),
    ])
    func BLT(_ instr: UInt32, _ x1: Int64, _ x2: Int64, _ addrRes: Int64) throws {
        try Branch(instr, x1, x2, addrRes)
    }

    @Test("BGE: x1 >= x2", arguments: [
        (UInt32(0x0020dc63), Int64(5), Int64(10), Int64(0x80000004)),
        (UInt32(0x0020dc63), Int64(-5), Int64(10), Int64(0x80000004)),
        (UInt32(0x0020dc63), Int64(5), Int64(-5), Int64(0x80000018)),
        (UInt32(0x0020dc63), Int64(10), Int64(5), Int64(0x80000018)),
        (UInt32(0x0020dc63), Int64(5), Int64(5), Int64(0x80000018)),
        (UInt32(0x0020dc63), Int64(-5), Int64(-5), Int64(0x80000018)),
        (UInt32(0x0020dc63), Int64(-5), Int64(-1), Int64(0x80000004)),
        (UInt32(0x0020dc63), Int64(-5), Int64(-10), Int64(0x80000018)),
        (UInt32(0xfe20d2e3), Int64(5), Int64(10), Int64(0x80000004)),
        (UInt32(0xfe20d2e3), Int64(-5), Int64(10), Int64(0x80000004)),
        (UInt32(0xfe20d2e3), Int64(5), Int64(-5), Int64(0x7fffffe4)),
        (UInt32(0xfe20d2e3), Int64(10), Int64(5), Int64(0x7fffffe4)),
        (UInt32(0xfe20d2e3), Int64(5), Int64(5), Int64(0x7fffffe4)),
        (UInt32(0xfe20d2e3), Int64(-5), Int64(-5), Int64(0x7fffffe4)),
        (UInt32(0xfe20d2e3), Int64(-5), Int64(-1), Int64(0x80000004)),
        (UInt32(0xfe20d2e3), Int64(-5), Int64(-10), Int64(0x7fffffe4)),
    ])
    func BGE(_ instr: UInt32, _ x1: Int64, _ x2: Int64, _ addrRes: Int64) throws {
        try Branch(instr, x1, x2, addrRes)
    }

    @Test("BLTU: x1 < x2", arguments: [
        (UInt32(0x0020e863), Int64(5), Int64(10), Int64(0x80000010)),
        (UInt32(0x0020e863), Int64(5), Int64(5), Int64(0x80000004)),
        (UInt32(0x0020e863), Int64(0), Int64(10), Int64(0x80000010)),
        (UInt32(0x0020e863), Int64(-1), Int64(5), Int64(0x80000004)),
        (UInt32(0x0020e863), Int64(10), Int64(-1), Int64(0x80000010)),
        (UInt32(0x0020e863), Int64(-5), Int64(-1), Int64(0x80000010)),
        (UInt32(0xfc20eee3), Int64(5), Int64(10), Int64(0x7fffffdc)),
        (UInt32(0xfc20eee3), Int64(5), Int64(5), Int64(0x80000004)),
        (UInt32(0xfc20eee3), Int64(0), Int64(10), Int64(0x7fffffdc)),
        (UInt32(0xfc20eee3), Int64(-1), Int64(5), Int64(0x80000004)),
        (UInt32(0xfc20eee3), Int64(10), Int64(-1), Int64(0x7fffffdc)),
        (UInt32(0xfc20eee3), Int64(-5), Int64(-1), Int64(0x7fffffdc)),
    ])
    func BLTU(_ instr: UInt32, _ x1: Int64, _ x2: Int64, _ addrRes: Int64) throws {
        try Branch(instr, x1, x2, addrRes)
    }

    @Test("BGEU: x1 >= x2", arguments: [
        (UInt32(0x0020f463), Int64(5), Int64(10), Int64(0x80000004)),
        (UInt32(0x0020f463), Int64(10), Int64(5), Int64(0x80000008)),
        (UInt32(0x0020f463), Int64(5), Int64(5), Int64(0x80000008)),
        (UInt32(0x0020f463), Int64(-1), Int64(5), Int64(0x80000008)),
        (UInt32(0x0020f463), Int64(-1), Int64(-1), Int64(0x80000008)),
        (UInt32(0x0020f463), Int64(-1), Int64(-2), Int64(0x80000008)),
        (UInt32(0xfc20fae3), Int64(5), Int64(10), Int64(0x80000004)),
        (UInt32(0xfc20fae3), Int64(10), Int64(5), Int64(0x7fffffd4)),
        (UInt32(0xfc20fae3), Int64(5), Int64(5), Int64(0x7fffffd4)),
        (UInt32(0xfc20fae3), Int64(-1), Int64(5), Int64(0x7fffffd4)),
        (UInt32(0xfc20fae3), Int64(-1), Int64(-1), Int64(0x7fffffd4)),
        (UInt32(0xfc20fae3), Int64(-1), Int64(-2), Int64(0x7fffffd4)),
    ])
    func BGEU(_ instr: UInt32, _ x1: Int64, _ x2: Int64, _ addrRes: Int64) throws {
        try Branch(instr, x1, x2, addrRes)
    }
}
