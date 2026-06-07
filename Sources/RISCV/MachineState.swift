// Replica of riscv-fs `MachineState.fs` (module ISA.RISCV.MachineState)
//
// The F# reference is an immutable record: every transition returns a fresh state.
// The Swift replica keeps the same functional API (`let m2 = m1.setRegister(...)`) and
// the same observable value semantics, but the transition methods take `consuming self`
// so a chained `mstate = mstate.setRegister(...)` is a move — the register array and
// memory pages stay uniquely referenced and mutate in place (no copy), while keeping a
// prior state alive still snapshots it via copy-on-write.

public enum RunMachineState: Sendable, Equatable {
    case NotRun
    case Run
    case Stopped
    case Trap(TrapErrors)
}

public struct MachineState: Sendable {
    public var PC: MachineInt
    // Sealed setter: x0 is hardwired to 0 and every write is XLEN-normalized
    // (`alignByArch`), invariants that a direct external `Registers[i] = …` would
    // silently bypass. Reads stay public (observable semantics unchanged); all
    // mutation goes through the transition methods below.
    public private(set) var Registers: [RegisterVal]
    public var Memory: MemoryMap
    public var Verbosity: Bool
    public var Arch: Architecture
    // Cached architecture facts, derived from Arch once at init (the per-access
    // alternative is a 22-case enum switch on every register/PC write). Declared
    // right after the two 1-byte fields so they occupy existing padding bytes —
    // MachineState stays 88 bytes (verified by a layout probe). Invariant: always
    // equal to Arch.archBits == .RV32 / Arch.hasC.
    @usableFromInline var xlenIsRV32: Bool
    @usableFromInline var hasCExt: Bool
    public var RunState: RunMachineState
    /// LR/SC reservation: address and access width (bytes), or nil.
    public var Reservation: (MachineInt, Int)?
    public var InstrLen: Int

    // x0 always 0: maintained branchlessly through the invariant that
    // Registers[0] stays 0 — every register write unconditionally re-zeroes
    // slot 0 instead of branching on `reg == 0` (the classic interpreter trick).
    @inline(__always)
    public func getRegister(_ reg: Register) -> MachineInt {
        Registers[Int(reg)]
    }

    @inline(__always)
    public consuming func setRegister(_ reg: Register, _ value: MachineInt) -> MachineState {
        var mstate = self
        mstate.Registers[Int(reg)] = mstate.alignByArch(value)
        // Check x0 register that always 0
        mstate.Registers[0] = 0
        return mstate
    }

    // ---- fused transitions (internal) ----
    // The reference chains transitions (`setRegister(...).incPC()`), which costs
    // two whole-struct materializations per instruction. These fused variants do
    // the same observable work in ONE pass; the public replica API is unchanged.

    /// setRegister + incPC in a single transition.
    @inline(__always)
    consuming func setRegisterIncPC(_ reg: Register, _ value: MachineInt) -> MachineState {
        var mstate = self
        mstate.Registers[Int(reg)] = mstate.alignByArch(value)
        mstate.Registers[0] = 0
        mstate.PC = mstate.alignByArchUnsign(mstate.PC &+ Int64(mstate.InstrLen))
        return mstate
    }

    /// setRegister + setPC in a single transition (JAL/JALR link + jump).
    @inline(__always)
    consuming func setRegisterSetPC(_ reg: Register, _ value: MachineInt, _ pc: MachineInt) -> MachineState {
        var mstate = self
        mstate.Registers[Int(reg)] = mstate.alignByArch(value)
        mstate.Registers[0] = 0
        mstate.PC = mstate.alignByArchUnsign(pc)
        return mstate
    }

    /// setRegister + setReservation + incPC (LR.W/LR.D).
    @inline(__always)
    consuming func setRegisterReserveIncPC(_ reg: Register, _ value: MachineInt, _ addr: MachineInt, _ width: Int) -> MachineState {
        var mstate = self
        mstate.Registers[Int(reg)] = mstate.alignByArch(value)
        mstate.Registers[0] = 0
        mstate.Reservation = (addr, width)
        mstate.PC = mstate.alignByArchUnsign(mstate.PC &+ Int64(mstate.InstrLen))
        return mstate
    }

