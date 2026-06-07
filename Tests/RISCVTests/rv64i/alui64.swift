import Testing

import RISCV

//===============================================
// ALU Immediate Word tests
struct RV64iALUITests {
    func ALUimmediate(_ instr: UInt32, _ x2: Int64, _ x3: Int64) throws {
        // Init MachineState
        let addr: Int64 = 0x80000000
        var mstate = InitMachineState(.empty, .RV64i, true)
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
        (Int64(bitPattern: 0x8FAFCF1F8AF300C7), Int64(bitPattern: 0xf5f9e3f15e6018e0)),
        (Int64(0x00AFCF1F8AF300C7), Int64(0x15f9e3f15e6018e0)),
    ])
    func SLLI(_ x2: Int64, _ x3: Int64) throws {
        try ALUimmediate(0x00511193, x2, x3)
    }

    @Test("SRLI: x3 = x2 >> 5 (b101)", arguments: [
        (Int64(0b1011001101), Int64(0b0000010110)),
        (Int64(0b11001100101), Int64(0b00000110011)),
        (Int64(Int32(bitPattern: 0b11110000111100000000000000001111)), Int64(0x7ffffffff878000)),
        (Int64(bitPattern: 0x8FAFCF1F8AF300C7), Int64(0x47d7e78fc579806)),
        (Int64(bitPattern: 0xFFDFCF1F8AF300C7), Int64(0x7fefe78fc579806)),
    ])
    func SRLI(_ x2: Int64, _ x3: Int64) throws {
        try ALUimmediate(0x00515193, x2, x3)
    }

    @Test("SRAI: x3 = x2 >> 5 (b101)", arguments: [
        (Int64(0b1011001101), Int64(0b0000010110)),
        (Int64(Int32(bitPattern: 0b11110000111100000000000000001111)), Int64(Int32(bitPattern: 0b11111111100001111000000000000000))),
        (Int64(0x0FAFCF1F8AF300C7), Int64(0x7d7e78fc579806)),
        (Int64(bitPattern: 0x8FAFCF1F8AF300C7), Int64(bitPattern: 0xfc7d7e78fc579806)),
    ])
    func SRAI(_ x2: Int64, _ x3: Int64) throws {
        try ALUimmediate(0x40515193, x2, x3)
    }

    // RV64 shift-immediates use a 6-bit shamt (rs2[5:0]); exercise shamt 32 and 63.
    @Test("SLLI: x3 = x2 << 32", arguments: [
        (Int64(1), Int64(0x100000000)),
    ])
    func SLLI_32(_ x2: Int64, _ x3: Int64) throws {
        try ALUimmediate(0x02011193, x2, x3)
    }

    @Test("SLLI: x3 = x2 << 63", arguments: [
        (Int64(1), Int64(bitPattern: 0x8000000000000000)),
    ])
    func SLLI_63(_ x2: Int64, _ x3: Int64) throws {
        try ALUimmediate(0x03f11193, x2, x3)
    }

    @Test("SRLI: x3 = x2 >> 32", arguments: [
        (Int64(bitPattern: 0xFFFFFFFF00000000), Int64(0xFFFFFFFF)),
    ])
    func SRLI_32(_ x2: Int64, _ x3: Int64) throws {
        try ALUimmediate(0x02015193, x2, x3)
    }

    @Test("SRLI: x3 = x2 >> 63", arguments: [
        (Int64(bitPattern: 0x8000000000000000), Int64(1)),
    ])
    func SRLI_63(_ x2: Int64, _ x3: Int64) throws {
        try ALUimmediate(0x03f15193, x2, x3)
    }

    @Test("SRAI: x3 = x2 >> 32", arguments: [
        (Int64(bitPattern: 0x8000000000000000), Int64(bitPattern: 0xFFFFFFFF80000000)),
        (Int64(0x7FFFFFFF00000000), Int64(0x7FFFFFFF)),
    ])
    func SRAI_32(_ x2: Int64, _ x3: Int64) throws {
        try ALUimmediate(0x42015193, x2, x3)
    }

    @Test("SRAI: x3 = x2 >> 63", arguments: [
        (Int64(bitPattern: 0x8000000000000000), Int64(-1)),
    ])
    func SRAI_63(_ x2: Int64, _ x3: Int64) throws {
        try ALUimmediate(0x43f15193, x2, x3)
    }
}
