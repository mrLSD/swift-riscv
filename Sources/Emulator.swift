import ArgumentParser

@main
struct Emulator: ParsableCommand {
    /// Emulator bus
    /// Address space calculated only from start address.
    /// End address calculated lile: nextStartAddress - 1.
    /// End of Bus address space marked as `endBusAddress`
    enum EmulatorBus {
        /// Start or ROM address space
        static let romAddress: UInt64 = 0x00_000_000
        /// Start or RAM address space
        static let ramAddress: UInt64 = 0x20_000_000
        /// End of Bus address space
        static let endBusAddress: UInt64 = 0x40_000_000

        static func initBus() -> Bus {
            let bus = Bus()
            let rom = ROM(startAddress: MachineValue(from: UInt64(Self.romAddress)), size: MachineValue(from: UInt64(Self.ramAddress - Self.romAddress)))
            bus.addDevice(rom)

            let ram = ROM(startAddress: MachineValue(from: UInt64(Self.romAddress)), size: MachineValue(from: UInt64(Self.endBusAddress - Self.ramAddress)))
            bus.addDevice(ram)

            return bus
        }
    }

    mutating func run() throws {
        // print(String(0b1111, radix: 16))
        print("RISC-V Swift")
        let arch: MachineArch = .x64
        // PC starts from ROM address
        let pc = MachineValue(from: UInt64(EmulatorBus.romAddress))
        let bus = EmulatorBus.initBus()
        let ms = MachineState(arch: arch, pc: pc, bus: bus)
        let result = ms.run()
        print("Result state: \(result)")
    }
}
