import Testing

import RISCV

// Port of riscv-fs `Tests/rvc/c.fs` (the 'C' compressed extension tests) to Swift Testing.
//
// Scope deviation from the reference: the single-precision 'F' extension is NOT
// implemented in this port, so the FP-executing Zcf tests (C.FLW/C.FSW/C.FLWSP/
// C.FSWSP loads/stores, the Zcf runSteps program, and the Zcf verbosityMessage)
// are omitted. The Zcf *encoder* checks and *decode-gating* tests are kept, and
// because F is unavailable the Zcf encodings decode to None on every RV32 arch
// (including RV32ifc) — exactly the reference's own treatment of the Zcd set.
@Suite struct RVCTests {
    // ---- 16-bit C instruction encoders (spec bit layout; anchored by the canonical test) ----
    static func bit(_ v: Int32, _ pos: Int32) -> Int32 { (v & 1) << pos }
    static func fld(_ v: Int32, _ hi: Int32, _ lo: Int32) -> Int32 { (v & ((1 << (hi - lo + 1)) - 1)) << lo }
    static func cc(_ r: Int32) -> Int32 { r - 8 } // wide reg (x8..x15) -> 3-bit compressed field
    static func cjEnc(_ f3: Int32, _ imm: Int32) -> Int32 {
        fld(f3, 15, 13) | bit(imm >> 11, 12) | bit(imm >> 4, 11) | fld((imm >> 8) & 0x3, 10, 9) | bit(imm >> 10, 8)
            | bit(imm >> 6, 7) | bit(imm >> 7, 6) | fld((imm >> 1) & 0x7, 5, 3) | bit(imm >> 5, 2) | 0b01
    }
    static func cADDI4SPN(_ rd: Int32, _ imm: Int32) -> Int32 {
        fld(0b000, 15, 13) | fld((imm >> 6) & 0xf, 10, 7) | fld((imm >> 4) & 0x3, 12, 11) | bit(imm >> 3, 5) | bit(imm >> 2, 6) | fld(cc(rd), 4, 2)
    }
    static func cLW(_ rd: Int32, _ rs1: Int32, _ imm: Int32) -> Int32 {
        fld(0b010, 15, 13) | bit(imm >> 6, 5) | fld((imm >> 3) & 0x7, 12, 10) | bit(imm >> 2, 6) | fld(cc(rs1), 9, 7) | fld(cc(rd), 4, 2)
    }
    static func cSW(_ rs1: Int32, _ rs2: Int32, _ imm: Int32) -> Int32 {
        fld(0b110, 15, 13) | bit(imm >> 6, 5) | fld((imm >> 3) & 0x7, 12, 10) | bit(imm >> 2, 6) | fld(cc(rs1), 9, 7) | fld(cc(rs2), 4, 2)
    }
    static func cLD(_ rd: Int32, _ rs1: Int32, _ imm: Int32) -> Int32 {
        fld(0b011, 15, 13) | fld((imm >> 6) & 0x3, 6, 5) | fld((imm >> 3) & 0x7, 12, 10) | fld(cc(rs1), 9, 7) | fld(cc(rd), 4, 2)
    }
    static func cSD(_ rs1: Int32, _ rs2: Int32, _ imm: Int32) -> Int32 {
        fld(0b111, 15, 13) | fld((imm >> 6) & 0x3, 6, 5) | fld((imm >> 3) & 0x7, 12, 10) | fld(cc(rs1), 9, 7) | fld(cc(rs2), 4, 2)
    }
    static func cADDI(_ rd: Int32, _ imm: Int32) -> Int32 {
        fld(0b000, 15, 13) | bit(imm >> 5, 12) | fld(rd, 11, 7) | fld(imm & 0x1f, 6, 2) | 0b01
    }
    static func cADDIW(_ rd: Int32, _ imm: Int32) -> Int32 {
        fld(0b001, 15, 13) | bit(imm >> 5, 12) | fld(rd, 11, 7) | fld(imm & 0x1f, 6, 2) | 0b01
    }
    static func cJAL(_ imm: Int32) -> Int32 { cjEnc(0b001, imm) }
    static func cLI(_ rd: Int32, _ imm: Int32) -> Int32 {
        fld(0b010, 15, 13) | bit(imm >> 5, 12) | fld(rd, 11, 7) | fld(imm & 0x1f, 6, 2) | 0b01
    }
    static func cLUI(_ rd: Int32, _ n6: Int32) -> Int32 {
        fld(0b011, 15, 13) | bit(n6 >> 5, 12) | fld(rd, 11, 7) | fld(n6 & 0x1f, 6, 2) | 0b01
    }
    static func cADDI16SP(_ imm: Int32) -> Int32 {
        fld(0b011, 15, 13) | bit(imm >> 9, 12) | fld(2, 11, 7) | fld((imm >> 7) & 0x3, 4, 3) | bit(imm >> 6, 5) | bit(imm >> 5, 2) | bit(imm >> 4, 6) | 0b01
    }
    static func cSRLI(_ rd: Int32, _ shamt: Int32) -> Int32 {
        fld(0b100, 15, 13) | bit(shamt >> 5, 12) | fld(0b00, 11, 10) | fld(cc(rd), 9, 7) | fld(shamt & 0x1f, 6, 2) | 0b01
    }
    static func cSRAI(_ rd: Int32, _ shamt: Int32) -> Int32 {
        fld(0b100, 15, 13) | bit(shamt >> 5, 12) | fld(0b01, 11, 10) | fld(cc(rd), 9, 7) | fld(shamt & 0x1f, 6, 2) | 0b01
    }
    static func cANDI(_ rd: Int32, _ imm: Int32) -> Int32 {
        fld(0b100, 15, 13) | bit(imm >> 5, 12) | fld(0b10, 11, 10) | fld(cc(rd), 9, 7) | fld(imm & 0x1f, 6, 2) | 0b01
    }
    static func caEnc(_ b12: Int32, _ sub: Int32, _ rd: Int32, _ rs2: Int32) -> Int32 {
        fld(0b100, 15, 13) | (b12 << 12) | fld(0b11, 11, 10) | fld(cc(rd), 9, 7) | fld(sub, 6, 5) | fld(cc(rs2), 4, 2) | 0b01
    }
    static func cJ(_ imm: Int32) -> Int32 { cjEnc(0b101, imm) }
    static func cBEQZ(_ rs1: Int32, _ imm: Int32) -> Int32 {
        fld(0b110, 15, 13) | bit(imm >> 8, 12) | fld((imm >> 3) & 0x3, 11, 10) | fld(cc(rs1), 9, 7) | fld((imm >> 6) & 0x3, 6, 5) | fld((imm >> 1) & 0x3, 4, 3) | bit(imm >> 5, 2) | 0b01
    }
    static func cBNEZ(_ rs1: Int32, _ imm: Int32) -> Int32 {
        fld(0b111, 15, 13) | bit(imm >> 8, 12) | fld((imm >> 3) & 0x3, 11, 10) | fld(cc(rs1), 9, 7) | fld((imm >> 6) & 0x3, 6, 5) | fld((imm >> 1) & 0x3, 4, 3) | bit(imm >> 5, 2) | 0b01
    }
    static func cSLLI(_ rd: Int32, _ shamt: Int32) -> Int32 {
        fld(0b000, 15, 13) | bit(shamt >> 5, 12) | fld(rd, 11, 7) | fld(shamt & 0x1f, 6, 2) | 0b10
    }
    static func cLWSP(_ rd: Int32, _ imm: Int32) -> Int32 {
        fld(0b010, 15, 13) | fld((imm >> 6) & 0x3, 3, 2) | bit(imm >> 5, 12) | fld((imm >> 2) & 0x7, 6, 4) | fld(rd, 11, 7) | 0b10
    }
    static func cLDSP(_ rd: Int32, _ imm: Int32) -> Int32 {
        fld(0b011, 15, 13) | fld((imm >> 6) & 0x7, 4, 2) | bit(imm >> 5, 12) | fld((imm >> 3) & 0x3, 6, 5) | fld(rd, 11, 7) | 0b10
    }
    static func crEnc(_ b12: Int32, _ rd: Int32, _ rs2: Int32) -> Int32 {
        fld(0b100, 15, 13) | (b12 << 12) | fld(rd, 11, 7) | fld(rs2, 6, 2) | 0b10
    }
    static func cSWSP(_ rs2: Int32, _ imm: Int32) -> Int32 {
        fld(0b110, 15, 13) | fld((imm >> 6) & 0x3, 8, 7) | fld((imm >> 2) & 0xf, 12, 9) | fld(rs2, 6, 2) | 0b10
    }
    static func cSDSP(_ rs2: Int32, _ imm: Int32) -> Int32 {
        fld(0b111, 15, 13) | fld((imm >> 6) & 0x7, 9, 7) | fld((imm >> 3) & 0x7, 12, 10) | fld(rs2, 6, 2) | 0b10
    }

