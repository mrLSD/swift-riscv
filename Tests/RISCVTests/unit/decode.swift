import Testing

import RISCV

struct UnitDecodeTests {
    let m32 = InitMachineState(.empty, .RV32i, false)

    // ---- illegal-instruction (_ -> None) decode arms ----
    @Test("I decode returns None for illegal encodings")
    func IDecodeReturnsNoneForIllegalEncodings() throws {
        #expect(DecodeI.Decode(m32, Int32(bitPattern: 0x00002063)) == InstructionI.None)   // branch funct3=010
        #expect(DecodeI.Decode(m32, Int32(bitPattern: 0x40001013)) == InstructionI.None)   // imm funct3=001 with bad funct6
    }

    // ---- FENCE ignores its reserved rd/rs1 fields instead of trapping ----
    @Test("FENCE decodes with nonzero rd and rs1 (fields ignored)")
    func FENCEDecodesWithNonzeroRdAndRs1() throws {
        let decoded = DecodeI.Decode(m32, Int32(bitPattern: 0x0001008F))   // fence with rd=x1, rs1=x2, funct3=000
        guard case .FENCE = decoded else {
            Issue.record("expected FENCE, got \(decoded)")
            return
        }
    }

    @Test("FENCE.I (funct3=001) is not implemented and decodes to None")
    func FENCEINotImplemented() throws {
        #expect(DecodeI.Decode(m32, Int32(bitPattern: 0x0000100F)) == InstructionI.None)
    }

    // ---- verbosityMessage (logging) coverage ----
    @Test("I verbosityMessage covers all arms")
    func IVerbosityMessageCoversAllArms() throws {
        for w in [0x000000b7, 0x00000097, 0x0000006f, 0x00000067, 0x00000083, 0x00000063, 0x00001093, 0x000000b3, 0x0000000f] as [UInt32] {
            let instr = Int32(bitPattern: w)
            DecodeI.verbosityMessage(instr, DecodeI.Decode(m32, instr), m32)
        }
        DecodeI.verbosityMessage(0, InstructionI.None, m32)
    }
}
