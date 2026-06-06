// Regression tests for the runSteps fetch/decode caches (Phase 2): every cache
// decision must produce behavior bit-identical to the uncached reference path —
// including self-modifying code, page-edge fetches, and cache invalidation.

import Testing
@testable import RISCV

struct UnitPhase2Tests {
    private func program(_ words: [UInt32], arch: Architecture = .RV32i) -> MachineState {
        var m = InitMachineState(.empty, arch, false).setRunState(.Run)
        for (i, w) in words.enumerated() {
            m = m.storeMemoryWord(0x8000_0000 + Int64(i * 4), Int64(Int32(bitPattern: w)))
        }
        return m
    }

    @Test("self-modifying code re-decodes through the word-verified cache")
    func selfModifyingCode() {
        // Pass 1 executes `addi x7,x0,1` at 0x08 (seeding the decode cache), then
        // overwrites 0x08 with `addi x7,x0,55` and loops. Pass 2 MUST execute the
        // new word (the cached executor is rejected by the word compare).
        let m = program([
            0x8000_00B7, // lui  x1,0x80000
            0x0013_0313, // addi x6,x6,1        (pass counter)
            0x0010_0393, // addi x7,x0,1        <- SMC target
            0x0200_A183, // lw   x3,0x20(x1)    (replacement word)
            0x0030_A423, // sw   x3,8(x1)       (overwrite 0x08)
            0x0020_0413, // addi x8,x0,2
            0xFE83_46E3, // blt  x6,x8,-20      (loop to 0x04)
            0x0010_0073, // ebreak
            0x0370_0393, // .word: addi x7,x0,55
        ])
        let r = Run.runSteps(50, m)
        #expect(r.getRegister(6) == 2)
        #expect(r.getRegister(7) == 55)
        #expect(r.RunState == .Trap(.EBreak))
    }

    @Test("compressed instruction in the last 2 bytes of a page fetches via the fallback")
    func pageEdgeCompressedFetch() {
        var m = InitMachineState(.empty, .RV32ic, false).setRunState(.Run)
        m = m.storeMemoryHalfWord(0x8000_0FFE, 0x9002) // c.ebreak at page offset 4094
        m = m.setPC(0x8000_0FFE)
        let r = Run.runSteps(5, m)
        #expect(r.RunState == .Trap(.EBreak))
    }

    @Test("fetch from a completely unmapped page traps")
    func unmappedPageFetch() {
        let m = InitMachineState(.empty, .RV64i, false).setRunState(.Run).setPC(0x9000_0000)
        let r = Run.runSteps(3, m)
        #expect(r.RunState == .Trap(.InstructionFetch(0x9000_0000)))
    }

    @Test("stores to a data page keep the code-page fetch cache valid")
    func storeLoopKeepsFetchCache() {
        // Each iteration stores to page 0x10 while fetching from page 0x80000 —
        // the single-step generation bump must NOT drop the fetch cache.
        let m = program([
            0x0001_01B7, // lui  x3,0x10
            0x0010_8093, // addi x1,x1,1
            0x0011_A023, // sw   x1,0(x3)
            0x0050_0113, // addi x2,x0,5
            0xFE20_CAE3, // blt  x1,x2,-12   (loop to 0x04)
            0x0010_0073, // ebreak
        ])
        let r = Run.runSteps(100, m)
        #expect(r.getRegister(1) == 5)
        #expect(loadWord(r.Memory, 0x10000) == 5)
        #expect(r.RunState == .Trap(.EBreak))
    }

    @Test("a cross-page store invalidates the fetch cache conservatively")
    func crossPageStoreInvalidates() {
        // sw to 0x10FFE bumps the generation twice (two pages touched); the
        // multi-bump rule drops the fetch cache and the next fetch refills it.
        let m = program([
            0x0001_11B7, // lui  x3,0x11
            0xFFE1_8193, // addi x3,x3,-2     (x3 = 0x10FFE)
            0x0070_0093, // addi x1,x0,7
            0x0011_A023, // sw   x1,0(x3)
            0x0010_0073, // ebreak
        ])
        let r = Run.runSteps(10, m)
        #expect(loadWord(r.Memory, 0x10FFE) == 7)
        #expect(r.RunState == .Trap(.EBreak))
    }

    @Test("fetchInstruction word path works directly (32-bit and compressed)")
    func fetchInstructionWordPath() {
        var m = InitMachineState(.empty, .RV32i, false)
        m = m.storeMemoryWord(0x8000_0000, 0x0050_0093) // addi x1,x0,5
        #expect(Run.fetchInstruction(m) == 0x0050_0093)
        var c = InitMachineState(.empty, .RV32ic, false)
        c = c.storeMemoryWord(0x8000_0000, 0x0000_9002) // low halfword = c.ebreak
        #expect(Run.fetchInstruction(c) == 0x9002)
    }

    @Test("a 32-bit instruction straddling a page boundary executes via the fallback")
    func pageStraddling32BitFetch() {
        var m = InitMachineState(.empty, .RV32i, false).setRunState(.Run)
        m = m.storeMemoryWord(0x8000_0FFE, 0x0090_0093) // addi x1,x0,9 across pages
        m = m.storeMemoryWord(0x8000_1002, 0x0010_0073) // ebreak (also straddling)
        m = m.setPC(0x8000_0FFE)
        let r = Run.runSteps(5, m)
        #expect(r.getRegister(1) == 9)
        #expect(r.RunState == .Trap(.EBreak))
    }

    @Test("a loop wider than the decode cache exercises slot-collision refills")
    func decodeCacheCollision() {
        // 130 sequential addi (520 bytes) wrap the 256-slot PC-indexed cache, so
        // the second iteration re-misses overwritten slots; results must be exact.
        var words: [UInt32] = [0x0020_0113] // addi x2,x0,2 (limit)
        words += [UInt32](repeating: 0x0010_8093, count: 130) // addi x1,x1,1
        words.append(0x0011_8193) // addi x3,x3,1 (iteration counter)
        words.append(0xDE21_C8E3) // blt x3,x2,-528 (loop to 0x04)
        words.append(0x0010_0073) // ebreak
        let m = program(words)
        let r = Run.runSteps(1000, m)
        #expect(r.getRegister(1) == 260) // 130 increments x 2 iterations
        #expect(r.getRegister(3) == 2)
        #expect(r.RunState == .Trap(.EBreak))
    }
}
