import Testing

import RISCV

//===============================================
// ALU Immediate tests
struct RV32iALUITests {
    func ALUimmediate(_ instr: UInt32, _ x2: Int64, _ x3: Int64) throws {
        // Init MachineState
        let addr: Int64 = 0x80000000
        var mstate = InitMachineState(.empty, .RV32i, true)
        mstate = mstate.setPC(addr)
        mstate = mstate.setRegister(2, x2)

        let executor = try #require(Decoder.Decode(mstate, Int32(bitPattern: instr)))
        mstate = executor(mstate)
        #expect(mstate.getRegister(2) == x2)
        #expect(mstate.getRegister(3) == x3)
        #expect(mstate.PC == addr + 4)
    }

    @Test("ADDI: x3 = x2 + 5", arguments: [
        (Int64(5), Int64(10)),
        (Int64(-5), Int64(0)),
        (Int64(-10), Int64(-5)),
    ])
    func ADDI(_ x2: Int64, _ x3: Int64) throws {
        try ALUimmediate(0x00510193, x2, x3)
    }

    @Test("SLTI: x3 = x2 < 5", arguments: [
        (Int64(5), Int64(0)),
        (Int64(10), Int64(0)),
        (Int64(4), Int64(1)),
        (Int64(0), Int64(1)),
        (Int64(-4), Int64(1)),
        (Int64(-5), Int64(1)),
        (Int64(-10), Int64(1)),
    ])
    func SLTI(_ x2: Int64, _ x3: Int64) throws {
        try ALUimmediate(0x00512193, x2, x3)
    }

    @Test("SLTIU: x3 = unsign x2 < unsign 5", arguments: [
        (Int64(5), Int64(0)),
        (Int64(10), Int64(0)),
        (Int64(4), Int64(1)),
        (Int64(0), Int64(1)),
        (Int64(-4), Int64(0)),
        (Int64(-5), Int64(0)),
        (Int64(-10), Int64(0)),
    ])
    func SLTIU(_ x2: Int64, _ x3: Int64) throws {
        try ALUimmediate(0x00513193, x2, x3)
    }

    @Test("XORI: x3 = x2 ^ 5 (b101)", arguments: [
        (Int64(0b101), Int64(0)),
        (Int64(0b010), Int64(0b111)),
        (Int64(0b011), Int64(0b110)),
        (Int64(0b1000), Int64(0b1101)),
        (Int64(0b1011), Int64(0b1110)),
    ])
    func XORI(_ x2: Int64, _ x3: Int64) throws {
        try ALUimmediate(0x00514193, x2, x3)
    }

    @Test("ORI: x3 = x2 | 5 (b101)", arguments: [
        (Int64(0b101), Int64(0b101)),
        (Int64(0b110), Int64(0b111)),
        (Int64(0b011), Int64(0b111)),
        (Int64(0b1111), Int64(0b1111)),
        (Int64(0b1101), Int64(0b1101)),
    ])
    func ORI(_ x2: Int64, _ x3: Int64) throws {
        try ALUimmediate(0x00516193, x2, x3)
    }

    @Test("ANDI: x3 = x2 & 5 (b101)", arguments: [
        (Int64(0b101), Int64(0b101)),
        (Int64(0b111), Int64(0b101)),
        (Int64(0b110), Int64(0b100)),
        (Int64(0b1011), Int64(0b0001)),
    ])
    func ANDI(_ x2: Int64, _ x3: Int64) throws {
        try ALUimmediate(0x00517193, x2, x3)
    }

    @Test("SLLI: x3 = x2 << 5 (b101)", arguments: [
        (Int64(0b11001101), Int64(0b1100110100000)),
        (Int64(0b11001110), Int64(0b1100111000000)),
    ])
    func SLLI(_ x2: Int64, _ x3: Int64) throws {
        try ALUimmediate(0x00511193, x2, x3)
    }

    @Test("SRLI: x3 = x2 >> 5 (b101)", arguments: [
        (Int64(0b1011001101), Int64(0b0000010110)),
        (Int64(0b11001100101), Int64(0b00000110011)),
        (Int64(Int32(bitPattern: 0b11110000111100000000000000001111)), Int64(0b00000111100001111000000000000000)),
    ])
    func SRLI(_ x2: Int64, _ x3: Int64) throws {
        try ALUimmediate(0x00515193, x2, x3)
    }

    @Test("SRAI: x3 = x2 >> 5 (b101)", arguments: [
        (Int64(0b1011001101), Int64(0b0000010110)),
        (Int64(Int32(bitPattern: 0b11110000111100000000000000001111)), Int64(Int32(bitPattern: 0b11111111100001111000000000000000))),
    ])
    func SRAI(_ x2: Int64, _ x3: Int64) throws {
        try ALUimmediate(0x40515193, x2, x3)
    }
}
