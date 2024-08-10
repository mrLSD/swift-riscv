import Foundation

/// Register field type
typealias Register = UInt32
/// Instruction field type
typealias InstrField = UInt32

/// Decode Instruction protocol
protocol DecodeInstruction {
    static func decode(instr: MachineValue) -> ExecuteInstruction?
}

enum Decoder: DecodeInstruction {
    static func decode(instr: MachineValue) -> ExecuteInstruction? {
        if let decoded = InstructionI.decode(instr: instr) {
            return decoded
        }
        return nil
    }
}
