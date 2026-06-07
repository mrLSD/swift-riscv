import Testing

import RISCV

struct UnitExecuteTests {
    private func st(_ arch: Architecture) -> MachineState {
        InitMachineState(.empty, arch, false).setRunState(.Run)
    }

    private func step(_ m: MachineState, _ instr: UInt32) throws -> MachineState {
        let executor = try #require(Decoder.Decode(m, Int32(bitPattern: instr)))
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

    @Test("I loads trap on an unmapped address", arguments: [
        UInt32(0x00000083), // LB  x1,0(x0)
        UInt32(0x00001083), // LH
        UInt32(0x00002083), // LW
        UInt32(0x00004083), // LBU
        UInt32(0x00005083), // LHU
    ])
    func I_loads_trap_on_an_unmapped_address(_ instr: UInt32) throws {
        #expect(isMemTrap(try step(st(.RV32i), instr)))
    }

    @Test("JALR misaligned target traps")
    func JALR_misaligned_target_traps() throws {
        let m = try step(st(.RV32i), 0x00200067)
        guard case .Trap(.JumpAddress) = m.RunState else {
            Issue.record("expected JumpAddress trap, got \(m.RunState)")
            return
        }
    }

    @Test("JALR to self stops")
    func JALR_to_self_stops() throws {
        let m = st(.RV64i).setRegister(1, 0x80000000)
        #expect(try step(m, 0x00008067).RunState == .Stopped)
    }

    @Test("JAL misaligned target traps")
    func JAL_misaligned_target_traps() throws {
        let m = try step(st(.RV32i), 0x0020006f)
        guard case .Trap(.JumpAddress) = m.RunState else {
            Issue.record("expected JumpAddress trap, got \(m.RunState)")
            return
        }
    }

    @Test("JAL to self stops")
    func JAL_to_self_stops() throws {
        #expect(try step(st(.RV32i), 0x0000006f).RunState == .Stopped)
    }

    // On RV32 a self-jump to a bit-31 address must still be detected (the register
    // holds it sign-extended, so newPC needs XLEN normalization before the PC compare).
    @Test("RV32 JALR self-jump to a high address stops")
    func RV32_JALR_self_jump_to_a_high_address_stops() throws {
        let m = st(.RV32i).setRegister(1, 0x80000000)   // PC default is 0x80000000
        #expect(try step(m, 0x00008067).RunState == .Stopped)  // jalr x0,x1,0
    }

    // A store then load through a bit-31 base address must round-trip on RV32
    // (loads previously used the raw sign-extended address as the memory key and trapped).
    @Test("RV32 load reads back a store at a bit-31 address")
    func RV32_load_reads_back_a_store_at_a_bit_31_address() throws {
        var m = st(.RV32i).setRegister(1, 0x80000000)
        m = m.setRegister(2, 0x12345678)
        m = try step(m, 0x0020A023)   // sw x2, 0(x1)
        m = try step(m, 0x0000A183)   // lw x3, 0(x1)
        #expect(m.RunState == .Run)
        #expect(m.getRegister(3) == 0x12345678)
    }

    // x1 = 0, x2 = 1: lets the unsigned-compare branches (BLTU/BGEU) be exercised as
    // taken (0 < 1) or not-taken (0 >= 1 is false) without depending on x0.
    private func brSt() -> MachineState {
        st(.RV32i).setRegister(1, 0).setRegister(2, 1)
    }

    // A taken branch with a misaligned target traps (no-C machine: instrAlign = 4).
    @Test("taken branch with a misaligned target traps", arguments: [
        UInt32(0x00000163), // beq  x0,x0,2  (taken)
        UInt32(0x00007163), // bgeu x0,x0,2  (taken: 0 >= 0)
        UInt32(0x0020E163), // bltu x1,x2,2  (taken: 0 < 1)
    ])
    func taken_branch_with_a_misaligned_target_traps(_ instr: UInt32) throws {
        let m = try step(brSt(), instr)
        guard case .Trap(.BreakAddress) = m.RunState else {
            Issue.record("expected BreakAddress trap, got \(m.RunState)")
            return
        }
    }

    // A taken self-branch (target == PC) halts as the infinite-loop sentinel.
    @Test("taken self-branch stops", arguments: [
        UInt32(0x00000063), // beq  x0,x0,0  (taken)
        UInt32(0x00007063), // bgeu x0,x0,0  (taken)
        UInt32(0x0020E063), // bltu x1,x2,0  (taken: 0 < 1)
    ])
    func taken_self_branch_stops(_ instr: UInt32) throws {
        #expect(try step(brSt(), instr).RunState == .Stopped)
    }

    // A NOT-taken branch falls through to PC+InstrLen even if its (unused) target is
    // misaligned or equals PC (regression: the checks previously ran before branchCheck).
    @Test("not-taken branch falls through without trapping or stopping", arguments: [
        UInt32(0x00001163), // bne  x0,x0,2  (not taken; misaligned target)
        UInt32(0x00001063), // bne  x0,x0,0  (not taken; target == PC)
        UInt32(0x00006163), // bltu x0,x0,2  (not taken)
        UInt32(0x00006063), // bltu x0,x0,0  (not taken)
        UInt32(0x0020F163), // bgeu x1,x2,2  (not taken: 0 >= 1 is false)
        UInt32(0x0020F063), // bgeu x1,x2,0  (not taken)
    ])
    func not_taken_branch_falls_through_without_trapping_or_stopping(_ instr: UInt32) throws {
        let m = try step(brSt(), instr)
        #expect(m.RunState == .Run)
        #expect(m.PC == 0x80000004)
    }

    @Test("Execute None traps for every instruction set (dead dispatch arms)")
    func Execute_None_traps() throws {
        let m = st(.RV64ima)
        #expect(isTrap(ExecuteI.Execute(InstructionI.None, m)))
    }

    // On RV32 a multi-byte access whose bytes wrap past 0xFFFFFFFF must round-trip.
    // Stores already normalize each byte address to 32 bits (so byte 0x1_0000_0000 folds to
    // key 0x0); loads now normalize each probed byte address identically. Previously the load
    // probed the un-wrapped keys (0x1_0000_0000..) and trapped MemAddress / read stale data.
    @Test("RV32 word store and load round-trip across the 4GB boundary")
    func RV32_word_store_and_load_round_trip_across_the_4GB_boundary() throws {
        var m = st(.RV32i).setRegister(1, Int64(-2))          // base 0xFFFFFFFE
        m = m.setRegister(2, 0x11223344)
        m = try step(m, 0x0020A023)                           // sw x2, 0(x1)  (high 2 bytes wrap to 0x0/0x1)
        m = try step(m, 0x0000A183)                           // lw x3, 0(x1)
        #expect(m.RunState == .Run)
        #expect(m.getRegister(3) == 0x11223344)
    }

    @Test("RV32 halfword store and load round-trip across the 4GB boundary")
    func RV32_halfword_store_and_load_round_trip_across_the_4GB_boundary() throws {
        var m = st(.RV32i).setRegister(1, Int64(-1))          // base 0xFFFFFFFF: second byte wraps to 0x0
        m = m.setRegister(2, 0x6789)
        m = try step(m, 0x00209023)                           // sh x2, 0(x1)
        m = try step(m, 0x00009183)                           // lh x3, 0(x1)
        #expect(m.RunState == .Run)
        #expect(m.getRegister(3) == 0x6789)
    }
}
