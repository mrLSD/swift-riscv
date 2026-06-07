// Replica of riscv-fs `ExecuteA.fs` (module ISA.RISCV.Execute.A)
//
// Single-hart simulator: LR/SC act as plain load/store plus the reservation
// bookkeeping; AMOs are a load + op + store. .NET arithmetic wraps silently —
// replicated with &+ and truncating conversions.

public enum ExecuteA {
    //=================================================
    // LR.W - Load-Reserved Word operation
    // This acts just like a lw in this implementation (no need for sync)
    // (except there's no immediate)
    static func execLR_W(_ rd: Register, _ rs1: Register, _ mstate: consuming MachineState) -> MachineState {
        let addr = mstate.alignByArchUnsign(mstate.getRegister(rs1))
        guard let memResult = mstate.loadMemoryWord(addr) else {
            return mstate.setRunState(.Trap(.MemAddress(addr)))
        }
        return mstate.setRegisterReserveIncPC(rd, Int64(memResult), addr, 4)
    }

    //=================================================
    // SC.W - Store Conditional Word
    // This acts just like a sd in this implementation, but it will
    // always set the check register to 0 (indicating load success)
    static func execSC_W(_ rd: Register, _ rs1: Register, _ rs2: Register, _ mstate: consuming MachineState) -> MachineState {
        let addr = mstate.alignByArchUnsign(mstate.getRegister(rs1))
        if mstate.Reservation?.0 == addr && mstate.Reservation?.1 == 4 {
            let mstate = mstate.storeMemoryWord(addr, mstate.getRegister(rs2))
            return mstate.setRegisterClearReservationIncPC(rd, 0)
        } else {
            return mstate.setRegisterClearReservationIncPC(rd, 1)
        }
    }

    //=================================================
    // AMOSWAP.W - AMO Swap word
    static func execAMOSWAP_W(_ rd: Register, _ rs1: Register, _ rs2: Register, _ mstate: consuming MachineState) -> MachineState {
        let addr = mstate.alignByArchUnsign(mstate.getRegister(rs1))
        let rs2Val = mstate.getRegister(rs2)

        guard let memResult = mstate.loadMemoryWord(addr) else {
            return mstate.setRunState(.Trap(.MemAddress(addr)))
        }
        let resMemOp = rs2Val
        return mstate.storeBytesSetRegisterIncPC(4, addr, resMemOp, rd, Int64(memResult))
    }

    //=================================================
    // AMOADD.W - AMO Add Word
    static func execAMOADD_W(_ rd: Register, _ rs1: Register, _ rs2: Register, _ mstate: consuming MachineState) -> MachineState {
        let addr = mstate.alignByArchUnsign(mstate.getRegister(rs1))
        let rs2Val = mstate.getRegister(rs2)

        guard let memResult = mstate.loadMemoryWord(addr) else {
            return mstate.setRunState(.Trap(.MemAddress(addr)))
        }
        let resMemOp = Int64(memResult) &+ rs2Val
        return mstate.storeBytesSetRegisterIncPC(4, addr, resMemOp, rd, Int64(memResult))
    }

    //=================================================
    // AMOXOR.W - AMO Xor Word
    static func execAMOXOR_W(_ rd: Register, _ rs1: Register, _ rs2: Register, _ mstate: consuming MachineState) -> MachineState {
        let addr = mstate.alignByArchUnsign(mstate.getRegister(rs1))
        let rs2Val = mstate.getRegister(rs2)

        guard let memResult = mstate.loadMemoryWord(addr) else {
            return mstate.setRunState(.Trap(.MemAddress(addr)))
        }
        let resMemOp = Int64(memResult) ^ rs2Val
        return mstate.storeBytesSetRegisterIncPC(4, addr, resMemOp, rd, Int64(memResult))
    }

    //=================================================
    // AMOAND.W - AMO And Word
    static func execAMOAND_W(_ rd: Register, _ rs1: Register, _ rs2: Register, _ mstate: consuming MachineState) -> MachineState {
        let addr = mstate.alignByArchUnsign(mstate.getRegister(rs1))
        let rs2Val = mstate.getRegister(rs2)

        guard let memResult = mstate.loadMemoryWord(addr) else {
            return mstate.setRunState(.Trap(.MemAddress(addr)))
        }
        let resMemOp = Int64(memResult) & rs2Val
        return mstate.storeBytesSetRegisterIncPC(4, addr, resMemOp, rd, Int64(memResult))
    }

    //=================================================
    // AMOOR.W - AMO Or Word
    static func execAMOOR_W(_ rd: Register, _ rs1: Register, _ rs2: Register, _ mstate: consuming MachineState) -> MachineState {
        let addr = mstate.alignByArchUnsign(mstate.getRegister(rs1))
        let rs2Val = mstate.getRegister(rs2)

        guard let memResult = mstate.loadMemoryWord(addr) else {
            return mstate.setRunState(.Trap(.MemAddress(addr)))
        }
        let resMemOp = Int64(memResult) | rs2Val
        return mstate.storeBytesSetRegisterIncPC(4, addr, resMemOp, rd, Int64(memResult))
    }

    //=================================================
    // AMOMIN.W - AMO Min Word
    static func execAMOMIN_W(_ rd: Register, _ rs1: Register, _ rs2: Register, _ mstate: consuming MachineState) -> MachineState {
        let addr = mstate.alignByArchUnsign(mstate.getRegister(rs1))
        let rs2Val = mstate.getRegister(rs2)

        guard let memResult = mstate.loadMemoryWord(addr) else {
            return mstate.setRunState(.Trap(.MemAddress(addr)))
        }
        let resMemOp: Int64 =
            if memResult > Int32(truncatingIfNeeded: rs2Val) {
                rs2Val
            } else {
                Int64(memResult)
            }
        return mstate.storeBytesSetRegisterIncPC(4, addr, resMemOp, rd, Int64(memResult))
    }