    // Zcf (RV32 + C + F): C.FLW / C.FSW / C.FLWSP / C.FSWSP.
    // Encoders mirror cLW/cSW/cLWSP/cSWSP with funct3 011/111 (the encodings that
    // are C.LD/C.SD/C.LDSP/C.SDSP on RV64).
    static func cFLW(_ rd: Int32, _ rs1: Int32, _ imm: Int32) -> Int32 {
        fld(0b011, 15, 13) | bit(imm >> 6, 5) | fld((imm >> 3) & 0x7, 12, 10) | bit(imm >> 2, 6) | fld(cc(rs1), 9, 7) | fld(cc(rd), 4, 2)
    }
    static func cFSW(_ rs1: Int32, _ rs2: Int32, _ imm: Int32) -> Int32 {
        fld(0b111, 15, 13) | bit(imm >> 6, 5) | fld((imm >> 3) & 0x7, 12, 10) | bit(imm >> 2, 6) | fld(cc(rs1), 9, 7) | fld(cc(rs2), 4, 2)
    }
    static func cFLWSP(_ rd: Int32, _ imm: Int32) -> Int32 {
        fld(0b011, 15, 13) | fld((imm >> 6) & 0x3, 3, 2) | bit(imm >> 5, 12) | fld((imm >> 2) & 0x7, 6, 4) | fld(rd, 11, 7) | 0b10
    }
    static func cFSWSP(_ rs2: Int32, _ imm: Int32) -> Int32 {
        fld(0b111, 15, 13) | fld((imm >> 6) & 0x3, 8, 7) | fld((imm >> 2) & 0xf, 12, 9) | fld(rs2, 6, 2) | 0b10
    }

