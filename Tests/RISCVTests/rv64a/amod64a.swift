import Testing

import RISCV

//===============================================
// A-extension `.D` atomics tests
struct RV64aAMODTests {
    // Encode an A-extension `.D` instruction (funct3 = 0b011, aq = rl = 0)
    // with rd = x12, rs1 = x10 (address), rs2 = x11 (operand).
    // Distinct rs1/rs2 so a regression to rs2 = rs1 is caught.
    func encodeD(_ funct5: UInt32) -> Int32 {
        Int32(bitPattern: funct5 << 27 | UInt32(11) << 20 | UInt32(10) << 15 | 0b011 << 12 | UInt32(12) << 7 | 0b0101111)
    }

    // Decode + execute one `.D` atomic against memory[addr] = memVal, x11 = rs2Val.
    // Returns (x12, memory-after) for assertions.
    func runD(_ funct5: UInt32, _ memVal: Int64, _ rs2Val: Int64) throws -> (Int64, Int64) {
        let addr: Int64 = 0x1000
        var mstate = InitMachineState(MemoryMap.empty, .RV64ia, false)
        mstate = mstate.setPC(0x80000000)
        mstate = mstate.setRunState(.Run)
        mstate = mstate.setRegister(10, addr)
        mstate = mstate.setRegister(11, rs2Val)
        mstate = mstate.storeMemoryDoubleWord(addr, memVal)
        let executor = try #require(Decoder.Decode(mstate, encodeD(funct5)))
        mstate = executor(mstate)
        #expect(mstate.PC == 0x80000004)
        return (mstate.getRegister(12), loadDouble(mstate.Memory, addr)!)
    }

    @Test("LR.D loads the doubleword")
    func LR_D() throws {
        let (rd, mem) = try runD(0b00010, 0x1122334455667788, Int64(bitPattern: 0xDEAD))
        #expect(rd == 0x1122334455667788)
        #expect(mem == 0x1122334455667788)
    }

    @Test("SC.D after LR.D stores rs2 and writes 0 to rd")
    func SC_D_after_LR_D() throws {
        let addr: Int64 = 0x1000
        var mstate = InitMachineState(MemoryMap.empty, .RV64ia, false)
        mstate = mstate.setPC(0x80000000)
        mstate = mstate.setRunState(.Run)
        mstate = mstate.setRegister(10, addr)
        mstate = mstate.setRegister(11, 0x2222)
        mstate = mstate.storeMemoryDoubleWord(addr, 0x1111)
        let lr = try #require(Decoder.Decode(mstate, encodeD(0b00010)))
        mstate = lr(mstate)
        let sc = try #require(Decoder.Decode(mstate, encodeD(0b00011)))
        mstate = sc(mstate)
        #expect(mstate.getRegister(12) == 0)
        #expect(loadDouble(mstate.Memory, addr)! == 0x2222)
    }

    @Test("AMOSWAP.D swaps memory and rs2")
    func AMOSWAP_D() throws {
        let (rd, mem) = try runD(0b00001, 100, 7)
        #expect(rd == 100)
        #expect(mem == 7)
    }

    @Test("AMOADD.D adds rs2 to memory")
    func AMOADD_D() throws {
        let (rd, mem) = try runD(0b00000, 100, 7)
        #expect(rd == 100)
        #expect(mem == 107)
    }

    @Test("AMOXOR.D")
    func AMOXOR_D() throws {
        let (rd, mem) = try runD(0b00100, 0b1100, 0b1010)
        #expect(rd == 0b1100)
        #expect(mem == 0b0110)
    }

    @Test("AMOAND.D")
    func AMOAND_D() throws {
        let (rd, mem) = try runD(0b01100, 0b1100, 0b1010)
        #expect(rd == 0b1100)
        #expect(mem == 0b1000)
    }

    @Test("AMOOR.D")
    func AMOOR_D() throws {
        let (rd, mem) = try runD(0b01000, 0b1100, 0b1010)
        #expect(rd == 0b1100)
        #expect(mem == 0b1110)
    }

    @Test("AMOMIN.D signed")
    func AMOMIN_D_signed() throws {
        let (rd, mem) = try runD(0b10000, -1, 1)
        #expect(rd == -1)
        #expect(mem == -1)
    }

    @Test("AMOMAX.D signed")
    func AMOMAX_D_signed() throws {
        let (rd, mem) = try runD(0b10100, -1, 1)
        #expect(rd == -1)
        #expect(mem == 1)
    }

    @Test("AMOMINU.D unsigned")
    func AMOMINU_D_unsigned() throws {
        let (rd, mem) = try runD(0b11000, -1, 1)
        #expect(rd == -1)
        #expect(mem == 1)
    }

    @Test("AMOMAXU.D unsigned")
    func AMOMAXU_D_unsigned() throws {
        let (rd, mem) = try runD(0b11100, -1, 1)
        #expect(rd == -1)
        #expect(mem == -1)
    }
}
