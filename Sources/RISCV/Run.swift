// Replica of riscv-fs `Run.fs` (module ISA.RISCV.Run)
//
// The reference loads ELF files through the ELFSharp library; the Swift replica
// carries its own minimal ELF32/ELF64 program-header parser (little-endian, PT_LOAD
// segments and e_entry only) with strict bounds checks on every untrusted field.

import Foundation

/// Failure while reading or parsing an ELF file (the reference surfaces these as
/// exceptions from ELFSharp / `failwithf`).
public struct ElfLoadError: Error, Equatable, CustomStringConvertible {
    public let message: String

    public init(_ message: String) {
        self.message = message
    }

    public var description: String { message }
}

public enum Run {
    /// Get registers state
    public static func verbosityMessageRegisters(_ mstate: borrowing MachineState) {
        print("Not zero Registers: ")
        for x in 0 ... 31 where mstate.Registers[x] != 0 {
            let value = "0x" + String(UInt64(bitPattern: mstate.Registers[x]), radix: 16)
            print("\t" + padRight("x\(x)", 4) + value)
        }
    }

    /// Read Elf data content to memory with format: [address, dataByte], paired with the
    /// ELF entry point (e_entry) so the PC starts where the program is actually linked.
    /// Loads every PT_LOAD segment (code, data, zero-filled bss) for 32- and 64-bit ELF.
    public static func readElfFile(_ file: String) throws -> (MemoryMap, Int64) {
        // The memory map tracks one mapped flag per byte, so an untrusted ELF's
        // attacker-controlled p_memsz must be bounded BEFORE allocation. Sum each
        // segment's memsz saturated at the cap, in UInt64 so a huge or wrapping
        // p_memsz cannot evade the check, and reject the file if the total exceeds
        // the limit.
        let maxMappedBytes: UInt64 = 4 * 1024 * 1024
        // The file itself is equally untrusted: bound the read BEFORE materializing
        // anything (a multi-GB path must not be loaded into RAM just to be rejected),
        // and reject non-regular files (FIFO/device) whose read could block or grow
        // without bound.
        let maxFileBytes: UInt64 = 16 * 1024 * 1024
        let attrs = try FileManager.default.attributesOfItem(atPath: file)
        guard attrs[.type] as? FileAttributeType == .typeRegular else {
            throw ElfLoadError("'\(file)' is not a regular file")
        }
        guard let fileSize = (attrs[.size] as? NSNumber)?.uint64Value, fileSize <= maxFileBytes else {
            throw ElfLoadError("ELF file exceeds the \(maxFileBytes)-byte size limit")
        }
        let bytes = try [UInt8](Data(contentsOf: URL(fileURLWithPath: file)))

        // --- bounds-checked little-endian field readers over the untrusted file ---
        func readLE(_ offset: UInt64, _ n: Int) throws -> UInt64 {
            guard let start = Int(exactly: offset), start <= bytes.count - n, bytes.count >= n else {
                throw ElfLoadError("ELF file is truncated: cannot read \(n) bytes at offset \(offset)")
            }
            return bytes.withUnsafeBufferPointer { buf in
                let span = buf.span
                var acc: UInt64 = 0
                for i in 0 ..< n {
                    acc |= UInt64(span[start + i]) << (i << 3)
                }
                return acc
            }
        }

        guard bytes.count >= 6, bytes[0] == 0x7F, bytes[1] == 0x45, bytes[2] == 0x4C, bytes[3] == 0x46 else {
            throw ElfLoadError("Not an ELF file")
        }

        // e_ident[EI_DATA]: this hand-written loader reads every multi-byte field
        // little-endian (1 => LE). A big-endian ELF (2) would silently misparse, so
        // reject it explicitly rather than load garbage. The reference defers this to
        // ELFSharp, which we do not carry — consistent with the loader being LE-only.
        guard bytes[5] == 0x01 else {
            throw ElfLoadError("Unsupported ELF endianness (only little-endian is supported)")
        }

        // e_ident[EI_CLASS]: 2 => 64-bit, anything else is handled as 32-bit
        // (mirrors the reference `CheckELFType` match).
        let is64 = bytes[4] == 2

        let entry: Int64
        let phoff: UInt64
        let phentsize: UInt64
        let phnum: UInt64
        // Program-header field offsets (little-endian System V layout).
        let pOffset: UInt64, pVaddr: UInt64, pFilesz: UInt64, pMemsz: UInt64
        let fieldSize: Int
        if is64 {
            entry = Int64(bitPattern: try readLE(0x18, 8))
            phoff = try readLE(0x20, 8)
            phentsize = try readLE(0x36, 2)
            phnum = try readLE(0x38, 2)
            (pOffset, pVaddr, pFilesz, pMemsz) = (0x08, 0x10, 0x20, 0x28)
            fieldSize = 8
        } else {
            entry = Int64(try readLE(0x18, 4))
            phoff = try readLE(0x1C, 4)
            phentsize = try readLE(0x2A, 2)
            phnum = try readLE(0x2C, 2)
            (pOffset, pVaddr, pFilesz, pMemsz) = (0x04, 0x08, 0x10, 0x14)
            fieldSize = 4
        }

        // Pass 1: collect PT_LOAD program headers and bound the total mapped size
        // before materializing anything.
        var segments: [(offset: UInt64, vaddr: UInt64, filesz: UInt64, memsz: UInt64)] = []
        var total: UInt64 = 0
        for i in 0 ..< phnum {
            let ph = phoff &+ i &* phentsize
            let type = try readLE(ph, 4)
            guard type == 1 /* PT_LOAD */ else { continue }
            let segment = (
                offset: try readLE(ph &+ pOffset, fieldSize),
                vaddr: try readLE(ph &+ pVaddr, fieldSize),
                filesz: try readLE(ph &+ pFilesz, fieldSize),
                memsz: try readLE(ph &+ pMemsz, fieldSize)
            )
            total &+= min(segment.memsz, maxMappedBytes + 1)
            segments.append(segment)
        }
        if total > maxMappedBytes {
            throw ElfLoadError("ELF load segments exceed the \(maxMappedBytes)-byte memory limit")
        }

        // Pass 2: materialize each segment — filesz bytes from the file, zero-filled
        // up to memsz (.bss) — into sparse memory at its virtual address.
        var mem = MemoryMap.empty
        for segment in segments {
            guard segment.filesz <= segment.memsz else {
                throw ElfLoadError("ELF segment file size exceeds its memory size")
            }
            guard let start = Int(exactly: segment.offset),
                  let filesz = Int(exactly: segment.filesz),
                  start <= bytes.count - filesz, bytes.count >= filesz
            else {
                throw ElfLoadError("ELF segment data lies outside the file")
            }
            var contents = [UInt8](bytes[start ..< start + filesz])
            contents.append(contentsOf: repeatElement(0, count: Int(segment.memsz) - filesz))
            mem.storeRange(Int64(bitPattern: segment.vaddr), contents)
        }
        return (mem, entry)
    }

