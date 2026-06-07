import Testing

import RISCV

struct UnitUnitsTests {
    @Test("Architecture.fromString parses every valid arch", arguments: [
        "rv32i",
        "rv64i",
        "rv32im",
        "rv64im",
        "rv32ia",
        "rv64ia",
        "rv32ima",
        "rv64ima",
        "rv32ic",
        "rv64ic",
        "rv32imc",
        "rv64imc",
        "rv32iac",
        "rv64iac",
        "rv32imac",
        "rv64imac",
        "rv32izicsr",
        "rv64izicsr",
        "rv32if",
        "rv64if",
        "rv32ifc",
        "rv64ifc",
    ])
    func ArchitectureFromStringParsesEveryValidArch(_ s: String) {
        #expect(Architecture.fromString(s) != nil)
    }

    @Test("Architecture.fromString rejects an unknown arch")
    func ArchitectureFromStringRejectsUnknownArch() {
        #expect(Architecture.fromString("rv128gc") == nil)
    }

    // Truth table mirrored from Arch.fs (archBits / hasM / hasA / hasC / hasF / hasZicsr)
    @Test("Architecture predicates", arguments: [
        // (arch, archBits, hasM, hasA, hasC, hasF, hasZicsr)
        (Architecture.RV32, Architecture.RV32, false, false, false, false, false),
        (Architecture.RV64, Architecture.RV64, false, false, false, false, false),
        (Architecture.RV32i, Architecture.RV32, false, false, false, false, false),
        (Architecture.RV64i, Architecture.RV64, false, false, false, false, false),
        (Architecture.RV32im, Architecture.RV32, true, false, false, false, false),
        (Architecture.RV64im, Architecture.RV64, true, false, false, false, false),
        (Architecture.RV32ia, Architecture.RV32, false, true, false, false, false),
        (Architecture.RV64ia, Architecture.RV64, false, true, false, false, false),
        (Architecture.RV32ima, Architecture.RV32, true, true, false, false, false),
        (Architecture.RV64ima, Architecture.RV64, true, true, false, false, false),
        (Architecture.RV32ic, Architecture.RV32, false, false, true, false, false),
        (Architecture.RV64ic, Architecture.RV64, false, false, true, false, false),
        (Architecture.RV32imc, Architecture.RV32, true, false, true, false, false),
        (Architecture.RV64imc, Architecture.RV64, true, false, true, false, false),
        (Architecture.RV32iac, Architecture.RV32, false, true, true, false, false),
        (Architecture.RV64iac, Architecture.RV64, false, true, true, false, false),
        (Architecture.RV32imac, Architecture.RV32, true, true, true, false, false),
        (Architecture.RV64imac, Architecture.RV64, true, true, true, false, false),
        (Architecture.RV32izicsr, Architecture.RV32, false, false, false, false, true),
        (Architecture.RV64izicsr, Architecture.RV64, false, false, false, false, true),
        (Architecture.RV32if, Architecture.RV32, false, false, false, true, true),
        (Architecture.RV64if, Architecture.RV64, false, false, false, true, true),
        (Architecture.RV32ifc, Architecture.RV32, false, false, true, true, true),
        (Architecture.RV64ifc, Architecture.RV64, false, false, true, true, true),
    ])
    func ArchitecturePredicates(
        _ arch: Architecture,
        _ archBits: Architecture,
        _ hasM: Bool,
        _ hasA: Bool,
        _ hasC: Bool,
        _ hasF: Bool,
        _ hasZicsr: Bool
    ) {
        #expect(arch.archBits == archBits)
        #expect(arch.hasM == hasM)
        #expect(arch.hasA == hasA)
        #expect(arch.hasC == hasC)
        #expect(arch.hasF == hasF)
        #expect(arch.hasZicsr == hasZicsr)
    }

    @Test("Int64 bit helpers")
    func Int64BitHelpers() {
        let x: Int64 = 0b1010
        #expect(x.bitSlice(3, 2) == 0b10)
        #expect(x.isSet(1))
        #expect(!x.isSet(0))
        #expect(x.toHex == "0xa")
        #expect(x.toBin.count == 64)
        #expect(x.toArray == [1, 3])
        x.print()
        x.display()
    }

    @Test("combineBytes over empty, single and multi-byte arrays")
    func CombineBytesOverEmptySingleAndMultiByteArrays() {
        #expect(combineBytes([]) == 0)                          // empty range branch
        #expect(combineBytes([0xAB]) == 0xAB)                   // single byte
        #expect(combineBytes([0xAB, 0xCD]) == 0xCDAB)           // little-endian combine
    }

    @Test("load helpers return None on unmapped memory")
    func LoadHelpersReturnNoneOnUnmappedMemory() {
        let mem = MemoryMap.empty
        #expect(loadByte(mem, 0) == nil)
        #expect(loadHalfWord(mem, 0) == nil)
        #expect(loadWord(mem, 0) == nil)
        #expect(loadDouble(mem, 0) == nil)
    }

    @Test("getMemory returns Some for mapped and None for unmapped")
    func GetMemoryReturnsSomeForMappedAndNoneForUnmapped() {
        var m = InitMachineState(.empty, .RV32i, false)
        m = m.setMemoryByte(0x10, 0xAB)
        #expect(m.getMemory(0x10) == 0xAB)
        #expect(m.getMemory(0x20) == nil)
    }

    @Test("setRegister does not mutate the source state")
    func SetRegisterDoesNotMutateTheSourceState() {
        let m0 = InitMachineState(.empty, .RV64i, false)
        let m1 = m0.setRegister(1, 99)
        #expect(m0.getRegister(1) == 0)
        #expect(m1.getRegister(1) == 99)
    }
}