    /// setRegister + clearReservation + incPC (SC.W/SC.D result write).
    @inline(__always)
    consuming func setRegisterClearReservationIncPC(_ reg: Register, _ value: MachineInt) -> MachineState {
        var mstate = self
        mstate.Registers[Int(reg)] = mstate.alignByArch(value)
        mstate.Registers[0] = 0
        mstate.Reservation = nil
        mstate.PC = mstate.alignByArchUnsign(mstate.PC &+ Int64(mstate.InstrLen))
        return mstate
    }

    @inline(__always)
    public consuming func setPC(_ pc: MachineInt) -> MachineState {
        var mstate = self
        mstate.PC = mstate.alignByArchUnsign(pc)
        return mstate
    }

    @inline(__always)
    public consuming func incPC() -> MachineState {
        let pc = PC &+ Int64(InstrLen)
        return setPC(pc)
    }

    /// Instruction alignment (IALIGN): 2 bytes when C is supported, else 4.
    public var instrAlign: Int64 {
        hasCExt ? 2 : 4
    }

    public func getMemory(_ addr: Int64) -> UInt8? {
        let addr = alignByArchUnsign(addr)
        return Memory[addr]
    }

    public consuming func setMemoryByte(_ addr: Int64, _ value: UInt8) -> MachineState {
        var mstate = self
        let addr = mstate.alignByArchUnsign(addr)
        mstate.Memory.setByte(addr, value)
        return mstate
    }

    // Store `nBytes` little-endian bytes of `value` starting at `addr`, normalizing
    // EACH byte address to XLEN (alignByArchUnsign) like the reference. When the
    // normalized run is contiguous (no wrap past 2^XLEN) the store goes through the
    // page-level Span fast path; a wrapping run falls back to per-byte stores.
    private consuming func storeBytes(_ nBytes: Int, _ addr: MachineInt, _ value: MachineInt) -> MachineState {
        var mstate = self
        let first = mstate.alignByArchUnsign(addr)
        let last = mstate.alignByArchUnsign(addr &+ Int64(nBytes - 1))
        if last &- first == Int64(nBytes - 1) {
            mstate.Memory.storeBytes(nBytes, first, value)
        } else {
            for i in 0 ..< nBytes {
                let a = mstate.alignByArchUnsign(addr &+ Int64(i))
                mstate.Memory.setByte(a, UInt8(truncatingIfNeeded: value >> (i << 3)))
            }
        }
        return mstate
    }

    /// storeBytes + incPC in a single transition (internal; the store instructions).
    @inline(__always)
    private consuming func storeBytesIncPC(_ nBytes: Int, _ addr: MachineInt, _ value: MachineInt) -> MachineState {
        var mstate = self.storeBytes(nBytes, addr, value)
        mstate.PC = mstate.alignByArchUnsign(mstate.PC &+ Int64(mstate.InstrLen))
        return mstate
    }

    /// storeBytes + setRegister + incPC in a single transition (internal; the AMO
    /// read-modify-write instructions: store the op result, write rd = old value).
    @inline(__always)
    consuming func storeBytesSetRegisterIncPC(_ nBytes: Int, _ addr: MachineInt, _ memValue: MachineInt, _ reg: Register, _ regValue: MachineInt) -> MachineState {
        var mstate = self.storeBytes(nBytes, addr, memValue)
        mstate.Registers[Int(reg)] = mstate.alignByArch(regValue)
        mstate.Registers[0] = 0
        mstate.PC = mstate.alignByArchUnsign(mstate.PC &+ Int64(mstate.InstrLen))
        return mstate
    }

    @inline(__always)
    consuming func storeMemoryByteIncPC(_ addr: MachineInt, _ value: MachineInt) -> MachineState {
        storeBytesIncPC(1, addr, value)
    }

    @inline(__always)
    consuming func storeMemoryHalfWordIncPC(_ addr: MachineInt, _ value: MachineInt) -> MachineState {
        storeBytesIncPC(2, addr, value)
    }

    @inline(__always)
    consuming func storeMemoryWordIncPC(_ addr: MachineInt, _ value: MachineInt) -> MachineState {
        storeBytesIncPC(4, addr, value)
    }

