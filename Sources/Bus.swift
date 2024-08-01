import Foundation

/// Protocol for Device bus in address space
protocol BusDevice {
    /// Address space start
    var startAddress: MachineValue { get }
    /// Address space end
    var endAddress: MachineValue { get }

    /// Read device data from specific address
    func read(from address: MachineValue) -> Result<MachineValue, BusDeviceErrors>
    /// Write device data to specific address
    func write(to address: MachineValue, data: MachineValue) -> Result<Void, BusDeviceErrors>
}

/// Bus devise errors
enum BusDeviceErrors: Error {
    /// Devise read only
    case ReadOnly
    /// Access to devise out of address space
    case OutOfAddressSpace
}

/// ROM device
class ROM: BusDevice {
    let startAddress: MachineValue
    let endAddress: MachineValue
    private var memory: [MachineValue]

    init(startAddress: MachineValue, size: MachineValue) {
        self.startAddress = startAddress
        self.endAddress = startAddress + size - 1
        // Detect architecture and init zero value
        let zeroValue: MachineValue = switch startAddress {
        case .x32(_): .x32(0)
        case .x64(_): .x64(0)
        }
        // Init memory with zero values
        self.memory = Array(repeating: zeroValue, count: Int(size))
    }

    func read(from address: MachineValue) -> Result<MachineValue, BusDeviceErrors> {
        .success(memory[Int(address - startAddress)])
    }

    func write(to address: MachineValue, data: MachineValue) -> Result<Void, BusDeviceErrors> {
        .failure(.ReadOnly)
    }
}

/// RAM device
class RAM: BusDevice {
    let startAddress: MachineValue
    let endAddress: MachineValue
    private var memory: [MachineValue]

    init(startAddress: MachineValue, size: MachineValue) {
        self.startAddress = startAddress
        self.endAddress = startAddress + size - 1
        // Detect architecture and init zero value
        let zeroValue: MachineValue = switch startAddress {
        case .x32(_): .x32(0)
        case .x64(_): .x64(0)
        }
        // Init memory with zero values
        self.memory = Array(repeating: zeroValue, count: Int(size))
    }

    func read(from address: MachineValue) -> Result<MachineValue, BusDeviceErrors> {
        .success(memory[Int(address - startAddress)])
    }

    func write(to address: MachineValue, data: MachineValue) -> Result<Void, BusDeviceErrors> {
        memory[Int(address - startAddress)] = data
        return .success(())
    }
}

/// Main bus
class Bus {
    private var devices: [BusDevice] = []

    func addDevice(_ device: BusDevice) {
        devices.append(device)
    }

    func read(from address: MachineValue) -> Result<MachineValue, BusDeviceErrors> {
        for device in devices {
            if address >= device.startAddress, address <= device.endAddress {
                return device.read(from: address)
            }
        }
        return .failure(.OutOfAddressSpace)
    }

    func write(to address: MachineValue, data: MachineValue) -> Result<Void, BusDeviceErrors> {
        for device in devices {
            if address >= device.startAddress, address <= device.endAddress {
                return device.write(to: address, data: data)
            }
        }
        return .failure(.OutOfAddressSpace)
    }
}
