import Testing

import RISCV

//===============================================
// A-extension semantics (`rv64a`) tests
struct RV64aAMOSemTests {
    // A-extension encoders (aq = rl = 0); funct3 = 0b010 for .W, 0b011 for .D.
    // NOTE: funct5 >= 16 (e.g. 0b10000) shifted by 27 overflows Int32, so build
    // the word in UInt32 and convert once.
    private func encW(_ funct5: UInt32, _ rs2: UInt32, _ rs1: UInt32, _ rd: UInt32) -> Int32 {
        Int32(bitPattern: funct5 << 27 | rs2 << 20 | rs1 << 15 | 0b010 << 12 | rd << 7 | 0b0101111)
    }
    private func encD(_ funct5: UInt32, _ rs2: UInt32, _ rs1: UInt32, _ rd: UInt32) -> Int32 {
        Int32(bitPattern: funct5 << 27 | rs2 << 20 | rs1 << 15 | 0b011 << 12 | rd << 7 | 0b0101111)
    }

    private func initMachine() -> MachineState {
        InitMachineState(.empty, .RV64ia, false).setRunState(.Run)
    }

    private func exec(_ m: MachineState, _ instr: Int32) throws -> MachineState {
        let e = try #require(Decoder.Decode(m, instr))
        return e(m)
    }

    // ---- LR/SC reservation ----
    @Test("SC.W succeeds after LR.W to the same address")
    func SC_W_succeeds_after_LR_W() throws {
        let addr: Int64 = 0x2000
        var m = initMachine()
        m = m.setRegister(10, addr)
        m = m.setRegister(11, 0x1234)
        m = m.storeMemoryWord(addr, 0)
        m = try exec(m, encW(0b00010, 0, 10, 0))
        m = try exec(m, encW(0b00011, 11, 10, 12))
        #expect(m.getRegister(12) == 0)
        #expect(Int64(try #require(loadWord(m.Memory, addr))) == 0x1234)
    }

    @Test("SC.W fails without a prior LR.W")
    func SC_W_fails_without_LR() throws {
        let addr: Int64 = 0x2000
        var m = initMachine()
        m = m.setRegister(10, addr)
        m = m.setRegister(11, 0x1234)
        m = m.storeMemoryWord(addr, 0xAA)
        m = try exec(m, encW(0b00011, 11, 10, 12))
        #expect(m.getRegister(12) == 1)
        #expect(Int64(try #require(loadWord(m.Memory, addr))) == 0xAA)
    }

    @Test("SC.W fails when the address differs from the reservation")
    func SC_W_fails_on_different_address() throws {
        var m = initMachine()
        m = m.setRegister(10, 0x2000)
        m = m.setRegister(9, 0x3000)
        m = m.setRegister(11, 0x1234)
        m = m.storeMemoryWord(0x3000, 0x55)
        m = try exec(m, encW(0b00010, 0, 10, 0))
        m = try exec(m, encW(0b00011, 11, 9, 12))
        #expect(m.getRegister(12) == 1)
        #expect(Int64(try #require(loadWord(m.Memory, 0x3000))) == 0x55)
    }

    // ---- SC must fail when its width does not match the LR it pairs with ----
    @Test("SC.D after LR.W fails on a width mismatch")
    func SC_D_after_LR_W_width_mismatch() throws {
        let addr: Int64 = 0x2000
        var m = initMachine()
        m = m.setRegister(10, addr)
        m = m.setRegister(11, 0x1234)
        m = m.storeMemoryDoubleWord(addr, 0xAA)
        m = try exec(m, encW(0b00010, 0, 10, 0))    // lr.w (width 4) reserves addr
        m = try exec(m, encD(0b00011, 11, 10, 12))  // sc.d (width 8) at addr -> must fail
        #expect(m.getRegister(12) == 1)
        #expect(try #require(loadDouble(m.Memory, addr)) == 0xAA)
    }

    @Test("SC.W after LR.D fails on a width mismatch")
    func SC_W_after_LR_D_width_mismatch() throws {
        let addr: Int64 = 0x2000
        var m = initMachine()
        m = m.setRegister(10, addr)
        m = m.setRegister(11, 0x1234)
        m = m.storeMemoryDoubleWord(addr, 0xAA)
        m = try exec(m, encD(0b00010, 0, 10, 0))    // lr.d (width 8) reserves addr
        m = try exec(m, encW(0b00011, 11, 10, 12))  // sc.w (width 4) at addr -> must fail
        #expect(m.getRegister(12) == 1)
        #expect(try #require(loadDouble(m.Memory, addr)) == 0xAA)
    }

    // ---- AMO.W uses only the low 32 bits of rs2 on RV64 ----
    @Test("AMOMIN.W compares only low 32 bits of rs2")
    func AMOMIN_W_low32_of_rs2() throws {
        let addr: Int64 = 0x2000
        var m = initMachine()
        m = m.setRegister(10, addr)
        m = m.setRegister(11, 0x0000000100000005)
        m = m.storeMemoryWord(addr, 10)
        m = try exec(m, encW(0b10000, 11, 10, 12))
        #expect(m.getRegister(12) == 10)
        #expect(Int64(try #require(loadWord(m.Memory, addr))) == 5)
    }

    @Test("AMOMINU.W compares only low 32 bits of rs2")
    func AMOMINU_W_low32_of_rs2() throws {
        let addr: Int64 = 0x2000
        var m = initMachine()
        m = m.setRegister(10, addr)
        m = m.setRegister(11, 0x0000000100000005)
        m = m.storeMemoryWord(addr, 10)
        m = try exec(m, encW(0b11000, 11, 10, 12))
        #expect(m.getRegister(12) == 10)
        #expect(Int64(try #require(loadWord(m.Memory, addr))) == 5)
    }

    // ---- misaligned atomic address traps ----
    @Test("AMOADD.W traps on a misaligned address")
    func AMOADD_W_misaligned_trap() throws {
        var m = initMachine()
        m = m.setRegister(10, 0x2002)
        m = m.setRegister(11, 1)
        m = m.storeMemoryWord(0x2000, 0)
        m = m.storeMemoryWord(0x2004, 0)
        m = try exec(m, encW(0b00000, 11, 10, 12))
        guard case .Trap(.MemAddress) = m.RunState else {
            Issue.record("expected misalign trap, got \(m.RunState)")
            return
        }
    }

    @Test("AMOADD.D traps on a misaligned address")
    func AMOADD_D_misaligned_trap() throws {
        var m = initMachine()
        m = m.setRegister(10, 0x2004)
        m = m.setRegister(11, 1)
        m = m.storeMemoryDoubleWord(0x2000, 0)
        m = m.storeMemoryDoubleWord(0x2008, 0)
        m = try exec(m, encD(0b00000, 11, 10, 12))
        guard case .Trap(.MemAddress) = m.RunState else {
            Issue.record("expected misalign trap, got \(m.RunState)")
            return
        }
    }
}