    // Anchor: encoders reproduce well-known real encodings, validating the bit layout.
    @Test("encoders match canonical hex")
    func encodersMatchCanonicalHex() {
        #expect(Self.cADDI(0, 0) == 0x0001) // c.nop
        #expect(Self.cADDI(1, 1) == 0x0085)
        #expect(Self.cLI(1, 1) == 0x4085)
        #expect(Self.crEnc(0, 1, 0) == 0x8082) // c.jr x1 (ret)
        #expect(Self.crEnc(0, 1, 2) == 0x808a) // c.mv x1,x2
        #expect(Self.crEnc(1, 1, 2) == 0x908a) // c.add x1,x2
        #expect(Self.crEnc(1, 0, 0) == 0x9002) // c.ebreak
        #expect(Self.crEnc(1, 1, 0) == 0x9082) // c.jalr x1
        #expect(Self.cLWSP(1, 0) == 0x4082)
        #expect(Self.cSWSP(1, 0) == 0xc006)
    }

    // No manual InstrLen: Decoder.Decode derives it from inst[1:0] and bakes it into
    // the executor, so a compressed op advances PC by 2 without the caller setting it.
    static func st(_ arch: Architecture) -> MachineState { InitMachineState(.empty, arch, false) }
    func run(_ m: consuming MachineState, _ instr: Int32) throws -> MachineState {
        let e = try #require(Decoder.Decode(m, instr))
        return e(m)
    }

    // ---- Quadrant 0 ----
    @Test("C.ADDI4SPN")
    func cADDI4SPN_test() throws {
        let m = try run(Self.st(.RV32ic).setRegister(2, 0x1000), Self.cADDI4SPN(8, 16))
        #expect(m.getRegister(8) == 0x1010)
        #expect(m.PC == 0x80000002)
    }

    @Test("C.LW")
    func cLW_test() throws {
        var m = Self.st(.RV32ic).setRegister(8, 0x2000).storeMemoryWord(0x2004, 0xABCD)
        m = try run(m, Self.cLW(9, 8, 4))
        #expect(Int64(loadWord(m.Memory, 0x2004)!) == 0xABCD)
        #expect(m.getRegister(9) == 0xABCD)
    }