    /// Get instruction from current Machine State that related to
    /// current PC as memory address for loading instruction data for Decoding.
    /// 32-bit instruction iff inst[1:0] = 0b11, otherwise 16-bit compressed.
    ///
    /// The reference reads a half-word first and widens; since every 32-bit fetch
    /// then pays a second memory access, the replica tries the full word ONCE and
    /// only falls back to the half-word path when the word read fails (a 16-bit
    /// instruction in the last two mapped bytes). Observable behavior is identical
    /// for every (memory, PC) pair.
    public static func fetchInstruction(_ mstate: borrowing MachineState) -> InstrField? {
        if let w = loadWord(mstate.Memory, mstate.PC) {
            return w & 0x3 == 0x3 ? w : Int32(UInt16(truncatingIfNeeded: w))
        }
        guard let hw = loadHalfWord(mstate.Memory, mstate.PC) else { return nil }
        // The full word was unreadable: only a compressed instruction can be valid here.
        if Int32(hw) & 0x3 == 0x3 {
            return nil
        } else {
            return Int32(UInt16(bitPattern: hw))
        }
    }

    /// Basic RISC-V run life cycle (FSM). `steps` bounds execution so a non-terminating
    /// program (e.g. a backward self-branch) aborts with a StepLimit trap instead of hanging.
    /// (The reference recurses; Swift iterates — same FSM, explicit tail loop.)
    ///
    /// The loop carries two LOCAL caches (they never enter MachineState, so the
    /// functional value semantics are untouched):
    /// - a fetch cache of the current code page's storage, validated against
    ///   `MemoryMap.generation` so any store that could touch the cached page
    ///   (or any multi-bump store) drops it — self-modifying code stays bit-exact;
    /// - a direct-mapped, PC-indexed decode cache whose hits are verified against
    ///   the freshly fetched WORD, so a hit can never execute stale code.
    /// Every fetched word and every executed transition is identical to the
    /// uncached `fetchInstruction` + `Decoder.Decode` path.
    public static func runSteps(_ steps: Int, _ mstate: consuming MachineState) -> MachineState {
        var steps = steps
        var mstate = mstate

        // ---- fetch cache (current code page) ----
        var fetchKey = Int64.min // cached page key (.min = empty)
        var fetchGen = -1 // memory generation the cache was validated at
        var fetchBytes: [UInt8] = []
        var fetchMapped: [UInt64] = []

        // ---- decode cache (direct-mapped, word-verified) ----
        // The dummy filler is never executed: a hit requires tag == PC AND a word
        // match, and entries are only written together after a successful decode.
        let cacheSize = 256
        var cacheTags = [Int64](repeating: .min, count: cacheSize)
        var cacheWords = [Int32](repeating: 0, count: cacheSize)
        var cacheExecs = [execFunc](
            repeating: execFunc(instr: .I(.ADDI(rd: 0, rs1: 0, imm12: 0)), len: 4),
            count: cacheSize
        )

        while steps > 0 {
            let pc = mstate.PC

            // Revalidate the fetch cache against memory mutations. At most one
            // store happens per instruction, so a single-step generation bump
            // that touched ANOTHER page keeps the cache; anything else (a write
            // to our page, or a multi-bump cross-page/wrapping store) drops it.
            let gen = mstate.Memory.generation
            if gen != fetchGen {
                if gen != fetchGen &+ 1 || mstate.Memory.lastMutatedKey == fetchKey {
                    fetchKey = .min
                }
                fetchGen = gen
            }

            let pageKey = pc >> MemoryMap.pageShift
            if pageKey != fetchKey {
                if let (bytes, mapped) = mstate.Memory.pageArrays(pageKey) {
                    fetchKey = pageKey
                    fetchBytes = bytes
                    fetchMapped = mapped
                } else {
                    fetchKey = .min
                }
            }

            // Fast fetch: a whole word inside the cached page (same word-first
            // widening as fetchInstruction; little-endian host). Page-crossing,
            // partially mapped, and unmapped fetches take the reference path.
            let offset = Int(pc & Int64(MemoryMap.pageSize - 1))
            let instr: InstrField?
            if fetchKey == pageKey, offset <= MemoryMap.pageSize - 4,
               MemoryMap.isMappedRun(fetchMapped, offset, 4) {
                let w = fetchBytes.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: offset, as: UInt32.self) }
                let wi = Int32(bitPattern: w)
                instr = wi & 0x3 == 0x3 ? wi : Int32(UInt16(truncatingIfNeeded: w))
            } else {
                instr = fetchInstruction(mstate)
            }

