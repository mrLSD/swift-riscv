import Foundation

/// Execute instruction protocol
protocol ExecuteInstruction {
    func execute(state ms: inout MachineState)
}