    @Test("C.SW")
    func cSW_test() throws {
        var m = Self.st(.RV32ic).setRegister(8, 0x2000).setRegister(9, 0x1234)
        m = try run(m, Self.cSW(8, 9, 4))
        #expect(Int64(loadWord(m.Memory, 0x2004)!) == 0x1234)
    }

    @Test("C.LD (RV64)")
    func cLD_test() throws {
        var m = Self.st(.RV64ic).setRegister(8, 0x2000).storeMemoryDoubleWord(0x2008, 0x1122334455667788)
        m = try run(m, Self.cLD(9, 8, 8))
        #expect(m.getRegister(9) == 0x1122334455667788)
    }

    @Test("C.SD (RV64)")
    func cSD_test() throws {
        var m = Self.st(.RV64ic).setRegister(8, 0x2000).setRegister(9, 0xDEADBEEFCAFE)
        m = try run(m, Self.cSD(8, 9, 8))
        #expect(loadDouble(m.Memory, 0x2008)! == 0xDEADBEEFCAFE)
    }

    // ---- Quadrant 1 ----
    @Test("C.ADDI")
    func cADDI_test() throws {
        let m = try run(Self.st(.RV32ic).setRegister(5, 10), Self.cADDI(5, -3))
        #expect(m.getRegister(5) == 7)
        #expect(m.PC == 0x80000002)
    }

    @Test("C.NOP")
    func cNOP_test() throws {
        let m = try run(Self.st(.RV32ic), Self.cADDI(0, 0))
        #expect(m.getRegister(0) == 0)
        #expect(m.PC == 0x80000002)
    }

    @Test("C.JAL (RV32) links PC+2")
    func cJAL_test() throws {
        let m = try run(Self.st(.RV32ic).setPC(0x1000), Self.cJAL(16))
        #expect(m.PC == 0x1010)
        #expect(m.getRegister(1) == 0x1002)
    }

    @Test("C.ADDIW (RV64)")
    func cADDIW_test() throws {
        let m = try run(Self.st(.RV64ic).setRegister(5, 0xFFFFFFFF), Self.cADDIW(5, 1))
        #expect(m.getRegister(5) == 0)
    }

    @Test("C.ADDIW rd, 0 acts as sext.w (RV64)")
    func cADDIW_sextw_test() throws {
        // imm=0 is VALID for C.ADDIW (not reserved): addiw rd,rd,0 == sext.w rd.
        // Upper 32 bits are discarded; bit 31 is sign-extended through bits 63:32.
        let neg = try run(Self.st(.RV64ic).setRegister(5, 0x1234567880000000), Self.cADDIW(5, 0))
        #expect(neg.getRegister(5) == -2147483648) // 0xFFFFFFFF_80000000
        let pos = try run(Self.st(.RV64ic).setRegister(6, 0x1234567800000123), Self.cADDIW(6, 0))
        #expect(pos.getRegister(6) == 0x123) // 0x00000000_00000123
    }

    @Test("C.LI")
    func cLI_test() throws {
        let m = try run(Self.st(.RV32ic), Self.cLI(5, -1))
        #expect(m.getRegister(5) == -1)
    }

    @Test("C.ADDI16SP")
    func cADDI16SP_test() throws {
        let m = try run(Self.st(.RV32ic).setRegister(2, 0x1000), Self.cADDI16SP(32))
        #expect(m.getRegister(2) == 0x1020)
    }

    @Test("C.LUI")
    func cLUI_test() throws {
        let m = try run(Self.st(.RV32ic), Self.cLUI(5, 1))
        #expect(m.getRegister(5) == 0x1000)
    }

    @Test("C.LUI rd=x0 is a HINT (no-op, not illegal)")
    func cLUI_hint_test() throws {
        // rd=x0, nzimm!=0 is a HINT: must decode (not trap) and run as a no-op.
        // PC+2 also confirms InstrLen is derived by Decode (st no longer sets it).
        let m = try run(Self.st(.RV32ic), Self.cLUI(0, 1))
        #expect(m.getRegister(0) == 0)
        #expect(m.PC == 0x80000002)
    }

    @Test("C.SRLI")
    func cSRLI_test() throws {
        let m = try run(Self.st(.RV32ic).setRegister(8, 0xF0), Self.cSRLI(8, 4))
        #expect(m.getRegister(8) == 0xF)
    }

    @Test("C.SRAI")
    func cSRAI_test() throws {
        let m = try run(Self.st(.RV32ic).setRegister(8, -16), Self.cSRAI(8, 2))
        #expect(m.getRegister(8) == -4)
    }