            switch instr {
            case .none:
                mstate = mstate.setRunState(.Trap(.InstructionFetch(mstate.PC)))
            case let .some(instrValue):
                if mstate.Verbosity {
                    print(String(format: "%08llx: %08x", mstate.PC, instrValue))
                }
                let slot = Int((pc >> 1) & Int64(cacheSize - 1))
                if cacheTags[slot] == pc, cacheWords[slot] == instrValue {
                    mstate = cacheExecs[slot](mstate)
                } else {
                    switch Decoder.Decode(mstate, instrValue) {
                    case .none:
                        mstate = mstate.setRunState(.Trap(.InstructionDecode))
                    case let .some(executor):
                        cacheTags[slot] = pc
                        cacheWords[slot] = instrValue
                        cacheExecs[slot] = executor
                        mstate = executor(mstate)
                    }
                }
            }
            switch mstate.RunState {
            case .Trap, .Stopped:
                if mstate.Verbosity {
                    verbosityMessageRegisters(mstate)
                }
                return mstate
            default:
                steps -= 1
            }
        }
        return mstate.setRunState(.Trap(.StepLimit))
    }

    /// 10M-instruction cap guards against a non-terminating program.
    public static func runCycle(_ mstate: consuming MachineState) -> MachineState {
        runSteps(10_000_000, mstate)
    }

    /// Main application Run logic
    public static func Run(_ cfg: AppConfig) throws -> MachineState {
        let (data, entry) = try readElfFile(cfg.Files![0])
        // Start the PC at the ELF entry point (e_entry) instead of a fixed constant, so a
        // program linked anywhere (not only 0x80000000) fetches its first instruction.
        let mstate = InitMachineState(data, cfg.Arch!, cfg.Verbosity!).setPC(entry)
        return runCycle(mstate)
    }
}
