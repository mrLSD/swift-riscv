import Testing

import RISCV

struct UnitATests {
    let m64 = InitMachineState(.empty, .RV64ima, false)

    private func st(_ arch: Architecture) -> MachineState {
        InitMachineState(.empty, arch, false).setRunState(.Run)
    }

    private func step(_ m: MachineState, _ instr: Int32) throws -> MachineState {
        let executor = try #require(Decoder.Decode(m, instr))
        return executor(m)
    }

    private func isMemTrap(_ m: MachineState) -> Bool {
        if case .Trap(.MemAddress) = m.RunState { return true }
        return false
    }

    private func isTrap(_ m: MachineState) -> Bool {
        if case .Trap = m.RunState { return true }
        return false
    }

    // funct5 << 27 overflows Int32 for funct5 >= 16, so build in UInt32 and convert.
    private func encW(_ funct5: UInt32, _ rs2: UInt32, _ rs1: UInt32, _ rd: UInt32) -> Int32 {
        Int32(bitPattern: (funct5 << 27) | (rs2 << 20) | (rs1 << 15) | (0b010 << 12) | (rd << 7) | 0b0101111)
    }

    private func encD(_ funct5: UInt32, _ rs2: UInt32, _ rs1: UInt32, _ rd: UInt32) -> Int32 {
        Int32(bitPattern: (funct5 << 27) | (rs2 << 20) | (rs1 << 15) | (0b011 << 12) | (rd << 7) | 0b0101111)
    }

    // AMO/LR funct5 values that load from memory (SC excluded)
    private let loadingFunct5: [UInt32] = [0b00010, 0b00001, 0b00000, 0b00100, 0b01100, 0b01000, 0b10000, 0b10100, 0b11000, 0b11100]

    // =====================================================================
    // verbosityMessage: decode one real encoding per constructor so every
    // OR-pattern alternative arm is exercised (full branch coverage).
    // (Anonymous records can't cross the assembly boundary, so we decode
    //  rather than build the DU values directly.)
    // =====================================================================

    @Test("A verbosityMessage: every constructor arm")
    func AVerbosityMessageEveryConstructorArm() throws {
        for w in [
            0x1000202f, 0x1800202f, 0x0800202f, 0x0000202f, 0x2000202f, 0x6000202f, // LR SC SWAP ADD XOR AND
            0x4000202f, 0x8000202f, 0xA000202f, 0xC000202f, 0xE000202f,             // OR MIN MAX MINU MAXU
        ] as [UInt32] {
            let instr = Int32(bitPattern: w)
            DecodeA.verbosityMessage(instr, DecodeA.Decode(instr), m64)
        }
        DecodeA.verbosityMessage(0, InstructionA.None, m64)   // _ -> "Undef"
    }

    @Test("A64 verbosityMessage: every constructor arm")
    func A64VerbosityMessageEveryConstructorArm() throws {
        for w in [
            0x1000302f, 0x1800302f, 0x0800302f, 0x0000302f, 0x2000302f, 0x6000302f, // LR SC SWAP ADD XOR AND
            0x4000302f, 0x8000302f, 0xA000302f, 0xC000302f, 0xE000302f,             // OR MIN MAX MINU MAXU
        ] as [UInt32] {
            let instr = Int32(bitPattern: w)
            DecodeA64.verbosityMessage(instr, DecodeA64.Decode(instr), m64)
        }
        DecodeA64.verbosityMessage(0, InstructionA64.None, m64)
    }

    // ---- illegal-instruction (_ -> None) decode arms ----
    @Test("A decode returns None for unknown funct5")
    func ADecodeReturnsNoneForUnknownFunct5() throws {
        #expect(DecodeA.Decode(Int32(bitPattern: 0x2800202f)) == InstructionA.None)   // funct5=00101, .W
    }

    @Test("A64 decode returns None for unknown funct5")
    func A64DecodeReturnsNoneForUnknownFunct5() throws {
        #expect(DecodeA64.Decode(Int32(bitPattern: 0x2800302f)) == InstructionA64.None) // funct5=00101, .D
    }

    @Test("A .W ops trap on an unmapped aligned address")
    func A_W_ops_trap_on_an_unmapped_aligned_address() throws {
        for f5 in loadingFunct5 {
            let m = st(.RV64ia).setRegister(1, 0x4)
            #expect(isMemTrap(try step(m, encW(f5, 2, 1, 3))))
        }
    }

    @Test("A .D ops trap on an unmapped aligned address")
    func A_D_ops_trap_on_an_unmapped_aligned_address() throws {
        for f5 in loadingFunct5 {
            let m = st(.RV64ia).setRegister(1, 0x8)
            #expect(isMemTrap(try step(m, encD(f5, 2, 1, 3))))
        }
    }

    @Test("SC.D without a reservation fails")
    func SC_D_without_a_reservation_fails() throws {
        let m = st(.RV64ia).setRegister(1, 0x8)
        #expect(try step(m, encD(0b00011, 2, 1, 3)).getRegister(3) == 1)
    }

