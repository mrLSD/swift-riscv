import Testing

import RISCV

//===============================================
// ALU tests
struct RV64aAMOTests {
    func ALU(_ instrs: [UInt32], _ a4: Int64, _ a5: Int64, _ a6: Int64, _ a7: Int64) throws {
        // Init MachineState
        let addr: Int64 = 0x80000000
        var mstate = InitMachineState(MemoryMap.empty, .RV64ia, true)
        mstate = mstate.setPC(addr)
        mstate = mstate.setRunState(.Run)

        for w in instrs {
            let pc = mstate.PC
            let executor = try #require(Decoder.Decode(mstate, Int32(bitPattern: w)))
            mstate = executor(mstate)
            #expect(mstate.RunState == .Run)
            #expect(pc + 4 == mstate.PC)
        }
        let x14 = mstate.getRegister(14)
        let x15 = mstate.getRegister(15)
        let x16 = mstate.getRegister(16)
        let x17 = mstate.getRegister(17)

        #expect(x14 == a4)
        #expect(x15 == a5)
        #expect(x16 == a6)
        #expect(x17 == a7)
    }

    @Test("AMO.ADD", arguments: [
        (Int64(bitPattern: 0xffffffff80000000), Int64(0x000000007ffff800), Int64(0x000000007ffff800), Int64(bitPattern: 0xfffffffffffff800)),
    ])
    func AMO_ADD(_ a4: Int64, _ a5: Int64, _ a6: Int64, _ a7: Int64) throws {
        let instrSet: [UInt32] = [
            0x80000537,
            0x80000593,
            0x00001697,
            0xff868693,
            0x00a6a023,

            0x00b6a72f,
            0x0006a783,
            0x800005b7,
            0x00b6a82f,
            0x0006a883,
        ]
        try ALU(instrSet, a4, a5, a6, a7)
    }

    @Test("AMO.AND", arguments: [
        (Int64(bitPattern: 0xffffffff80000000), Int64(bitPattern: 0xffffffff80000000), Int64(bitPattern: 0xffffffff80000000), Int64(bitPattern: 0xffffffff80000000)),
    ])
    func AMO_AND(_ a4: Int64, _ a5: Int64, _ a6: Int64, _ a7: Int64) throws {
        let instrSet: [UInt32] = [
            0x80000537,
            0x80000593,
            0x00001697,
            0xff868693,
            0x00a6a023,

            0x60b6a72f,
            0x0006a783,
            0x80000637,
            0x60c6a82f,
            0x0006a883,
        ]
        try ALU(instrSet, a4, a5, a6, a7)
    }

    @Test("AMO.OR", arguments: [
        (Int64(bitPattern: 0xffffffff80000000), Int64(bitPattern: 0xfffffffffffff800), Int64(bitPattern: 0xfffffffffffff800), Int64(bitPattern: 0xfffffffffffff801)),
    ])
    func AMO_OR(_ a4: Int64, _ a5: Int64, _ a6: Int64, _ a7: Int64) throws {
        let instrSet: [UInt32] = [
            0x80000537,
            0x80000593,
            0x00001697,
            0xff868693,
            0x00a6a023,

            0x40b6a72f,
            0x0006a783,
            0x00100613,
            0x40c6a82f,
            0x0006a883,
        ]
        try ALU(instrSet, a4, a5, a6, a7)
    }

    @Test("AMO.XOR", arguments: [
        (Int64(bitPattern: 0xffffffff80000000), Int64(0x7ffff800), Int64(0x7ffff800), Int64(bitPattern: 0xffffffffbffff801)),
    ])
    func AMO_XOR(_ a4: Int64, _ a5: Int64, _ a6: Int64, _ a7: Int64) throws {
        let instrSet: [UInt32] = [
            0x80000537,
            0x80000593,
            0x00001697,
            0xff868693,
            0x00a6a023,

            0x20b6a72f,
            0x0006a783,
            0xc0000637,
            0x00160613,
            0x20c6a82f,
            0x0006a883,
        ]
        try ALU(instrSet, a4, a5, a6, a7)
    }

