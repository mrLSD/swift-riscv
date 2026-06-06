import Testing

import RISCV

//===============================================
// Upper immediate tests
@Suite struct RV64iUITests {
    func Ui(_ instr: UInt32, _ x3: Int64) throws {
        // Init MachineState
        let addr: Int64 = 0x80000000
        var mstate = InitMachineState(.empty, .RV64i, true)
        mstate = mstate.setPC(addr)

        let executor = try #require(Decoder.Decode(mstate, Int32(bitPattern: instr)))
        mstate = executor(mstate)
        #expect(mstate.getRegister(3) == x3)
    }

    @Test("LUI: x3, imm20", arguments: [
        (UInt32(0x0000a1b7), Int64(0xA000)),
        (UInt32(0x000001b7), Int64(0x0)),
        (UInt32(0xfffff1b7), Int64(bitPattern: 0xfffffffffffff000)),
        (UInt32(0x0aff01b7), Int64(0xaff0000)),
        (UInt32(0x8aff01b7), Int64(bitPattern: 0xffffffff8aff0000)),
    ])
    func LUI(_ instr: UInt32, _ x3: Int64) throws {
        try Ui(instr, x3)
    }

    @Test("AUIPC: x3, imm20", arguments: [
        (UInt32(0x0000a197), Int64(0x8000a000)),
        (UInt32(0x00000197), Int64(0x80000000)),
        (UInt32(0xfffff197), Int64(0x7ffff000)),
    ])
    func AUIPC(_ instr: UInt32, _ x3: Int64) throws {
        try Ui(instr, x3)
    }
}
