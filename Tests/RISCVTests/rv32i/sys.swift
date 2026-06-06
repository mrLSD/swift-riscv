import Testing

import RISCV

//===============================================
// System tests
@Suite struct RV32iSysTests {
    func System(_ instr: UInt32, _ trap: Bool) throws -> MachineState {
        // Init MachineState
        let addr: Int64 = 0x80000000
        var mstate = InitMachineState(.empty, .RV32i, true)
        mstate = mstate.setPC(addr)
        let newmstate = mstate.incPC()

        let executor = try #require(Decoder.Decode(mstate, Int32(bitPattern: instr)))
        mstate = executor(mstate)

        if trap {
            #expect(mstate.PC == addr)
        } else {
            #expect(mstate.PC == newmstate.PC)
        }
        return mstate
    }

    @Test("FENCE", arguments: [
        UInt32(0x0ff0000f),
    ])
    func FENCE(_ instr: UInt32) throws {
        let mstate = try System(instr, false)
        #expect(mstate.RunState == .NotRun)
    }

    @Test("ECALL", arguments: [
        UInt32(0x00000073),
    ])
    func ECALL(_ instr: UInt32) throws {
        let mstate = try System(instr, true)
        #expect(mstate.RunState == .Trap(.ECall))
    }

    @Test("EBREAK", arguments: [
        UInt32(0x00100073),
    ])
    func EBREAK(_ instr: UInt32) throws {
        let mstate = try System(instr, true)
        #expect(mstate.RunState == .Trap(.EBreak))
    }
}