    //=================================================
    // AMOMAX.W - AMO Max Word
    static func execAMOMAX_W(_ rd: Register, _ rs1: Register, _ rs2: Register, _ mstate: consuming MachineState) -> MachineState {
        let addr = mstate.alignByArchUnsign(mstate.getRegister(rs1))
        let rs2Val = mstate.getRegister(rs2)

        guard let memResult = mstate.loadMemoryWord(addr) else {
            return mstate.setRunState(.Trap(.MemAddress(addr)))
        }
        let resMemOp: Int64 =
            if memResult < Int32(truncatingIfNeeded: rs2Val) {
                rs2Val
            } else {
                Int64(memResult)
            }
        return mstate.storeBytesSetRegisterIncPC(4, addr, resMemOp, rd, Int64(memResult))
    }

    //=================================================
    // AMOMINU.W - AMO Unsigned Min Word
    static func execAMOMINU_W(_ rd: Register, _ rs1: Register, _ rs2: Register, _ mstate: consuming MachineState) -> MachineState {
        let addr = mstate.alignByArchUnsign(mstate.getRegister(rs1))
        let rs2Val = mstate.getRegister(rs2)

        guard let memResult = mstate.loadMemoryWord(addr) else {
            return mstate.setRunState(.Trap(.MemAddress(addr)))
        }
        let resMemOp: Int64 =
            if UInt32(bitPattern: memResult) > UInt32(truncatingIfNeeded: rs2Val) {
                rs2Val
            } else {
                Int64(memResult)
            }
        return mstate.storeBytesSetRegisterIncPC(4, addr, resMemOp, rd, Int64(memResult))
    }

    //=================================================
    // AMOMAXU.W - AMO Unsigned Max Word
    static func execAMOMAXU_W(_ rd: Register, _ rs1: Register, _ rs2: Register, _ mstate: consuming MachineState) -> MachineState {
        let addr = mstate.alignByArchUnsign(mstate.getRegister(rs1))
        let rs2Val = mstate.getRegister(rs2)

        guard let memResult = mstate.loadMemoryWord(addr) else {
            return mstate.setRunState(.Trap(.MemAddress(addr)))
        }
        let resMemOp: Int64 =
            if UInt32(bitPattern: memResult) < UInt32(truncatingIfNeeded: rs2Val) {
                rs2Val
            } else {
                Int64(memResult)
            }
        return mstate.storeBytesSetRegisterIncPC(4, addr, resMemOp, rd, Int64(memResult))
    }

    /// Execute A-instructions
    public static func Execute(_ instr: InstructionA, _ mstate: consuming MachineState) -> MachineState {
        // Atomics require a 4-byte-aligned address; check before dispatch.
        let rawAddr: Int64 =
            switch instr {
            case let .LR_W(_, rs1, _, _):
                mstate.getRegister(rs1)
            case let .SC_W(_, rs1, _, _, _), let .AMOSWAP_W(_, rs1, _, _, _),
                 let .AMOADD_W(_, rs1, _, _, _), let .AMOXOR_W(_, rs1, _, _, _),
                 let .AMOAND_W(_, rs1, _, _, _), let .AMOOR_W(_, rs1, _, _, _),
                 let .AMOMIN_W(_, rs1, _, _, _), let .AMOMAX_W(_, rs1, _, _, _),
                 let .AMOMINU_W(_, rs1, _, _, _), let .AMOMAXU_W(_, rs1, _, _, _):
                mstate.getRegister(rs1)
            case .None:
                0
            }
        let addr = mstate.alignByArchUnsign(rawAddr)
        if instr != InstructionA.None && addr % 4 != 0 {
            return mstate.setRunState(.Trap(.MemAddress(addr)))
        }
        switch instr {
        case let .LR_W(rd, rs1, _, _):
            return execLR_W(rd, rs1, mstate)
        case let .SC_W(rd, rs1, rs2, _, _):
            return execSC_W(rd, rs1, rs2, mstate)
        case let .AMOSWAP_W(rd, rs1, rs2, _, _):
            return execAMOSWAP_W(rd, rs1, rs2, mstate)
        case let .AMOADD_W(rd, rs1, rs2, _, _):
            return execAMOADD_W(rd, rs1, rs2, mstate)
        case let .AMOXOR_W(rd, rs1, rs2, _, _):
            return execAMOXOR_W(rd, rs1, rs2, mstate)
        case let .AMOAND_W(rd, rs1, rs2, _, _):
            return execAMOAND_W(rd, rs1, rs2, mstate)
        case let .AMOOR_W(rd, rs1, rs2, _, _):
            return execAMOOR_W(rd, rs1, rs2, mstate)
        case let .AMOMIN_W(rd, rs1, rs2, _, _):
            return execAMOMIN_W(rd, rs1, rs2, mstate)
        case let .AMOMAX_W(rd, rs1, rs2, _, _):
            return execAMOMAX_W(rd, rs1, rs2, mstate)
        case let .AMOMINU_W(rd, rs1, rs2, _, _):
            return execAMOMINU_W(rd, rs1, rs2, mstate)
        case let .AMOMAXU_W(rd, rs1, rs2, _, _):
            return execAMOMAXU_W(rd, rs1, rs2, mstate)
        case .None:
            return mstate.setRunState(.Trap(.InstructionExecute))
        }
    }
}
