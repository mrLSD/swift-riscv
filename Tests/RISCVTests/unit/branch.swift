import Testing

import RISCV

@Suite struct UnitBranchTests {
    let m32 = InitMachineState(.empty, .RV32i, false)

    // =====================================================================
    // verbosityMessage: decode one real encoding per constructor so every
    // OR-pattern alternative arm is exercised (full branch coverage).
    // (Anonymous records can't cross the assembly boundary, so we decode
    //  rather than build the DU values directly.)
    // =====================================================================

    @Test("I verbosityMessage: every constructor arm")
    func IVerbosityMessageEveryConstructorArm() {
        let words: [UInt32] = [
            0x000000b7,                                                              // LUI
            0x00000097,                                                              // AUIPC
            0x0000006f,                                                              // JAL
            0x00000067,                                                              // JALR
            0x00000063, 0x00001063, 0x00004063, 0x00005063, 0x00006063, 0x00007063, // BEQ BNE BLT BGE BLTU BGEU
            0x00000083, 0x00001083, 0x00002083, 0x00004083, 0x00005083,             // LB LH LW LBU LHU
            0x00000023, 0x00001023, 0x00002023,                                     // SB SH SW
            0x00000013, 0x00002013, 0x00003013, 0x00004013, 0x00006013, 0x00007013, // ADDI SLTI SLTIU XORI ORI ANDI
            0x00001013, 0x00005013, 0x40005013,                                     // SLLI SRLI SRAI
            0x00000033, 0x40000033, 0x00001033, 0x00002033, 0x00003033,             // ADD SUB SLL SLT SLTU
            0x00004033, 0x00005033, 0x40005033, 0x00006033, 0x00007033,             // XOR SRL SRA OR AND
            0x0000000f, 0x00000073, 0x00100073,                                     // FENCE ECALL EBREAK
        ]
        for w in words {
            let instr = Int32(bitPattern: w)
            DecodeI.verbosityMessage(instr, DecodeI.Decode(m32, instr), m32)
        }
        DecodeI.verbosityMessage(0, InstructionI.None, m32)   // _ -> "Undef"
    }

    // =====================================================================
    // DecodeI: false-branches of the shift / FENCE / SYSTEM when-guards.
    // =====================================================================

    @Test("I decode: SRAI guard false branches")
    func IDecodeSRAIGuardFalseBranches() {
        // funct3=101, funct6=0b010000, shamt[5]=1 on RV32 -> shamt_ok=false -> None
        #expect(DecodeI.Decode(m32, Int32(bitPattern: 0x42005013)) == InstructionI.None)
        // funct3=101 with funct6 neither 0 nor 0b010000 -> guard cond1 false -> None
        #expect(DecodeI.Decode(m32, Int32(bitPattern: 0x80005013)) == InstructionI.None)
    }

    @Test("I decode: FENCE/SYSTEM guard false branches")
    func IDecodeFenceSystemGuardFalseBranches() {
        // FENCE opcode (0b0001111): rd/rs1 are ignored per spec; only funct3 != 0 -> None
        #expect(DecodeI.Decode(m32, Int32(bitPattern: 0x0000100F)) == InstructionI.None)  // funct3=1 (e.g. unimplemented FENCE.I)
        // SYSTEM opcode (0b1110011) with rd / rs1 / funct3 != 0, or imm not 0/1 -> None
        #expect(DecodeI.Decode(m32, Int32(bitPattern: 0x000000F3)) == InstructionI.None)  // rd=1
        #expect(DecodeI.Decode(m32, Int32(bitPattern: 0x00008073)) == InstructionI.None)  // rs1=1
        #expect(DecodeI.Decode(m32, Int32(bitPattern: 0x00001073)) == InstructionI.None)  // funct3=1
        #expect(DecodeI.Decode(m32, Int32(bitPattern: 0x00200073)) == InstructionI.None)  // imm12=2 (neither ECALL nor EBREAK)
    }
}
