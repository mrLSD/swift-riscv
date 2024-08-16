import Foundation

/// Protocol for Device bus in address space
protocol BusDevice {
    /// Address space start
    var startAddress: MachineValue { get }
    /// Address space end
    var endAddress: MachineValue { get }

    /// Read device data from specific address spaces and return data array
    func read(from fromAddress: MachineValue, to toAddress: MachineValue) -> Result<[UInt8], BusDeviceErrors>
    /// Write device data to specific address.
    func write(to address: MachineValue, data: UInt8) -> Result<Void, BusDeviceErrors>
}

extension BusDevice {
    /// Read byte (u8) from the memory
    func readByte(from address: MachineValue) -> Result<MachineValue, BusDeviceErrors> {
        read(from: address, to: address).flatMap { data in
            let result = switch address {
            case .x32: MachineValue(from: UInt32(combineBytes32(data)))
            case .x64: MachineValue(from: UInt64(combineBytes64(data)))
            }
            return .success(result)
        }
    }

    /// Read half word (u16) rom the memory
    func readHalfWord(from address: MachineValue) -> Result<MachineValue, BusDeviceErrors> {
        read(from: address, to: address + 1).flatMap { data in
            let result = switch address {
            case .x32: MachineValue(from: UInt32(combineBytes32(data)))
            case .x64: MachineValue(from: UInt64(combineBytes64(data)))
            }
            return .success(result)
        }
    }

    /// Read word (u32) from the memory
    func readWord(from address: MachineValue) -> Result<MachineValue, BusDeviceErrors> {
        read(from: address, to: address + 3).flatMap { data in
            let result = switch address {
            case .x32: MachineValue(from: UInt32(combineBytes32(data)))
            case .x64: MachineValue(from: UInt64(combineBytes64(data)))
            }
            return .success(result)
        }
    }

    /// Read double word (u64) from the memory
    func readDoubleWord(from address: MachineValue) -> Result<MachineValue, BusDeviceErrors> {
        read(from: address, to: address + 7).flatMap { data in
            switch address {
            case .x32: .failure(.memoryReadX64forX32)
            case .x64: .success(MachineValue(from: UInt64(combineBytes64(data))))
            }
        }
    }

    /// Write device data to specific address.
    func writeData(to address: MachineValue, data: MachineValue, index: Int) -> Result<Void, BusDeviceErrors> {
        // Convert to UInt64, as for UInt32 it will just extended with zero.
        let value = switch data {
        case .x32(let x): UInt64(x)
        case .x64(let x): x
        }
        for i in 0 ... index {
            if case .failure(let err) = write(to: address + i, data: UInt8((value >> i * 8) & 0xFF)) {
                return .failure(err)
            }
        }
        return .success(())
    }

    /// Write byte (u8) to the memory
    func writeByte(from address: MachineValue, data: MachineValue) -> Result<Void, BusDeviceErrors> {
        writeData(to: address, data: data, index: 0)
    }

    /// Write half word (u16) to the memory
    func writeHalfWord(from address: MachineValue, data: MachineValue) -> Result<Void, BusDeviceErrors> {
        writeData(to: address, data: data, index: 2)
    }

    /// Write word (u32) to the memory
    func writeWord(from address: MachineValue, data: MachineValue) -> Result<Void, BusDeviceErrors> {
        writeData(to: address, data: data, index: 4)
    }

    /// Write double word (u64) to the memory
    func writeDoubleWord(from address: MachineValue, data: MachineValue) -> Result<Void, BusDeviceErrors> {
        switch address {
        case .x32:
            .failure(.memoryWriteX64forX32)
        case .x64:
            writeData(to: address, data: data, index: 8)
        }
    }
}

/// Bus devise errors
enum BusDeviceErrors: Error {
    /// Devise read only
    case readOnly
    /// Access to devise out of address space
    case outOfAddressSpace
    /// When try read for x32 arch x64 value from memory
    case memoryReadX64forX32
    /// When try write for x32 arch x64 value to memory
    case memoryWriteX64forX32
}

/// ROM device
class ROM: BusDevice {
    let startAddress: MachineValue
    let endAddress: MachineValue
    private var memory: [UInt8]

    init(startAddress: MachineValue, size: MachineValue) {
        self.startAddress = startAddress
        self.endAddress = startAddress + size - 1
        // Init memory with zero values
        self.memory = Array(repeating: 0, count: Int(size))
    }

    func read(from fromAddress: MachineValue, to toAddress: MachineValue) -> Result<[UInt8], BusDeviceErrors> {
        .success(Array(memory[Int(fromAddress - startAddress) ... Int(toAddress - startAddress)]))
    }

    func write(to address: MachineValue, data: UInt8) -> Result<Void, BusDeviceErrors> {
        .failure(.readOnly)
    }
}

/// RAM device
class RAM: BusDevice {
    let startAddress: MachineValue
    let endAddress: MachineValue
    private var memory: [UInt8]

    init(startAddress: MachineValue, size: MachineValue) {
        self.startAddress = startAddress
        self.endAddress = startAddress + size - 1
        // Init memory with zero values
        self.memory = Array(repeating: 0, count: Int(size))
    }

    func read(from fromAddress: MachineValue, to toAddress: MachineValue) -> Result<[UInt8], BusDeviceErrors> {
        .success(Array(memory[Int(fromAddress - startAddress) ... Int(toAddress - startAddress)]))
    }

    func write(to address: MachineValue, data: UInt8) -> Result<Void, BusDeviceErrors> {
        memory[Int(address - startAddress)] = data
        return .success(())
    }
}

/// Main bus
/// Each device has own address space
class Bus {
    private var devices: [BusDevice] = []

    /// Add device to the Bus
    func addDevice(_ device: BusDevice) {
        devices.append(device)
    }

    /// Read byte (u8) the Bus from address
    /// Specific `Device` recognised from device address space
    func readByte(from address: MachineValue) -> Result<MachineValue, BusDeviceErrors> {
        for device in devices {
            if address >= device.startAddress, address <= device.endAddress {
                return device.readByte(from: address)
            }
        }
        return .failure(.outOfAddressSpace)
    }

    /// Read half word (u16) the Bus from address
    /// Specific `Device` recognised from device address space
    func readHalfWord(from address: MachineValue) -> Result<MachineValue, BusDeviceErrors> {
        for device in devices {
            if address >= device.startAddress, address <= device.endAddress {
                return device.readHalfWord(from: address)
            }
        }
        return .failure(.outOfAddressSpace)
    }

    /// Read  word (u32) the Bus from address
    /// Specific `Device` recognised from device address space
    func readWord(from address: MachineValue) -> Result<MachineValue, BusDeviceErrors> {
        for device in devices {
            if address >= device.startAddress, address <= device.endAddress {
                return device.readWord(from: address)
            }
        }
        return .failure(.outOfAddressSpace)
    }

    /// Read double word (u64) the Bus from address.
    /// **Only for x64-arch**
    /// Specific `Device` recognised from device address space
    func readDoubleWord(from address: MachineValue) -> Result<MachineValue, BusDeviceErrors> {
        for device in devices {
            if address >= device.startAddress, address <= device.endAddress {
                return device.readDoubleWord(from: address)
            }
        }
        return .failure(.outOfAddressSpace)
    }

    /// Read to the Bus to specific address
    /// Specific `Device` recognized from device address space
    func write(to address: MachineValue, data: MachineValue) -> Result<Void, BusDeviceErrors> {
        for device in devices {
            if address >= device.startAddress, address <= device.endAddress {
                // return device.write(to: address, data: data)
            }
        }
        return .failure(.outOfAddressSpace)
    }
}
