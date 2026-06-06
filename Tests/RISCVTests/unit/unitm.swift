import Testing

import RISCV

struct UnitMTests {
    let m64 = InitMachineState(.empty, .RV64ima, false)

    // =====================================================================
    // verbosityMessage: decode one real encoding per constructor so every
    // OR-pattern alternative arm is exercised (full branch coverage).
    // =====================================================================

    @Test("M verbosityMessage: every constructor arm")
    func MVerbosityMessageEveryConstructorArm() throws {
        for w in [
            0x02000033, 0x02001033, 0x02002033, 0x02003033,                  // MUL MULH MULHSU MULHU
            0x02004033, 0x02005033, 0x02006033, 0x02007033,                  // DIV DIVU REM REMU
        ] as [UInt32] {
            let instr = Int32(bitPattern: w)
            DecodeM.verbosityMessage(instr, DecodeM.Decode(m64, instr), m64)
        }
        DecodeM.verbosityMessage(0, InstructionM.None, m64)
    }

    @Test("M64 verbosityMessage: every constructor arm")
    func M64VerbosityMessageEveryConstructorArm() throws {
        for w in [
            0x0200003b, 0x0200403b, 0x0200503b, 0x0200603b, 0x0200703b,      // MULW DIVW DIVUW REMW REMUW
        ] as [UInt32] {
            let instr = Int32(bitPattern: w)
            DecodeM64.verbosityMessage(instr, DecodeM64.Decode(m64, instr), m64)
        }
        DecodeM64.verbosityMessage(0, InstructionM64.None, m64)
    }

    // ---- illegal-instruction (_ -> None) decode arms ----
    @Test("M64 decode returns None for unsupported funct3")
    func M64DecodeReturnsNoneForUnsupportedFunct3() throws {
        #expect(DecodeM64.Decode(m64, Int32(bitPattern: 0x0200103b)) == InstructionM64.None) // funct3=001
    }

    // ---- Execute None traps (dead dispatch arms) ----
    @Test("Execute None traps for M and M64 (dead dispatch arms)")
    func ExecuteNoneTrapsForMAndM64() throws {
        let m = InitMachineState(.empty, .RV64ima, false).setRunState(.Run)
        #expect(ExecuteM.Execute(InstructionM.None, m).RunState == .Trap(.InstructionExecute))
        #expect(ExecuteM64.Execute(InstructionM64.None, m).RunState == .Trap(.InstructionExecute))
    }

    // =====================================================================
    // Decoder gating: the M/M64 decode arms are only reachable when the
    // architecture advertises the M extension (and RV64 for the .W forms).
    // =====================================================================

    @Test("MUL decodes but Decoder gates it off when hasM is false (RV32i)")
    func DecoderGatesMULOffWhenNoM() throws {
        #expect(Decoder.Decode(InitMachineState(.empty, .RV32i, false), 0x02000033) == nil)
    }

    @Test("MUL decodes through the Decoder on RV32im")
    func DecoderAcceptsMULOnRV32im() throws {
        _ = try #require(Decoder.Decode(InitMachineState(.empty, .RV32im, false), 0x02000033))
    }

    @Test("MULW is gated off on RV32im (needs RV64)")
    func DecoderGatesMULWOffOnRV32() throws {
        #expect(Decoder.Decode(InitMachineState(.empty, .RV32im, false), Int32(bitPattern: 0x0200003b)) == nil)
    }

    @Test("MULW decodes through the Decoder on RV64im and advances PC by 4")
    func DecoderAcceptsMULWOnRV64im() throws {
        var m = InitMachineState(.empty, .RV64im, false).setRunState(.Run)
        m = m.setRegister(1, 6).setRegister(2, 7)
        let executor = try #require(Decoder.Decode(m, Int32(bitPattern: 0x0200003b)))
        let pc = m.PC
        m = executor(m) // rd is x0, so only the PC advance is observable
        #expect(m.PC == pc + 4)
    }

    @Test("MULW is gated off on RV64i (hasM false)")
    func DecoderGatesMULWOffWhenNoM() throws {
        #expect(Decoder.Decode(InitMachineState(.empty, .RV64i, false), Int32(bitPattern: 0x0200003b)) == nil)
    }

    @Test("M decode returns None for an ALU word with a non-M funct7")
    func MDecodeNoneForNonMFunct7() {
        // opcode 0110011 but funct7 = 0100000 (SUB shape) -> not an M instruction
        let m32 = InitMachineState(.empty, .RV32im, false)
        #expect(DecodeM.Decode(m32, Int32(bitPattern: 0x401101B3)) == InstructionM.None)
    }

    @Test("Illegal OP-32 word op (unsupported funct3) is gated to nil on RV64im")
    func DecoderReturnsNilForIllegalWordOpOnRV64im() {
        // opcode 0b0111011, funct7 0b0000001, funct3 0b001 -> DecodeM64 .None ->
        // the Decoder's `decM64 != None` gate operand evaluates false.
        #expect(Decoder.Decode(InitMachineState(.empty, .RV64im, false), Int32(bitPattern: 0x0200103b)) == nil)
    }

    @Test("M64 decode returns None for a word-op with a non-M funct7")
    func M64DecodeNoneForNonMFunct7() {
        // opcode 0111011 on RV64 but funct7 = 0100000 (SUBW shape) -> not an M64 instruction
        let m64 = InitMachineState(.empty, .RV64ima, false)
        #expect(DecodeM64.Decode(m64, Int32(bitPattern: 0x4000003B)) == InstructionM64.None)
    }
}