    @inline(__always)
    consuming func storeMemoryDoubleWordIncPC(_ addr: MachineInt, _ value: MachineInt) -> MachineState {
        storeBytesIncPC(8, addr, value)
    }

    public consuming func storeMemoryByte(_ addr: MachineInt, _ value: MachineInt) -> MachineState {
        storeBytes(1, addr, value)
    }

    public consuming func storeMemoryHalfWord(_ addr: MachineInt, _ value: MachineInt) -> MachineState {
        storeBytes(2, addr, value)
    }

    public consuming func storeMemoryWord(_ addr: MachineInt, _ value: MachineInt) -> MachineState {
        storeBytes(4, addr, value)
    }

    public consuming func storeMemoryDoubleWord(_ addr: MachineInt, _ value: MachineInt) -> MachineState {
        storeBytes(8, addr, value)
    }

    // Symmetric with storeBytes: load `nBytes` little-endian bytes starting at `addr`,
    // normalizing EACH byte address to XLEN (alignByArchUnsign) just as the store path
    // does, so a multi-byte access that wraps past 2^XLEN reads the same bytes the
    // matching store wrote. Returns nil (=> the caller raises a MemAddress trap) if any
    // byte is unmapped.
    private func loadBytes(_ nBytes: Int, _ addr: MachineInt) -> MachineInt? {
        let first = alignByArchUnsign(addr)
        let last = alignByArchUnsign(addr &+ Int64(nBytes - 1))
        if last &- first == Int64(nBytes - 1) {
            return Memory.loadBytes(nBytes, first)
        }
        var acc: Int64 = 0
        for i in 0 ..< nBytes {
            let a = alignByArchUnsign(addr &+ Int64(i))
            guard let b = Memory[a] else { return nil }
            acc |= Int64(b) << (i << 3)
        }
        return acc
    }

    public func loadMemoryByte(_ addr: MachineInt) -> Int8? {
        loadBytes(1, addr).map { Int8(truncatingIfNeeded: $0) }
    }

    public func loadMemoryHalfWord(_ addr: MachineInt) -> Int16? {
        loadBytes(2, addr).map { Int16(truncatingIfNeeded: $0) }
    }

    public func loadMemoryWord(_ addr: MachineInt) -> Int32? {
        loadBytes(4, addr).map { Int32(truncatingIfNeeded: $0) }
    }

    public func loadMemoryDoubleWord(_ addr: MachineInt) -> Int64? {
        loadBytes(8, addr)
    }

    @inline(__always)
    public consuming func setRunState(_ state: RunMachineState) -> MachineState {
        var mstate = self
        mstate.RunState = state
        return mstate
    }

    /// Reservation tracks both the address and the access width (bytes): an SC
    /// succeeds only when it pairs with an LR of the same address and width.
    public consuming func setReservation(_ addr: MachineInt, _ width: Int) -> MachineState {
        var mstate = self
        mstate.Reservation = (addr, width)
        return mstate
    }

    public consuming func clearReservation() -> MachineState {
        var mstate = self
        mstate.Reservation = nil
        return mstate
    }

    /// Represent a signed value at the register width (XLEN):
    /// RV32 keeps the low 32 bits sign-extended; RV64 is unchanged.
    @inline(__always)
    public func alignByArch(_ value: Int64) -> Int64 {
        xlenIsRV32 ? Int64(Int32(truncatingIfNeeded: value)) : value
    }

    /// Represent an unsigned value at the width (XLEN), used for PC/addresses:
    /// RV32 keeps the low 32 bits zero-extended; RV64 is unchanged.
    @inline(__always)
    public func alignByArchUnsign(_ value: Int64) -> Int64 {
        xlenIsRV32 ? Int64(UInt32(truncatingIfNeeded: value)) : value
    }
}

public func InitMachineState(_ mem: MemoryMap, _ arch: Architecture, _ verbosity: Bool) -> MachineState {
    MachineState(
        PC: 0x8000_0000,
        Registers: [RegisterVal](repeating: 0, count: 32),
        Memory: mem,
        Verbosity: verbosity,
        Arch: arch,
        xlenIsRV32: arch.archBits == .RV32,
        hasCExt: arch.hasC,
        RunState: RunMachineState.NotRun,
        Reservation: nil,
        InstrLen: 4
    )
}