    @Test("C.ANDI")
    func cANDI_test() throws {
        let m = try run(Self.st(.RV32ic).setRegister(8, 0xFF), Self.cANDI(8, 0xF))
        #expect(m.getRegister(8) == 0xF)
    }

    @Test("C.SUB")
    func cSUB_test() throws {
        let m = try run(Self.st(.RV32ic).setRegister(8, 10).setRegister(9, 3), Self.caEnc(0, 0b00, 8, 9))
        #expect(m.getRegister(8) == 7)
    }

    @Test("C.XOR")
    func cXOR_test() throws {
        let m = try run(Self.st(.RV32ic).setRegister(8, 0b1100).setRegister(9, 0b1010), Self.caEnc(0, 0b01, 8, 9))
        #expect(m.getRegister(8) == 0b0110)
    }

    @Test("C.OR")
    func cOR_test() throws {
        let m = try run(Self.st(.RV32ic).setRegister(8, 0b1100).setRegister(9, 0b1010), Self.caEnc(0, 0b10, 8, 9))
        #expect(m.getRegister(8) == 0b1110)
    }

    @Test("C.AND")
    func cAND_test() throws {
        let m = try run(Self.st(.RV32ic).setRegister(8, 0b1100).setRegister(9, 0b1010), Self.caEnc(0, 0b11, 8, 9))
        #expect(m.getRegister(8) == 0b1000)
    }

    @Test("C.SUBW (RV64)")
    func cSUBW_test() throws {
        let m = try run(Self.st(.RV64ic).setRegister(8, 10).setRegister(9, 3), Self.caEnc(1, 0b00, 8, 9))
        #expect(m.getRegister(8) == 7)
    }

    @Test("C.ADDW (RV64)")
    func cADDW_test() throws {
        let m = try run(Self.st(.RV64ic).setRegister(8, 10).setRegister(9, 3), Self.caEnc(1, 0b01, 8, 9))
        #expect(m.getRegister(8) == 13)
    }

    @Test("C.J")
    func cJ_test() throws {
        #expect(try run(Self.st(.RV32ic), Self.cJ(16)).PC == 0x80000010)
    }

    @Test("C.J to a 2-byte-aligned target (IALIGN=2)")
    func cJ_align2_test() throws {
        #expect(try run(Self.st(.RV32ic), Self.cJ(18)).PC == 0x80000012)
    }

    @Test("C.BEQZ taken / not taken")
    func cBEQZ_test() throws {
        #expect(try run(Self.st(.RV32ic).setRegister(8, 0), Self.cBEQZ(8, 16)).PC == 0x80000010)
        #expect(try run(Self.st(.RV32ic).setRegister(8, 5), Self.cBEQZ(8, 16)).PC == 0x80000002)
    }

    @Test("C.BNEZ taken / not taken")
    func cBNEZ_test() throws {
        #expect(try run(Self.st(.RV32ic).setRegister(8, 5), Self.cBNEZ(8, 16)).PC == 0x80000010)
        #expect(try run(Self.st(.RV32ic).setRegister(8, 0), Self.cBNEZ(8, 16)).PC == 0x80000002)
    }

    // ---- Quadrant 2 ----
    @Test("C.SLLI")
    func cSLLI_test() throws {
        #expect(try run(Self.st(.RV32ic).setRegister(5, 1), Self.cSLLI(5, 4)).getRegister(5) == 16)
    }

    @Test("C.SLLI shamt 32 (RV64)")
    func cSLLI_shamt32_test() throws {
        #expect(try run(Self.st(.RV64ic).setRegister(5, 1), Self.cSLLI(5, 32)).getRegister(5) == 0x100000000)
    }

    @Test("C.LWSP")
    func cLWSP_test() throws {
        let m = Self.st(.RV32ic).setRegister(2, 0x3000).storeMemoryWord(0x3004, 0x55)
        #expect(try run(m, Self.cLWSP(5, 4)).getRegister(5) == 0x55)
    }

    @Test("C.LDSP (RV64)")
    func cLDSP_test() throws {
        let m = Self.st(.RV64ic).setRegister(2, 0x3000).storeMemoryDoubleWord(0x3008, 0x99)
        #expect(try run(m, Self.cLDSP(5, 8)).getRegister(5) == 0x99)
    }

