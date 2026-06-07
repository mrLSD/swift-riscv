import Testing

import RISCV

//===============================================
// Jump tests
@Suite struct RV32iJumpTests {
    func Jump(_ instr: UInt32, _ x2: Int64, _ x3: Int64, _ resultAddr: Int64) throws {
        // Init MachineState
        let addr: Int64 = 0x80000000
        var mstate = InitMachineState(.empty, .RV32i, true)
        mstate = mstate.setPC(addr)
        mstate = mstate.setRegister(2, x2)
        let resMstate = mstate.incPC()

        let executor = try #require(Decoder.Decode(mstate, Int32(bitPattern: instr)))
        mstate = executor(mstate)

        #expect(mstate.getRegister(2) == Int64(Int32(truncatingIfNeeded: x2)))
        let pcs = mstate.setPC(mstate.getRegister(3))
        #expect(pcs.PC == resMstate.PC)
        #expect(mstate.PC == resultAddr)
    }

    @Test("JAL: x3, addr", arguments: [
        (UInt32(0x018001ef), Int64(0x80000018)),
        (UInt32(0xff5ff1ef), Int64(0x7ffffff4)),
    ])
    func JAL(_ instr: UInt32, _ addrRes: Int64) throws {
        try Jump(instr, 0, 3, addrRes)
    }

    @Test("JALR: x3, x2, addr", arguments: [
        (UInt32(0x010101e7), Int64(0x80000000), Int64(0x80000010)),
        (UInt32(0xff0101e7), Int64(0x80000000), Int64(0x7ffffff0)),
    ])
    func JALR(_ instr: UInt32, _ x2: Int64, _ addrRes: Int64) throws {
        try Jump(instr, x2, 3, addrRes)
    }
}
