import Testing

import RISCV

//===============================================
// ALU tests
struct RV64iALUTests {
    func ALU(_ instr: UInt32, _ x1: Int64, _ x2: Int64, _ x3: Int64) throws {
        // Init MachineState
        let addr: Int64 = 0x80000000
        var mstate = InitMachineState(MemoryMap.empty, .RV64i, true)
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

    @Test("ADD: x3 = x2 + x1", arguments: [
        (Int64(10), Int64(20), Int64(30)),
        (Int64(0), Int64(20), Int64(20)),
        (Int64(-10), Int64(20), Int64(10)),
        (Int64(-40), Int64(20), Int64(-20)),
        (Int64(-1), Int64(10), Int64(9)), // Overflow
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
        (Int64(10), Int64(-1), Int64(-11)),
        (Int64(-1), Int64(10), Int64(11)), // Overflow
    ])
    func SUB(_ x1: Int64, _ x2: Int64, _ x3: Int64) throws {
        try ALU(0x401101b3, x1, x2, x3)
    }

    @Test("SLL: x3 = x2 << x1", arguments: [
        (Int64(5), Int64(0b101101), Int64(0b10110100000)),
        (Int64(0), Int64(0b101101), Int64(0b101101)),
        (Int64(5), Int64(bitPattern: 0x8FAFCF1F8AF300C7), Int64(bitPattern: 0xf5f9e3f15e6018e0)),
        (Int64(5), Int64(0x00AFCF1F8AF300C7), Int64(0x15f9e3f15e6018e0)),
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
        (Int64(0b101), Int64(Int32(bitPattern: 0b11110000111100000000000000001111)), Int64(0x7ffffffff878000)),
        (Int64(0b101), Int64(bitPattern: 0x8FAFCF1F8AF300C7), Int64(0x47d7e78fc579806)),
        (Int64(0b101), Int64(bitPattern: 0xFFDFCF1F8AF300C7), Int64(0x7fefe78fc579806)),
    ])
    func SRL(_ x1: Int64, _ x2: Int64, _ x3: Int64) throws {
        try ALU(0x001151b3, x1, x2, x3)
    }

    @Test("SRA: x3 = x2 >> x1", arguments: [
        (Int64(0b101), Int64(0b1011001101), Int64(0b0000010110)),
        (Int64(0b101), Int64(Int32(bitPattern: 0b11110000111100000000000000001111)), Int64(Int32(bitPattern: 0b11111111100001111000000000000000))),
        (Int64(0b101), Int64(0x0FAFCF1F8AF300C7), Int64(0x7d7e78fc579806)),
        (Int64(0b101), Int64(bitPattern: 0x8FAFCF1F8AF300C7), Int64(bitPattern: 0xfc7d7e78fc579806)),
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