    @Test("C.JR")
    func cJR_test() throws {
        let m = try run(Self.st(.RV32ic).setRegister(5, 0x80001000), Self.crEnc(0, 5, 0))
        #expect(m.PC == 0x80001000)
    }

    @Test("C.MV")
    func cMV_test() throws {
        #expect(try run(Self.st(.RV32ic).setRegister(6, 42), Self.crEnc(0, 5, 6)).getRegister(5) == 42)
    }

    @Test("C.EBREAK")
    func cEBREAK_test() throws {
        let m = try run(Self.st(.RV32ic), Self.crEnc(1, 0, 0))
        guard case .Trap(.EBreak) = m.RunState else {
            Issue.record("expected EBreak trap, got \(m.RunState)")
            return
        }
    }

    @Test("C.JALR links PC+2")
    func cJALR_test() throws {
        let m = try run(Self.st(.RV32ic).setPC(0x1000).setRegister(5, 0x2000), Self.crEnc(1, 5, 0))
        #expect(m.PC == 0x2000)
        #expect(m.getRegister(1) == 0x1002)
    }

    @Test("C.ADD")
    func cADD_test() throws {
        let m = try run(Self.st(.RV32ic).setRegister(5, 10).setRegister(6, 5), Self.crEnc(1, 5, 6))
        #expect(m.getRegister(5) == 15)
    }

    @Test("C.SWSP")
    func cSWSP_test() throws {
        let m = try run(Self.st(.RV32ic).setRegister(2, 0x4000).setRegister(5, 0x77), Self.cSWSP(5, 4))
        #expect(Int64(loadWord(m.Memory, 0x4004)!) == 0x77)
    }

    @Test("C.SDSP (RV64)")
    func cSDSP_test() throws {
        let m = try run(Self.st(.RV64ic).setRegister(2, 0x4000).setRegister(5, 0x88), Self.cSDSP(5, 8))
        #expect(loadDouble(m.Memory, 0x4008)! == 0x88)
    }

    // ---- illegal / reserved encodings decode to None ----
    @Test("reserved and FP-compressed encodings decode to None")
    func reservedDecodeNone_test() {
        let m32 = Self.st(.RV32ic)
        let m64 = Self.st(.RV64ic)
        #expect(DecodeC.Decode(m32, 0x0000) == .None) // all-zero (illegal)
        #expect(DecodeC.Decode(m32, Self.cADDI4SPN(8, 0)) == .None) // C.ADDI4SPN nzuimm=0
        #expect(DecodeC.Decode(m32, 0x2000) == .None) // Q0 funct3=001 (C.FLD, needs D)
        #expect(DecodeC.Decode(m32, 0x6000) == .None) // RV32 Q0 funct3=011 (C.FLW, needs F)
        #expect(DecodeC.Decode(m32, 0x2002) == .None) // Q2 funct3=001 (C.FLDSP, needs D)
        #expect(DecodeC.Decode(m32, Self.caEnc(1, 0b00, 8, 9)) == .None) // RV32 reserved CA (bit12=1)
        #expect(DecodeC.Decode(m64, Self.caEnc(1, 0b10, 8, 9)) == .None) // RV64 reserved CA (sub=10)
        #expect(DecodeC.Decode(m32, Self.cSLLI(5, 32)) == .None) // RV32 C.SLLI shamt>=32
        #expect(DecodeC.Decode(m32, Self.cLWSP(0, 4)) == .None) // C.LWSP rd=0
        #expect(DecodeC.Decode(m32, Self.crEnc(0, 0, 0)) == .None) // C.JR rd=0
        #expect(DecodeC.Decode(m32, Self.cADDI16SP(0)) == .None) // C.ADDI16SP nzimm=0
        #expect(DecodeC.Decode(m32, Self.cLUI(5, 0)) == .None) // C.LUI nzimm=0
        #expect(DecodeC.Decode(m64, Self.cADDIW(0, 1)) == .None) // C.ADDIW rd=0
        #expect(DecodeC.Decode(m32, Self.cSRLI(8, 32)) == .None) // C.SRLI shamt>=32 RV32 (shamtOk=false)
        #expect(DecodeC.Decode(m32, Self.cSRAI(8, 32)) == .None) // C.SRAI shamt>=32 RV32 (shamtOk=false)
        #expect(DecodeC.Decode(m64, Self.cLDSP(0, 8)) == .None) // C.LDSP rd=0
    }

