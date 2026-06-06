import Testing

import RISCV

//===============================================
// ALU tests
struct RV32iALUTests {
    // ALU helper:
    // init RV32i machine, PC=0x80000000, set x1/x2, decode+execute instr,
    // assert x1/x2 unchanged, x3 == expected, PC == addr+4.
    func ALU(_ instr: Int32, _ x1: Int64, _ x2: Int64, _ x3: Int64) throws {
        // Init MachineState
        let addr: Int64 = 0x80000000
        var mstate = InitMachineState(.empty, .RV32i, true)
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

    @Test("ADD: x3 = x2 + x1", arguments: [
        (Int64(10), Int64(20), Int64(30)),
        (Int64(0), Int64(20), Int64(20)),
        (Int64(-10), Int64(20), Int64(10)),
        (Int64(-40), Int64(20), Int64(-20)),
        (Int64(-1), Int64(10), Int64(9)), // Overflow (0xFFFFFFFF)
    ])
    func ADD(_ x1: Int64, _ x2: Int64, _ x3: Int64) throws {
        try ALU(0x001101b3, x1, x2, x3)
    }

    @Test("SUB: x3 = x2 - x1", arguments: [
        (Int64(20), Int64(10), Int64(-10)),
        (Int64(10), Int64(20), Int64(10)),
        (Int64(0), Int64(20), Int64(20)),
        (Int64(10), Int64(0), Int64(-10)),
        (Int64(-10), Int64(-20), Int64(-10)),
        (Int64(10), Int64(-20), Int64(-30)),
        (Int64(10), Int64(-1), Int64(-11)), // x2 = 0xFFFFFFFF
        (Int64(-1), Int64(10), Int64(11)),  // Overflow (x1 = 0xFFFFFFFF)
    ])
    func SUB(_ x1: Int64, _ x2: Int64, _ x3: Int64) throws {
        try ALU(0x401101b3, x1, x2, x3)
    }

    @Test("SLL: x3 = x2 << x1", arguments: [
        (Int64(5), Int64(0b101101), Int64(0b10110100000)),
        (Int64(0), Int64(0b101101), Int64(0b101101)),
        // Edge cases: RV32 uses only the low 5 bits of the shift amount (rs2[4:0], mask 0x1f)
        (Int64(32), Int64(0b101101), Int64(0b101101)),    // 32 & 0x1f = 0 -> value unchanged (regression case)
        (Int64(33), Int64(0b101101), Int64(0b1011010)),   // 33 & 0x1f = 1
        (Int64(31), Int64(1), Int64(Int32.min)),          // shift into the sign bit (0x80000000)
        (Int64(63), Int64(1), Int64(Int32.min)),          // bit 5 masked off: 63 & 0x1f = 31 (0x80000000)
        (Int64(37), Int64(1), Int64(32)),                 // arbitrary high bits masked: 37 & 0x1f = 5
        (Int64(1), Int64(-1), Int64(Int32(bitPattern: 0xFFFFFFFE))), // overflow shifted off the top (32-bit result), x2 = 0xFFFFFFFF
    ])
    func SLL(_ x1: Int64, _ x2: Int64, _ x3: Int64) throws {
        try ALU(0x001111b3, x1, x2, x3)
    }

    @Test("SLT: x3 = x2 < x1", arguments: [
        (Int64(10), Int64(20), Int64(0)),
        (Int64(20), Int64(20), Int64(0)),
        (Int64(20), Int64(10), Int64(1)),
        (Int64(20), Int64(-10), Int64(1)),
        (Int64(-5), Int64(-10), Int64(1)),
        (Int64(-10), Int64(10), Int64(0)),
    ])
    func SLT(_ x1: Int64, _ x2: Int64, _ x3: Int64) throws {
        try ALU(0x001121b3, x1, x2, x3)
    }

    @Test("SLTU: x3 = unsign x2 < unsign x1", arguments: [
        (Int64(10), Int64(20), Int64(0)),
        (Int64(20), Int64(20), Int64(0)),
        (Int64(20), Int64(10), Int64(1)),
        (Int64(20), Int64(-10), Int64(0)),
        (Int64(-5), Int64(-10), Int64(1)),
        (Int64(-10), Int64(10), Int64(1)),
    ])
    func SLTU(_ x1: Int64, _ x2: Int64, _ x3: Int64) throws {
        try ALU(0x001131b3, x1, x2, x3)
    }

    @Test("XOR: x3 = x2 ^ x1", arguments: [
        (Int64(0b101), Int64(0b101), Int64(0)),
        (Int64(0b101), Int64(0b010), Int64(0b111)),
        (Int64(0b101), Int64(0b011), Int64(0b110)),
        (Int64(0b101), Int64(0b1000), Int64(0b1101)),
        (Int64(0b101), Int64(0b1011), Int64(0b1110)),
    ])
    func XOR(_ x1: Int64, _ x2: Int64, _ x3: Int64) throws {
        try ALU(0x001141b3, x1, x2, x3)
    }

    @Test("SRL: x3 = x2 >> x1", arguments: [
        (Int64(0b101), Int64(0b1011001101), Int64(0b0000010110)),
        (Int64(0b101), Int64(0b11001100101), Int64(0b00000110011)),
        (Int64(0b101), Int64(Int32(bitPattern: 0b11110000111100000000000000001111)), Int64(0b00000111100001111000000000000000)),
        // Edge cases: logical (zero-fill) shift, shift amount masked to rs2[4:0]
        (Int64(32), Int64(0b1011001101), Int64(0b1011001101)), // 32 & 0x1f = 0 -> value unchanged
        (Int64(33), Int64(0b1011001101), Int64(0b101100110)),  // 33 & 0x1f = 1
        (Int64(1), Int64(-1), Int64(0x7FFFFFFF)),              // zero-fill, not sign-fill, x2 = 0xFFFFFFFF
        (Int64(33), Int64(-1), Int64(0x7FFFFFFF)),             // 33 & 0x1f = 1 (same as shift 1), x2 = 0xFFFFFFFF
        (Int64(63), Int64(Int32.min), Int64(1)),              // 63 & 0x1f = 31, x2 = 0x80000000
        (Int64(37), Int64(-1), Int64(0x07FFFFFF)),            // 37 & 0x1f = 5, x2 = 0xFFFFFFFF
    ])
    func SRL(_ x1: Int64, _ x2: Int64, _ x3: Int64) throws {
        try ALU(0x001151b3, x1, x2, x3)
    }

    @Test("SRA: x3 = x2 >> x1", arguments: [
        (Int64(0b101), Int64(0b1011001101), Int64(0b0000010110)),
        (Int64(0b101), Int64(Int32(bitPattern: 0b11110000111100000000000000001111)), Int64(Int32(bitPattern: 0b11111111100001111000000000000000))),
        // Edge cases: arithmetic (sign-fill) shift, shift amount masked to rs2[4:0]
        (Int64(32), Int64(0x40000000), Int64(0x40000000)), // 32 & 0x1f = 0 -> value unchanged (regression case)
        (Int64(33), Int64(0x40000000), Int64(0x20000000)), // 33 & 0x1f = 1
        (Int64(1), Int64(-1), Int64(-1)),                  // sign-fill: -1 >> 1 stays -1, x2 = 0xFFFFFFFF
        (Int64(33), Int64(-1), Int64(-1)),                 // 33 & 0x1f = 1 (same as shift 1), x2 = 0xFFFFFFFF
        (Int64(31), Int64(Int32.min), Int64(-1)),          // sign bit smeared across the word, x2 = 0x80000000
        (Int64(63), Int64(Int32.min), Int64(-1)),          // 63 & 0x1f = 31, x2 = 0x80000000
        (Int64(37), Int64(0x40000000), Int64(0x2000000)),  // 37 & 0x1f = 5
    ])
    func SRA(_ x1: Int64, _ x2: Int64, _ x3: Int64) throws {
        try ALU(0x401151b3, x1, x2, x3)
    }

    @Test("OR: x3 = x2 | x1", arguments: [
        (Int64(0b101), Int64(0b101), Int64(0b101)),
        (Int64(0b101), Int64(0b110), Int64(0b111)),
        (Int64(0b101), Int64(0b011), Int64(0b111)),
        (Int64(0b101), Int64(0b1111), Int64(0b1111)),
        (Int64(0b101), Int64(0b1101), Int64(0b1101)),
    ])
    func OR(_ x1: Int64, _ x2: Int64, _ x3: Int64) throws {
        try ALU(0x001161b3, x1, x2, x3)
    }

    @Test("AND: x3 = x2 & x1", arguments: [
        (Int64(0b101), Int64(0b101), Int64(0b101)),
        (Int64(0b101), Int64(0b111), Int64(0b101)),
        (Int64(0b101), Int64(0b110), Int64(0b100)),
        (Int64(0b101), Int64(0b1011), Int64(0b0001)),
    ])
    func AND(_ x1: Int64, _ x2: Int64, _ x3: Int64) throws {
        try ALU(0x001171b3, x1, x2, x3)
    }
}