    @Test("AMO.SWAP", arguments: [
        (Int64(bitPattern: 0xffffffff80000000), Int64(bitPattern: 0xfffffffffffff800), Int64(bitPattern: 0xfffffffffffff800), Int64(bitPattern: 0xffffffff80000000)),
    ])
    func AMO_SWAP(_ a4: Int64, _ a5: Int64, _ a6: Int64, _ a7: Int64) throws {
        let instrSet: [UInt32] = [
            0x80000537,
            0x80000593,
            0x00001697,
            0xff868693,
            0x00a6a023,

            0x08b6a72f,
            0x0006a783,
            0x80000637,
            0x08c6a82f,
            0x0006a883,
        ]
        try ALU(instrSet, a4, a5, a6, a7)
    }

    @Test("AMO.MAX", arguments: [
        (Int64(bitPattern: 0xffffffff80000000), Int64(bitPattern: 0xfffffffffffff800), Int64(0), Int64(1)),
    ])
    func AMO_MAX(_ a4: Int64, _ a5: Int64, _ a6: Int64, _ a7: Int64) throws {
        let instrSet: [UInt32] = [
            0x80000537,
            0x80000593,
            0x00001697,
            0xff868693,
            0x00a6a023,

            0xa0b6a72f,
            0x0006a783,
            0x00100613,
            0x0006a023,
            0xa0c6a82f,
            0x0006a883,
        ]
        try ALU(instrSet, a4, a5, a6, a7)
    }

    @Test("AMO.MAXU", arguments: [
        (Int64(bitPattern: 0xffffffff80000000), Int64(bitPattern: 0xfffffffffffff800), Int64(0), Int64(bitPattern: 0xffffffffffffffff)),
    ])
    func AMO_MAXU(_ a4: Int64, _ a5: Int64, _ a6: Int64, _ a7: Int64) throws {
        let instrSet: [UInt32] = [
            0x80000537,
            0x80000593,
            0x00001697,
            0xff868693,
            0x00a6a023,

            0xe0b6a72f,
            0x0006a783,
            0xfff00613,
            0x0006a023,
            0xe0c6a82f,
            0x0006a883,
        ]
        try ALU(instrSet, a4, a5, a6, a7)
    }

    @Test("AMO.MIN", arguments: [
        (Int64(bitPattern: 0xffffffff80000000), Int64(bitPattern: 0xffffffff80000000), Int64(0), Int64(bitPattern: 0xffffffffffffffff)),
    ])
    func AMO_MIN(_ a4: Int64, _ a5: Int64, _ a6: Int64, _ a7: Int64) throws {
        let instrSet: [UInt32] = [
            0x80000537,
            0x80000593,
            0x00001697,
            0xff868693,
            0x00a6a023,

            0x80b6a72f,
            0x0006a783,
            0xfff00613,
            0x0006a023,
            0x80c6a82f,
            0x0006a883,
        ]
        try ALU(instrSet, a4, a5, a6, a7)
    }

    @Test("AMO.MINU", arguments: [
        (Int64(bitPattern: 0xffffffff80000000), Int64(bitPattern: 0xffffffff80000000), Int64(0), Int64(0)),
    ])
    func AMO_MINU(_ a4: Int64, _ a5: Int64, _ a6: Int64, _ a7: Int64) throws {
        let instrSet: [UInt32] = [
            0x80000537,
            0x80000593,
            0x00001697,
            0xff868693,
            0x00a6a023,

            0xc0b6a72f,
            0x0006a783,
            0xfff00613,
            0x0006a023,
            0xc0c6a82f,
            0x0006a883,
        ]
        try ALU(instrSet, a4, a5, a6, a7)
    }
}