    @Test("C Execute None traps")
    func cExecuteNoneTraps_test() {
        let m = ExecuteC.Execute(.None, Self.st(.RV32ic))
        guard case .Trap(.InstructionExecute) = m.RunState else {
            Issue.record("expected InstructionExecute trap, got \(m.RunState)")
            return
        }
    }

    // ---- fetch/PC integration: a compressed program runs through runSteps ----
    @Test("runSteps executes a compressed program (PC += 2)")
    func runStepsCompressed_test() {
        // c.li x5,5 ; c.li x6,3 ; c.add x5,x6 ; c.ebreak
        let prog = [Self.cLI(5, 5), Self.cLI(6, 3), Self.crEnc(1, 5, 6), Self.crEnc(1, 0, 0)]
        var m = InitMachineState(.empty, .RV32ic, false).setRunState(.Run)
        for (i, w) in prog.enumerated() {
            m = m.storeMemoryHalfWord(0x80000000 + Int64(i * 2), Int64(w))
        }
        m = Run.runSteps(10, m)
        #expect(m.getRegister(5) == 8)
        guard case .Trap(.EBreak) = m.RunState else {
            Issue.record("expected EBreak trap, got \(m.RunState)")
            return
        }
    }

    // ---- verbosityMessage: cover every output group ----
    @Test("C verbosityMessage covers every constructor")
    func cVerbosityMessage_test() {
        let m = Self.st(.RV64ic)
        func vm(_ w: Int32) { DecodeC.verbosityMessage(w, DecodeC.Decode(m, w), m) }
        // RV64ic decodes every constructor except C.JAL (RV32-only)
        vm(Self.cADDI4SPN(8, 16)); vm(Self.cADDI(1, 1)); vm(Self.cADDIW(5, 1)); vm(Self.cLI(5, 1)); vm(Self.cLUI(5, 1))
        vm(Self.cANDI(8, 0xF)); vm(Self.cLWSP(5, 4)); vm(Self.cLDSP(5, 8))
        vm(Self.cLW(9, 8, 4)); vm(Self.cLD(9, 8, 8)); vm(Self.cSW(8, 9, 4)); vm(Self.cSD(8, 9, 8))
        vm(Self.cSRLI(8, 4)); vm(Self.cSRAI(8, 2)); vm(Self.cSLLI(5, 4))
        vm(Self.caEnc(0, 0b00, 8, 9)); vm(Self.caEnc(0, 0b01, 8, 9)); vm(Self.caEnc(0, 0b10, 8, 9)); vm(Self.caEnc(0, 0b11, 8, 9))
        vm(Self.caEnc(1, 0b00, 8, 9)); vm(Self.caEnc(1, 0b01, 8, 9)) // C.SUBW C.ADDW
        vm(Self.cJ(16)); vm(Self.cADDI16SP(32)); vm(Self.cBEQZ(8, 16)); vm(Self.cBNEZ(8, 16))
        vm(Self.crEnc(0, 5, 0)); vm(Self.crEnc(1, 5, 0)) // C.JR C.JALR
        vm(Self.crEnc(0, 5, 6)); vm(Self.crEnc(1, 5, 6)) // C.MV C.ADD
        vm(Self.cSWSP(5, 4)); vm(Self.cSDSP(5, 8))
        // C.JAL is RV32-only (on RV64 funct3=001 decodes as C.ADDIW)
        let m32 = Self.st(.RV32ic)
        DecodeC.verbosityMessage(Self.cJAL(16), DecodeC.Decode(m32, Self.cJAL(16)), m32)
        DecodeC.verbosityMessage(0, .None, m) // _ -> "Undef"
        DecodeC.verbosityMessage(0, .C_EBREAK, m) // _ -> "Undef"
    }

    // =====================================================================
    // Zcf (RV32 + C + F): C.FLW / C.FSW / C.FLWSP / C.FSWSP.
    // The FP-executing Zcf tests are omitted because F is not implemented here;
    // only the pure encoder check and the decode-gating tests are ported.
    @Test("Zcf encoders match canonical hex")
    func zcfEncodersMatchCanonicalHex() {
        #expect(Self.cFLW(8, 8, 0) == 0x6000) // c.flw f8, 0(x8)
        #expect(Self.cFLW(9, 8, 4) == 0x6044) // c.flw f9, 4(x8)
        #expect(Self.cFSW(8, 9, 4) == 0xE044) // c.fsw f9, 4(x8)
        #expect(Self.cFLWSP(1, 0) == 0x6082) // c.flwsp f1, 0(sp)
        #expect(Self.cFSWSP(1, 0) == 0xE006) // c.fswsp f1, 0(sp)
    }

