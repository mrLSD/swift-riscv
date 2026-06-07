import Testing

import RISCV

//===============================================
// Memory tests
@Suite struct RV64iMemTests {
    // Load from memory instructions
    func loadMemory(_ instr: UInt32, _ x2: Int64, _ imm: Int64, _ nBytes: Int, _ unsign: Bool) throws {
        // Init MachineState
        let addr: Int64 = 0x80000000
        var mstate = InitMachineState(.empty, .RV64i, true)
        mstate = mstate.setPC(addr)
        mstate = mstate.setRegister(2, x2)

        // Set memory value
        let memAddr = x2 + imm
        let resNumber: Int64
        switch nBytes {
        case 1: // 1 bytes
            let data = unsign ? Int64(0x85 as UInt8) : Int64(Int8(bitPattern: 0x85))
            mstate = mstate.setMemoryByte(memAddr, 0x85)
            resNumber = data
        case 2: // 2 bytes
            let data = unsign ? Int64(0xa10f as UInt16) : Int64(Int16(bitPattern: 0xa10f))
            mstate = mstate.setMemoryByte(memAddr, 0x0f)
            mstate = mstate.setMemoryByte(memAddr + 1, 0xa1)
            resNumber = data
        default: // 4 bytes
            // LW sign-extends the 32-bit value
            let data = Int64(Int32(bitPattern: 0xc3b2a10f))
            mstate = mstate.setMemoryByte(memAddr, 0x0f)
            mstate = mstate.setMemoryByte(memAddr + 1, 0xa1)
            mstate = mstate.setMemoryByte(memAddr + 2, 0xb2)
            mstate = mstate.setMemoryByte(memAddr + 3, 0xc3)
            resNumber = data
        }

        let executor = try #require(Decoder.Decode(mstate, Int32(bitPattern: instr)))
        mstate = executor(mstate)
        #expect(mstate.getRegister(2) == x2)
        #expect(mstate.getRegister(3) == resNumber)
    }

    // Store to memory instructions
    func storeMemory(_ instr: UInt32, _ x3: Int64, _ x2: Int64, _ imm: Int64, _ nBytes: Int) throws {
        // Init MachineState
        let addr: Int64 = 0x80000000
        var mstate = InitMachineState(.empty, .RV64i, true)
        mstate = mstate.setPC(addr)
        mstate = mstate.setRegister(2, x2)
        mstate = mstate.setRegister(3, x3)

        let executor = try #require(Decoder.Decode(mstate, Int32(bitPattern: instr)))

        // Get memory value
        let memAddr = x2 + imm
        mstate = executor(mstate)
        let memoryRes: Int64
        switch nBytes {
        case 1: // 1 bytes
            memoryRes = Int64(Int8(try #require(loadByte(mstate.Memory, memAddr))))
        case 2: // 2 bytes
            memoryRes = Int64(try #require(loadHalfWord(mstate.Memory, memAddr)))
        default: // 4 bytes
            memoryRes = Int64(try #require(loadWord(mstate.Memory, memAddr)))
        }

        #expect(mstate.getRegister(2) == x2)
        #expect(mstate.getRegister(3) == x3)
        #expect(memoryRes == x3)
    }

    @Test("LB: x3, Imm(x2)", arguments: [
        (UInt32(0x00a10183), Int64(0x1000),  Int64(10)),
        (UInt32(0xff610183), Int64(0x1000), Int64(-10)),
    ])
    func LB(_ instr: UInt32, _ x2: Int64, _ imm: Int64) throws {
        try loadMemory(instr, x2, imm, 1, false)
    }

    @Test("LH: x3, Imm(x2)", arguments: [
        (UInt32(0x00a11183), Int64(0x1000),  Int64(10)),
        (UInt32(0xff611183), Int64(0x1000), Int64(-10)),
    ])
    func LH(_ instr: UInt32, _ x2: Int64, _ imm: Int64) throws {
        try loadMemory(instr, x2, imm, 2, false)
    }

    @Test("LW: x3, Imm(x2)", arguments: [
        (UInt32(0x00a12183), Int64(0x1000),  Int64(10)),
        (UInt32(0xff612183), Int64(0x1000), Int64(-10)),
    ])
    func LW(_ instr: UInt32, _ x2: Int64, _ imm: Int64) throws {
        try loadMemory(instr, x2, imm, 4, false)
    }

    @Test("LBU: x3, Imm(x2)", arguments: [
        (UInt32(0x00a14183), Int64(0x1000),  Int64(10)),
        (UInt32(0xff614183), Int64(0x1000), Int64(-10)),
    ])
    func LBU(_ instr: UInt32, _ x2: Int64, _ imm: Int64) throws {
        try loadMemory(instr, x2, imm, 1, true)
    }

    @Test("LHU: x3, Imm(x2)", arguments: [
        (UInt32(0x00a15183), Int64(0x1000),  Int64(10)),
        (UInt32(0xff615183), Int64(0x1000), Int64(-10)),
    ])
    func LHU(_ instr: UInt32, _ x2: Int64, _ imm: Int64) throws {
        try loadMemory(instr, x2, imm, 2, true)
    }

    @Test("SB: x3, Imm(x2)", arguments: [
        (UInt32(0x00310523), Int64(100),  Int64(0x1000),  Int64(10)),
        (UInt32(0xfe310b23), Int64(-100), Int64(0x1000), Int64(-10)),
    ])
    func SB(_ instr: UInt32, _ x3: Int64, _ x2: Int64, _ imm: Int64) throws {
        try storeMemory(instr, x3, x2, imm, 1)
    }

    @Test("SH: x3, Imm(x2)", arguments: [
        (UInt32(0x00311523), Int64(100),  Int64(0x1000),  Int64(10)),
        (UInt32(0xfe311b23), Int64(-100), Int64(0x1000), Int64(-10)),
    ])
    func SH(_ instr: UInt32, _ x3: Int64, _ x2: Int64, _ imm: Int64) throws {
        try storeMemory(instr, x3, x2, imm, 2)
    }

    @Test("SW: x3, Imm(x2)", arguments: [
        (UInt32(0x00312523), Int64(0x00001ac7), Int64(0x1000),  Int64(10)),
        (UInt32(0xfe312b23), Int64(-100),        Int64(0x1000), Int64(-10)),
    ])
    func SW(_ instr: UInt32, _ x3: Int64, _ x2: Int64, _ imm: Int64) throws {
        try storeMemory(instr, x3, x2, imm, 4)
    }
}