    // The same asymmetry for atomics — LR.W through a bit-31 base must read the store.
    @Test("RV32 atomic reads back a store at a bit-31 address")
    func RV32_atomic_reads_back_a_store_at_a_bit_31_address() throws {
        var m = st(.RV32ia).setRegister(1, 0x80000000)
        m = m.setRegister(2, 0x0000000A)
        m = try step(m, 0x0020A023)            // sw x2,0(x1) : seed memory
        m = try step(m, encW(0b00010, 0, 1, 3))  // lr.w x3,(x1)
        #expect(m.RunState == .Run)
        #expect(m.getRegister(3) == 0xA)
    }

    @Test("Execute None traps for every instruction set (dead dispatch arms)")
    func Execute_None_traps() throws {
        let m = st(.RV64ima)
        #expect(isTrap(ExecuteA.Execute(InstructionA.None, m)))
        #expect(isTrap(ExecuteA64.Execute(InstructionA64.None, m)))
    }

    // AMO min/max: exercise both selection branches (mem-kept vs rs2-selected).
    private func amoMem(_ f5: UInt32, _ isD: Bool, _ memVal: Int64, _ rs2Val: Int64) throws -> Int64 {
        let addr: Int64 = 0x40
        var m = st(.RV64ia).setRegister(1, addr)
        m = m.setRegister(2, rs2Val)
        m = m.storeMemoryDoubleWord(addr, memVal)
        m = try step(m, isD ? encD(f5, 2, 1, 3) : encW(f5, 2, 1, 3))
        return isD ? loadDouble(m.Memory, addr)! : Int64(loadWord(m.Memory, addr)!)
    }

    @Test("AMOMAX.W / AMOMAXU.W keep memory when it is not smaller")
    func AMOMAX_W_AMOMAXU_W_keep_memory_when_it_is_not_smaller() throws {
        #expect(try amoMem(0b10100, false, 10, 5) == 10)
        #expect(try amoMem(0b11100, false, 10, 5) == 10)
    }

    @Test("AMO .D min/max cover both selection branches")
    func AMO_D_min_max_cover_both_selection_branches() throws {
        #expect(try amoMem(0b10000, true, 10, 5) == 5)   // AMOMIN.D  mem>rs2 -> rs2
        #expect(try amoMem(0b10100, true, 10, 5) == 10)  // AMOMAX.D  mem>rs2 -> mem
        #expect(try amoMem(0b11000, true, 5, 10) == 5)   // AMOMINU.D mem<rs2 -> mem
        #expect(try amoMem(0b11100, true, 5, 10) == 10)  // AMOMAXU.D mem<rs2 -> rs2
    }

    @Test("AMO.W arithmetic uses only low 32 bits of rs2 on RV64")
    func AMO_W_arithmetic_uses_only_low_32_bits_of_rs2_on_RV64() throws {
        #expect(try amoMem(0b00000, false, 10, Int64(bitPattern: 0x0000000100000005)) == 15)    // AMOADD.W  10 + 5
        #expect(try amoMem(0b00001, false, 10, Int64(bitPattern: 0x00000001000000AB)) == 0xAB)  // AMOSWAP.W store 0xAB
        #expect(try amoMem(0b01100, false, 0xFF, Int64(bitPattern: 0x000000010000000F)) == 0xF) // AMOAND.W  0xFF & 0xF
    }

    // =====================================================================
    // Decoder gating: the A/A64 decode arms are only reachable when the
    // architecture advertises the A extension (and RV64 for the .D forms).
    // =====================================================================

    @Test("AMOADD.W is gated off when hasA is false (RV32i)")
    func DecoderGatesAMOADDWOffWhenNoA() throws {
        #expect(Decoder.Decode(InitMachineState(.empty, .RV32i, false), Int32(bitPattern: 0x0000202f)) == nil)
    }

    @Test("AMOADD.W decodes through the Decoder on RV32ia")
    func DecoderAcceptsAMOADDWOnRV32ia() throws {
        _ = try #require(Decoder.Decode(InitMachineState(.empty, .RV32ia, false), Int32(bitPattern: 0x0000202f)))
    }

    @Test("AMOADD.D is gated off on RV32ia (needs RV64)")
    func DecoderGatesAMOADDDOffOnRV32() throws {
        #expect(Decoder.Decode(InitMachineState(.empty, .RV32ia, false), Int32(bitPattern: 0x0000302f)) == nil)
    }

    @Test("AMOADD.D decodes through the Decoder on RV64ia")
    func DecoderAcceptsAMOADDDOnRV64ia() throws {
        _ = try #require(Decoder.Decode(InitMachineState(.empty, .RV64ia, false), Int32(bitPattern: 0x0000302f)))
    }

    @Test("AMOADD.D is gated off on RV64i (hasA false)")
    func DecoderGatesAMOADDDOffWhenNoA() throws {
        #expect(Decoder.Decode(InitMachineState(.empty, .RV64i, false), Int32(bitPattern: 0x0000302f)) == nil)
    }
}