    @Test("Zcf encodings stay C.LD/C.SD/C.LDSP/C.SDSP on RV64 even with F")
    func zcfStayLdSdOnRV64() {
        let m64 = Self.st(.RV64ifc)
        guard case .C_LD = DecodeC.Decode(m64, Self.cFLW(9, 8, 4)) else {
            Issue.record("expected C_LD, got \(DecodeC.Decode(m64, Self.cFLW(9, 8, 4)))")
            return
        }
        guard case .C_SD = DecodeC.Decode(m64, Self.cFSW(8, 9, 4)) else {
            Issue.record("expected C_SD, got \(DecodeC.Decode(m64, Self.cFSW(8, 9, 4)))")
            return
        }
        guard case .C_LDSP = DecodeC.Decode(m64, Self.cFLWSP(5, 4)) else {
            Issue.record("expected C_LDSP, got \(DecodeC.Decode(m64, Self.cFLWSP(5, 4)))")
            return
        }
        guard case .C_SDSP = DecodeC.Decode(m64, Self.cFSWSP(5, 4)) else {
            Issue.record("expected C_SDSP, got \(DecodeC.Decode(m64, Self.cFSWSP(5, 4)))")
            return
        }
    }

    @Test("Zcf encodings stay reserved (None) without F")
    func zcfReservedWithoutF() {
        let m32 = Self.st(.RV32ic)
        #expect(DecodeC.Decode(m32, Self.cFLW(9, 8, 4)) == .None)
        #expect(DecodeC.Decode(m32, Self.cFSW(8, 9, 4)) == .None)
        #expect(DecodeC.Decode(m32, Self.cFLWSP(5, 4)) == .None)
        #expect(DecodeC.Decode(m32, Self.cFSWSP(5, 4)) == .None)
    }

    // Port deviation: this implementation does not implement F, so the Zcf encodings
    // remain reserved even on RV32ifc (the reference would decode them as C.FLW/etc.).
    @Test("Zcf encodings are reserved even on RV32ifc (F not implemented)")
    func zcfReservedOnRV32ifc() {
        let m32ifc = Self.st(.RV32ifc)
        #expect(DecodeC.Decode(m32ifc, Self.cFLW(9, 8, 4)) == .None)
        #expect(DecodeC.Decode(m32ifc, Self.cFSW(8, 9, 4)) == .None)
        #expect(DecodeC.Decode(m32ifc, Self.cFLWSP(5, 4)) == .None)
        #expect(DecodeC.Decode(m32ifc, Self.cFSWSP(5, 4)) == .None)
    }

    @Test("Zcd encodings (need D) remain reserved even with F")
    func zcdReservedWithF() {
        let m32 = Self.st(.RV32ifc)
        let m64 = Self.st(.RV64ifc)
        #expect(DecodeC.Decode(m32, 0x2000) == .None) // Q0 funct3=001: C.FLD (needs D)
        #expect(DecodeC.Decode(m32, 0xA000) == .None) // Q0 funct3=101: C.FSD (needs D)
        #expect(DecodeC.Decode(m32, 0x2002) == .None) // Q2 funct3=001: C.FLDSP (needs D)
        #expect(DecodeC.Decode(m32, 0xA002) == .None) // Q2 funct3=101: C.FSDSP (needs D)
        #expect(DecodeC.Decode(m64, 0x2000) == .None)
        #expect(DecodeC.Decode(m64, 0xA002) == .None)
    }

    @Test("Decoder gate: reserved compressed word on a C arch returns nil")
    func decoderCGateReservedReturnsNil() {
        // 0x0000 is the canonical illegal compressed encoding. On RV32ic it is not
        // base-I, M/A are absent, so it reaches the C gate with hasC=true &&
        // decC==None -> nil (the gate's RHS-false outcome).
        #expect(Decoder.Decode(Self.st(.RV32ic), 0x0000) == nil)
        #expect(Decoder.Decode(Self.st(.RV64ic), 0x0000) == nil)
    }
}
