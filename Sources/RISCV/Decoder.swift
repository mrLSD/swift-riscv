/// Decode instructions set
// Replica of riscv-fs `Decoder.fs` (module ISA.RISCV.Decoder)

// Execution Function type is currying with partly applied
// concrete function for specific instruction set.
// The F# reference models this as `execFunc = MachineState -> MachineState`;
// the Swift replica packages the partly-applied execute in a callable value
// type so the hot loop pays no closure heap allocation per decoded instruction.
public struct execFunc {
    @usableFromInline
    enum DecodedInstruction {
        case I(InstructionI)
        case M(InstructionM)
        case M64(InstructionM64)
        case A(InstructionA)
        case A64(InstructionA64)
        case C(InstructionC)
    }

    @usableFromInline let instr: DecodedInstruction
    @usableFromInline let len: Int

    @inlinable
    public func callAsFunction(_ mstate: consuming MachineState) -> MachineState {
        var mstate = mstate
        mstate.InstrLen = len
        switch instr {
        case let .I(decoded):
            return ExecuteI.Execute(decoded, mstate)
        case let .M(decoded):
            return ExecuteM.Execute(decoded, mstate)
        case let .M64(decoded):
            return ExecuteM64.Execute(decoded, mstate)
        case let .A(decoded):
            return ExecuteA.Execute(decoded, mstate)
        case let .A64(decoded):
            return ExecuteA64.Execute(decoded, mstate)
        case let .C(decoded):
            return ExecuteC.Execute(decoded, mstate)
        }
    }
}

public enum Decoder {
    /// Aggregate decoded data.
    ///
    /// Each extension is gated by architecture support; base I is always present.
    /// (Compressed and 32-bit encodings are disjoint by inst[1:0], so only one decodes.)
    /// The reference decodes every extension eagerly and then picks the first match;
    /// the decoders are pure, so the replica short-circuits in the same priority
    /// order (I, M, M64, A, A64, C) — observable behavior is identical, and the
    /// common base-I hot path never pays for the extension decoders.
    /// (Compressed and 32-bit encodings are disjoint by inst[1:0], so only one decodes.)
    public static func Decode(_ mstate: borrowing MachineState, _ instr: InstrField) -> execFunc? {
        // Instruction length is intrinsic to the encoding (inst[1:0]=11 => 32-bit, else
        // 16-bit compressed). Bake it into the returned executor so PC/link advance
        // correctly for any caller, without relying on InstrLen being set externally.
        let len = (instr & 0x3) == 0x3 ? 4 : 2

        let decI32 = DecodeI.Decode(mstate, instr)
        if decI32 != InstructionI.None {
            return execFunc(instr: .I(decI32), len: len)
        }

        let rv64 = mstate.Arch.archBits == .RV64

        // Extension decoders run only when the architecture has the extension:
        // the reference decodes eagerly and discards via the gate; the decoders
        // are pure, so skipping the discarded decode is observationally identical
        // (and the base-I miss path stops paying for absent extensions).
        if mstate.Arch.hasM {
            let decM = DecodeM.Decode(mstate, instr)
            if decM != InstructionM.None {
                return execFunc(instr: .M(decM), len: len)
            }
            if rv64 {
                let decM64 = DecodeM64.Decode(mstate, instr)
                if decM64 != InstructionM64.None {
                    return execFunc(instr: .M64(decM64), len: len)
                }
            }
        }

        if mstate.Arch.hasA {
            let decA = DecodeA.Decode(instr)
            if decA != InstructionA.None {
                return execFunc(instr: .A(decA), len: len)
            }
            if rv64 {
                let decA64 = DecodeA64.Decode(instr)
                if decA64 != InstructionA64.None {
                    return execFunc(instr: .A64(decA64), len: len)
                }
            }
        }

        if mstate.Arch.hasC {
            let decC = DecodeC.Decode(mstate, instr)
            if decC != InstructionC.None {
                return execFunc(instr: .C(decC), len: len)
            }
        }

        return nil
    }
}
