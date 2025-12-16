---
name: darwin-godwin-machine
description: |
  Hybrid cognitive architecture combining Darwinian evolution with Gödel Machine self-improvement for maximum reasoning power. Use for: complex coding problems, multi-step reasoning, architecture design, debugging hard problems, any task requiring exhaustive solution exploration with formal verification. Activates when user needs "powerful reasoning", "best possible solution", "explore all options", or faces problems where first-attempt solutions typically fail.
---

# Darwin-Gödel Machine

A cognitive architecture that evolves populations of solutions while formally verifying improvements before self-modification.

## Core Philosophy

**Darwin**: Generate diverse solution populations → Apply selection pressure → Evolve toward optimum
**Gödel**: Verify improvements formally before accepting → Enable recursive self-improvement → Prove modifications beneficial

**Combined**: Explore solution space evolutionarily, but only commit changes with verification proofs.

---

## REASONING FRAMEWORK SELECTION

Before entering the execution loop, select the appropriate reasoning topology based on problem characteristics. This is the **FIRST** decision point.

### The Three Frameworks

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  CHAIN OF THOUGHT (CoT) — Linear Sequential Reasoning                       │
│  ─────────────────────────────────────────────────────────────────────────  │
│  Topology:  [Step 1] → [Step 2] → [Step 3] → ... → [Answer]                │
│                                                                             │
│  STRENGTHS:                                                                 │
│    • Simple to implement and follow                                         │
│    • Effective for sequential reasoning tasks                               │
│    • Low computational overhead                                             │
│    • Clear audit trail of reasoning                                         │
│                                                                             │
│  LIMITATIONS:                                                               │
│    • Linear only—no backtracking capability                                 │
│    • Cannot explore multiple paths simultaneously                           │
│    • Less effective for problems requiring exploration                      │
│    • Single point of failure (one bad step derails everything)              │
│                                                                             │
│  BEST FOR:                                                                  │
│    ✓ Arithmetic and mathematical calculations                               │
│    ✓ Commonsense reasoning chains                                           │
│    ✓ Tasks with clear sequential steps                                      │
│    ✓ Simple decomposition problems                                          │
│    ✓ When the solution path is relatively obvious                           │
│                                                                             │
│  ACTIVATION TRIGGERS:                                                       │
│    • "Walk me through..."                                                   │
│    • "Step by step..."                                                      │
│    • Simple math, logic puzzles with single solution path                   │
│    • Clearly sequential procedures                                          │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│  TREE OF THOUGHTS (ToT) — Hierarchical Branching Exploration                │
│  ─────────────────────────────────────────────────────────────────────────  │
│  Topology:                                                                  │
│                        [Root Problem]                                       │
│                       /      |       \                                      │
│                  [Path A] [Path B] [Path C]                                 │
│                  /    \      |      /    \                                  │
│              [A.1] [A.2]  [B.1]  [C.1] [C.2]                                │
│                      ↓                   ↓                                  │
│                  [Winner]           [Pruned]                                │
│                                                                             │
│  STRENGTHS:                                                                 │
│    • Enables exploration AND backtracking                                   │
│    • Systematically evaluates multiple reasoning paths                      │
│    • Can prune unpromising branches early                                   │
│    • Supports lookahead evaluation                                          │
│    • Natural fit for search problems                                        │
│                                                                             │
│  LIMITATIONS:                                                               │
│    • Increased resource consumption                                         │
│    • Inefficient for simpler tasks (overkill)                               │
│    • Limited by hierarchical structure                                      │
│    • Cannot easily combine insights across distant branches                 │
│                                                                             │
│  BEST FOR:                                                                  │
│    ✓ Problems with multiple possible approaches                             │
│    ✓ Creative tasks requiring exploration                                   │
│    ✓ Puzzles requiring lookahead (game trees)                               │
│    ✓ Planning problems with branching decisions                             │
│    ✓ When you need to try several approaches before committing              │
│                                                                             │
│  ACTIVATION TRIGGERS:                                                       │
│    • "What are the options..."                                              │
│    • "Explore different approaches..."                                      │
│    • Complex puzzles (Sudoku, planning, games)                              │
│    • Design decisions with trade-offs                                       │
│    • "Best solution" requests where path isn't obvious                      │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│  GRAPH OF THOUGHTS (GoT) — Non-Hierarchical Network Reasoning               │
│  ─────────────────────────────────────────────────────────────────────────  │
│  Topology:                                                                  │
│                                                                             │
│              [Thought A] ←──────→ [Thought D]                               │
│                  ↑ ↓                   ↑                                    │
│              [Thought B] ───→ [Thought E] ←── [Thought F]                   │
│                  ↓           ↗        ↓                                     │
│              [Thought C] ←───    [Synthesis]                                │
│                                                                             │
│  STRENGTHS:                                                                 │
│    • Maximum flexibility in thought connections                             │
│    • Enables complex thought transformations:                               │
│      - Aggregation (combine multiple thoughts into one)                     │
│      - Refinement (improve a thought iteratively)                           │
│      - Merging (synthesize insights from different branches)                │
│    • Closest approximation to human cognitive processes                     │
│    • Can revisit and connect any thoughts regardless of when formed         │
│    • Supports cycles and bidirectional reasoning                            │
│                                                                             │
│  LIMITATIONS:                                                               │
│    • More complex to implement and manage                                   │
│    • Potentially higher computational overhead                              │
│    • Requires careful thought about which connections matter                │
│    • Can become unwieldy without structure                                  │
│                                                                             │
│  BEST FOR:                                                                  │
│    ✓ Tasks requiring synthesis of multiple approaches                       │
│    ✓ Problems decomposable into interconnected subtasks                     │
│    ✓ Situations where insights from one area inform another                 │
│    ✓ Complex system design with many interacting components                 │
│    ✓ Research synthesis and multi-source integration                        │
│    ✓ When you need to "connect the dots" across different analyses          │
│                                                                             │
│  ACTIVATION TRIGGERS:                                                       │
│    • "How do these relate..."                                               │
│    • "Synthesize these approaches..."                                       │
│    • Complex architecture design                                            │
│    • Multi-factor analysis problems                                         │
│    • When simple tree structure feels limiting                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Framework Selection Decision Matrix

| Problem Characteristic | CoT | ToT | GoT |
|------------------------|-----|-----|-----|
| Single clear solution path | ✓✓✓ | ✗ | ✗ |
| Multiple possible approaches | ✗ | ✓✓✓ | ✓✓ |
| Requires backtracking | ✗ | ✓✓✓ | ✓✓ |
| Interconnected subtasks | ✗ | ✓ | ✓✓✓ |
| Need to synthesize insights | ✗ | ✓ | ✓✓✓ |
| Computational constraints | ✓✓✓ | ✓ | ✗ |
| Simple/fast execution needed | ✓✓✓ | ✗ | ✗ |
| Creative exploration | ✗ | ✓✓✓ | ✓✓ |
| Complex system design | ✗ | ✓✓ | ✓✓✓ |

**Key**: ✓✓✓ = Optimal, ✓✓ = Good, ✓ = Acceptable, ✗ = Poor fit

### Framework Selection Algorithm

```
SELECT_FRAMEWORK(problem):
    
    # Step 1: Assess problem structure
    paths = estimate_solution_paths(problem)
    dependencies = map_subtask_dependencies(problem)
    
    # Step 2: Apply selection rules
    IF paths == 1 AND dependencies.is_linear():
        RETURN CoT
        
    IF paths > 1 AND dependencies.is_hierarchical():
        RETURN ToT
        
    IF dependencies.has_cycles() OR need_synthesis():
        RETURN GoT
    
    # Step 3: Default escalation
    IF uncertain:
        START with CoT
        ESCALATE to ToT if stuck
        ESCALATE to GoT if branches need merging
```

### Framework Transitions During Execution

Frameworks can ESCALATE but should not DOWNGRADE mid-problem:

```
CoT ──stuck──→ ToT ──need-synthesis──→ GoT
 │                │                      │
 └──success──→ DELIVER                   │
               │                         │
               └──success──→ DELIVER     │
                                         │
                            └──success──→ DELIVER
```

**ESCALATION TRIGGERS:**
- **CoT → ToT**: Linear approach hits dead end, multiple promising alternatives visible
- **ToT → GoT**: Tree branches need to share insights, problem reveals interconnected structure

---

## FRAMEWORK INTEGRATION WITH DARWIN-GÖDEL LOOP

The selected reasoning framework influences HOW each phase operates:

### Phase-Framework Mapping

| Phase | CoT Behavior | ToT Behavior | GoT Behavior |
|-------|-------------|--------------|--------------|
| DECOMPOSE | Linear sub-problem chain | Hierarchical decomposition tree | Dependency graph with cycles |
| GENESIS | Single solution thread | Multiple parallel solution branches | Solution network with cross-connections |
| EVALUATE | Sequential fitness check | Branch-wise evaluation + pruning | Network-wide fitness propagation |
| EVOLVE | Linear mutation chain | Branch mutations + selective pruning | Graph-wide mutation + edge refinement |
| VERIFY | Step-by-step proof | Branch validity proofs | Network coherence verification |
| CONVERGE | Single path to answer | Best branch selection | Synthesis of best graph paths |

### Sequential Thinking Tool + Framework Integration

The Sequential Thinking tool maps to each framework differently:

| Framework | ST Configuration | Key ST Features Used |
|-----------|------------------|----------------------|
| **CoT** | Linear thoughts, no revisions, no branches | `thoughtNumber`, `nextThoughtNeeded` |
| **ToT** | Enable branching, allow revisions | `branchFromThought`, `branchId`, `isRevision` |
| **GoT** | Full revision + branching + high totalThoughts | All parameters, `needsMoreThoughts` for synthesis |

---

## THE EXECUTION LOOP

Every problem runs this loop. No exceptions. Depth scales with complexity.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  PHASE 0: FRAMEWORK SELECTION (NEW - MANDATORY FIRST STEP)                  │
│  ├─ Analyze problem structure (paths, dependencies, interconnections)       │
│  ├─ Apply selection matrix to determine CoT vs ToT vs GoT                   │
│  ├─ Document selected framework with justification                          │
│  └─ Configure subsequent phases based on framework choice                   │
├─────────────────────────────────────────────────────────────────────────────┤
│  PHASE 1: DECOMPOSE                                                         │
│  ├─ Parse the problem into atomic sub-problems                              │
│  ├─ Identify constraints, success criteria, edge cases                      │
│  ├─ Define fitness function: What makes a solution "better"?                │
│  └─ Estimate complexity class → determines population size & generations    │
├─────────────────────────────────────────────────────────────────────────────┤
│  PHASE 2: GENESIS (Population Initialization)                               │
│  ├─ Generate N diverse initial solutions (N = 3-7 based on complexity)      │
│  ├─ Ensure diversity: different algorithms, paradigms, trade-offs           │
│  ├─ Each solution must be complete and executable (no stubs)                │
│  └─ Tag each with: approach_type, expected_strengths, expected_weaknesses   │
├─────────────────────────────────────────────────────────────────────────────┤
│  PHASE 3: EVALUATE (Fitness Assessment)                                     │
│  ├─ Score each solution against fitness function (1-100)                    │
│  ├─ Test against edge cases and adversarial inputs                          │
│  ├─ Measure: correctness, efficiency, readability, robustness               │
│  └─ Rank population by composite fitness score                              │
├─────────────────────────────────────────────────────────────────────────────┤
│  PHASE 4: EVOLVE (Selection + Mutation + Crossover)                         │
│  ├─ SELECT: Keep top 50% of population                                      │
│  ├─ MUTATE: Apply mutation operators to survivors (see §Mutations)          │
│  ├─ CROSSOVER: Combine strengths of top 2 solutions into hybrid             │
│  └─ Generate new candidates to restore population size                      │
├─────────────────────────────────────────────────────────────────────────────┤
│  PHASE 5: VERIFY (Gödel Proof Gate)                                         │
│  ├─ For each evolved solution, PROVE improvement over parent                │
│  ├─ Proof types: logical deduction, test coverage, complexity analysis      │
│  ├─ REJECT any mutation that cannot be formally justified                   │
│  └─ Only verified improvements pass to next generation                      │
├─────────────────────────────────────────────────────────────────────────────┤
│  PHASE 6: CONVERGE (Termination Check)                                      │
│  ├─ If best solution meets success criteria → DELIVER                       │
│  ├─ If fitness plateau (no improvement in 2 generations) → DELIVER best     │
│  ├─ If generation limit reached → DELIVER best with caveats                 │
│  └─ Else → Return to PHASE 4 with evolved population                        │
├─────────────────────────────────────────────────────────────────────────────┤
│  PHASE 7: REFLECT (Mandatory Self-Reflection)                               │
│  ├─ SOLUTION REFLECTION: Why did winner win? What trait was decisive?       │
│  ├─ PROCESS REFLECTION: Did I explore right space? What did I miss?         │
│  ├─ ASSUMPTION AUDIT: List all assumptions, mark validated/invalidated      │
│  ├─ MUTATION ANALYSIS: Which mutations helped? Which wasted cycles?         │
│  ├─ PROOF QUALITY: Were proofs rigorous or hand-wavy?                       │
│  ├─ FAILURE ANALYSIS: What would have caught mistakes earlier?              │
│  ├─ FRAMEWORK REFLECTION: Was the chosen framework (CoT/ToT/GoT) optimal?   │
│  └─ Score reasoning quality 1-10, justify score                             │
├─────────────────────────────────────────────────────────────────────────────┤
│  PHASE 8: META-IMPROVE (Recursive Self-Improvement)                         │
│  ├─ Extract: What lessons apply to future problems?                         │
│  ├─ Propose: Concrete process improvements (not vague)                      │
│  ├─ Verify: Would proposed improvement actually help? (use ST if complex)   │
│  ├─ If verified → Add to ACTIVE_LESSONS for this conversation               │
│  └─ Apply ACTIVE_LESSONS at start of next problem in conversation           │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## TOOL ORCHESTRATION: SEQUENTIAL THINKING

The Sequential Thinking tool is **mandatory** for specific phases. Invoke it explicitly.

### When to Invoke Sequential Thinking

| Phase | Trigger Condition | How to Use |
|-------|-------------------|------------|
| FRAMEWORK SELECT | Problem structure unclear | Analyze paths and dependencies step-by-step |
| DECOMPOSE | Problem has 3+ interacting components | Map dependency graph, identify atomic sub-problems |
| DECOMPOSE | Constraints are implicit/hidden | Surface assumptions step-by-step |
| VERIFY | Building formal proof | Construct proof with backtracking capability |
| VERIFY | Proof attempt fails | Revise earlier steps, explore alternative proof paths |
| CONVERGE | Plateau detected (no improvement 2+ gens) | Diagnose why evolution stalled, reframe problem |
| REFLECT | Complex failure analysis needed | Trace causal chain from mistake to root cause |
| REFLECT | Extracting non-obvious lessons | Step through what happened to find patterns |
| META-IMPROVE | Process inefficiency detected | Trace reasoning chain to find improvement point |

### Sequential Thinking by Framework

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  CoT MODE: Sequential Thinking as Linear Chain                              │
│  ─────────────────────────────────────────────────────────────────────────  │
│  Configuration:                                                             │
│    • isRevision: false (no backtracking)                                    │
│    • branchFromThought: null (no branching)                                 │
│    • needsMoreThoughts: estimate upfront, then execute linearly             │
│    • totalThoughts: low (5-15 typical)                                      │
│                                                                             │
│  Use Pattern:                                                               │
│    1. Estimate total steps needed                                           │
│    2. Execute each thought sequentially                                     │
│    3. Each thought builds directly on previous                              │
│    4. No revision - commit to each step                                     │
│                                                                             │
│  Example:                                                                   │
│    Thought 1: Parse problem requirements                                    │
│    Thought 2: Identify constraints                                          │
│    Thought 3: Design solution approach                                      │
│    Thought 4: Implement solution                                            │
│    Thought 5: Verify correctness                                            │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│  ToT MODE: Sequential Thinking as Branching Tree                            │
│  ─────────────────────────────────────────────────────────────────────────  │
│  Configuration:                                                             │
│    • isRevision: true (enable backtracking)                                 │
│    • branchFromThought: specify when branching                              │
│    • branchId: label branches (A, B, C, etc.)                               │
│    • needsMoreThoughts: true (iterative expansion)                          │
│    • totalThoughts: medium (15-40 typical)                                  │
│                                                                             │
│  Use Pattern:                                                               │
│    1. Start with root thought                                               │
│    2. Generate multiple branches at decision points                         │
│    3. Evaluate each branch                                                  │
│    4. Prune poor branches, expand promising ones                            │
│    5. Revise earlier thoughts if branch fails                               │
│                                                                             │
│  Example:                                                                   │
│    Thought 1: Parse problem                                                 │
│    Thought 2: [Branch A] Try approach 1                                     │
│    Thought 3: [Branch B] Try approach 2                                     │
│    Thought 4: [Branch C] Try approach 3                                     │
│    Thought 5: [Branch A.1] Evaluate approach 1 - looks promising            │
│    Thought 6: [Branch B.1] Evaluate approach 2 - dead end, prune            │
│    Thought 7: [Branch C.1] Evaluate approach 3 - partial success            │
│    Thought 8: [Branch A.2] Implement winning approach                       │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│  GoT MODE: Sequential Thinking as Interconnected Graph                      │
│  ─────────────────────────────────────────────────────────────────────────  │
│  Configuration:                                                             │
│    • isRevision: true (full revision capability)                            │
│    • branchFromThought: any thought can branch                              │
│    • branchId: use semantic labels                                          │
│    • needsMoreThoughts: true (highly iterative)                             │
│    • totalThoughts: high (40-100+ for complex problems)                     │
│                                                                             │
│  Use Pattern:                                                               │
│    1. Generate thoughts across multiple dimensions                          │
│    2. Create connections between non-adjacent thoughts                      │
│    3. Synthesize insights from multiple branches                            │
│    4. Refine thoughts based on discoveries elsewhere in graph               │
│    5. Aggregate partial solutions into coherent whole                       │
│                                                                             │
│  Example:                                                                   │
│    Thought 1: [Core] Parse problem                                          │
│    Thought 2: [Constraint] Identify performance requirements                │
│    Thought 3: [Architecture] Consider microservices approach                │
│    Thought 4: [Security] Analyze authentication needs                       │
│    Thought 5: [Synthesis] Auth approach impacts architecture choice         │
│    Thought 6: [Revision:3] Update architecture based on auth constraints    │
│    Thought 7: [Data] Design schema considering both arch and auth           │
│    Thought 8: [Integration] Connect architecture + auth + data layers       │
│    ...continue until coherent system emerges                                │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## MUTATION OPERATORS

Mutations are transformations applied to solutions during evolution. Apply 1-3 mutations per generation.

### Code Mutation Operators

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  ALGORITHM SUBSTITUTION                                                     │
│  ─────────────────────────────────────────────────────────────────────────  │
│  Replace core algorithm with equivalent but different approach              │
│                                                                             │
│  Examples:                                                                  │
│    • Bubble sort → Quick sort → Merge sort                                  │
│    • Iterative → Recursive → Tail-recursive                                 │
│    • Imperative → Functional → Declarative                                  │
│    • Synchronous → Asynchronous → Event-driven                              │
│                                                                             │
│  When to apply:                                                             │
│    • Performance plateau detected                                           │
│    • Correctness issues in edge cases                                       │
│    • Exploring different complexity classes                                 │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│  DATA STRUCTURE SWAP                                                        │
│  ─────────────────────────────────────────────────────────────────────────  │
│  Replace underlying data structures with alternatives                       │
│                                                                             │
│  Examples:                                                                  │
│    • Array → Hash map → Tree → Graph                                        │
│    • List → Set → Ordered set                                               │
│    • Stack → Queue → Priority queue                                         │
│    • Mutable → Immutable structures                                         │
│                                                                             │
│  When to apply:                                                             │
│    • Time complexity issues (lookup, insert, delete)                        │
│    • Space complexity concerns                                              │
│    • Cache locality problems                                                │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│  OPTIMIZATION INJECTION                                                     │
│  ─────────────────────────────────────────────────────────────────────────  │
│  Add performance optimizations to existing solution                         │
│                                                                             │
│  Examples:                                                                  │
│    • Add memoization/caching                                                │
│    • Introduce lazy evaluation                                              │
│    • Apply early termination conditions                                     │
│    • Add branch prediction hints                                            │
│    • Implement parallel processing                                          │
│                                                                             │
│  When to apply:                                                             │
│    • Solution correct but too slow                                          │
│    • Redundant computation detected                                         │
│    • CPU/memory profiling shows bottlenecks                                 │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│  ERROR HANDLING ENHANCEMENT                                                 │
│  ─────────────────────────────────────────────────────────────────────────  │
│  Improve robustness and edge case handling                                  │
│                                                                             │
│  Examples:                                                                  │
│    • Add null/undefined checks                                              │
│    • Implement retry logic with backoff                                     │
│    • Add input validation                                                   │
│    • Improve error messages                                                 │
│    • Add graceful degradation                                               │
│                                                                             │
│  When to apply:                                                             │
│    • Edge case failures detected                                            │
│    • Fitness score penalized for fragility                                  │
│    • Production-readiness requirements                                      │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│  ABSTRACTION LEVEL SHIFT                                                    │
│  ─────────────────────────────────────────────────────────────────────────  │
│  Move up/down abstraction ladder                                            │
│                                                                             │
│  Examples:                                                                  │
│    • Extract helper functions (decompose)                                   │
│    • Inline functions (simplify)                                            │
│    • Introduce design patterns                                              │
│    • Remove over-engineering                                                │
│    • Add/remove generics                                                    │
│                                                                             │
│  When to apply:                                                             │
│    • Readability issues                                                     │
│    • Reusability concerns                                                   │
│    • Over-engineering detected                                              │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│  PARADIGM SHIFT                                                             │
│  ─────────────────────────────────────────────────────────────────────────  │
│  Change programming paradigm entirely                                       │
│                                                                             │
│  Examples:                                                                  │
│    • Object-oriented → Functional                                           │
│    • Procedural → Reactive                                                  │
│    • Imperative → Declarative                                               │
│    • Stateful → Stateless                                                   │
│                                                                             │
│  When to apply:                                                             │
│    • Fundamental design mismatch with problem                               │
│    • All mutations in current paradigm fail                                 │
│    • Exploring radically different approach                                 │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Architecture Mutation Operators

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  LAYER INJECTION/REMOVAL                                                    │
│  ─────────────────────────────────────────────────────────────────────────  │
│  • Add abstraction layer (e.g., introduce service layer)                    │
│  • Remove unnecessary layer (simplify architecture)                         │
│  • Introduce middleware, interceptors, decorators                           │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│  COMPONENT SPLITTING/MERGING                                                │
│  ─────────────────────────────────────────────────────────────────────────  │
│  • Split monolithic component into smaller pieces                           │
│  • Merge fragmented components into cohesive unit                           │
│  • Adjust coupling and cohesion                                             │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│  DEPENDENCY INVERSION                                                       │
│  ─────────────────────────────────────────────────────────────────────────  │
│  • Introduce dependency injection                                           │
│  • Add interface abstractions                                               │
│  • Invert control flow (IoC containers)                                     │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## VERIFICATION PROOF CONSTRUCTION

Phase 5 requires formal proofs that mutations improve solutions. Use these proof types:

### Proof Type Hierarchy

```
PROOF STRENGTH (weakest to strongest):

1. EMPIRICAL EVIDENCE
   - Benchmark comparisons
   - Test suite pass rates
   - Profiling data

2. LOGICAL DEDUCTION
   - Complexity analysis (O-notation improvements)
   - Type safety proofs
   - Invariant preservation

3. FORMAL VERIFICATION
   - Mathematical proofs
   - Property-based testing (QuickCheck style)
   - Model checking

USE STRONGEST PROOF FEASIBLE WITHIN TIME CONSTRAINTS
```

### Proof Templates

#### Template 1: Performance Improvement Proof

```
CLAIM: Mutation M improves performance over parent solution P

PROOF:
  1. MEASURE baseline:
     - Run P with representative inputs I1, I2, ..., In
     - Record time T_P and space S_P

  2. MEASURE mutation:
     - Run M with same inputs I1, I2, ..., In
     - Record time T_M and space S_M

  3. ANALYZE complexity:
     - Identify algorithmic change
     - Prove T_M ∈ O(f(n)) where f(n) < g(n) and T_P ∈ O(g(n))

  4. VERIFY correctness preserved:
     - Prove M produces identical outputs to P for all inputs
     - Or prove M outputs satisfy same invariants/contracts

  5. CONCLUDE:
     IF T_M < T_P AND complexity_class(M) ≤ complexity_class(P) AND correctness_preserved
     THEN improvement proven ∎
```

#### Template 2: Correctness Improvement Proof

```
CLAIM: Mutation M fixes bug B that existed in parent P

PROOF:
  1. IDENTIFY bug:
     - Specify input I_fail that causes P to produce wrong output
     - Specify expected output O_expected
     - Show P(I_fail) ≠ O_expected

  2. VERIFY fix:
     - Show M(I_fail) = O_expected

  3. PROVE no regression:
     - For all test inputs T where P(T) was correct:
       Show M(T) = P(T)
     - Or: Show test suite pass rate(M) ≥ pass rate(P)

  4. CONCLUDE:
     IF M fixes bug AND no regressions
     THEN improvement proven ∎
```

#### Template 3: Robustness Improvement Proof

```
CLAIM: Mutation M handles edge cases better than parent P

PROOF:
  1. ENUMERATE edge cases:
     - List edge inputs E1, E2, ..., Ek not handled by P

  2. VERIFY handling:
     - For each Ei, show M handles it gracefully:
       • Returns sensible default, OR
       • Throws descriptive error, OR
       • Degrades gracefully

  3. PROVE backward compatibility:
     - For all inputs handled by P, M behaves identically or better

  4. CONCLUDE:
     IF edge case coverage(M) > edge case coverage(P) AND no breakage
     THEN improvement proven ∎
```

### Proof Rejection Criteria

REJECT mutation if any of:
- Performance degrades without compensating improvement
- Correctness regression detected (even one test fails)
- No measurable improvement demonstrated
- "Improvement" is purely subjective (style, preference)
- Proof relies on untested assumptions

---

## WORKED EXAMPLE: FIBONACCI COMPUTATION

Let's trace the framework through a complete problem.

### Problem Statement
"Write an efficient function to compute the nth Fibonacci number."

---

### PHASE 0: FRAMEWORK SELECTION

**Analysis:**
- Solution paths: Multiple (recursive, iterative, matrix, memoized, etc.)
- Dependencies: Relatively independent approaches (hierarchical, not graph)
- Complexity: Medium (clear problem, but optimization trade-offs)

**Decision:** Use **Tree of Thoughts (ToT)**
- Multiple valid approaches worth exploring
- Can prune slow approaches early
- Don't need cross-branch synthesis (no cycles in dependencies)

---

### PHASE 1: DECOMPOSE

**Atomic sub-problems:**
1. Define correctness: fib(n) = fib(n-1) + fib(n-2), base cases fib(0)=0, fib(1)=1
2. Constraints: Must handle n ≥ 0, ideally up to n=100+
3. Success criteria: Correct output + reasonable performance

**Fitness function:**
```
fitness(solution) = correctness_score * 40 + performance_score * 30 + readability_score * 20 + robustness_score * 10

Where:
  correctness_score = (tests passed / total tests) * 100
  performance_score = 100 - normalize(execution_time, 0ms, 1000ms)
  readability_score = subjective assessment 0-100
  robustness_score = (edge cases handled / total edge cases) * 100
```

**Complexity class:** Medium → Population size N=5

---

### PHASE 2: GENESIS

**Solution 1: Naive Recursive**
```python
def fib_recursive(n):
    if n <= 1:
        return n
    return fib_recursive(n-1) + fib_recursive(n-2)
```
- approach_type: "divide-and-conquer"
- expected_strengths: Simple, readable, matches mathematical definition
- expected_weaknesses: Exponential time O(2^n), stack overflow risk

**Solution 2: Iterative**
```python
def fib_iterative(n):
    if n <= 1:
        return n
    a, b = 0, 1
    for _ in range(2, n+1):
        a, b = b, a + b
    return b
```
- approach_type: "iterative-optimization"
- expected_strengths: O(n) time, O(1) space, no recursion overhead
- expected_weaknesses: Less intuitive than recursive

**Solution 3: Memoized Recursive**
```python
def fib_memoized(n, memo={}):
    if n in memo:
        return memo[n]
    if n <= 1:
        return n
    memo[n] = fib_memoized(n-1, memo) + fib_memoized(n-2, memo)
    return memo[n]
```
- approach_type: "dynamic-programming"
- expected_strengths: O(n) time, maintains recursion clarity
- expected_weaknesses: O(n) space, mutable default argument bug

**Solution 4: Matrix Exponentiation**
```python
def fib_matrix(n):
    def matrix_mult(A, B):
        return [[A[0][0]*B[0][0] + A[0][1]*B[1][0], A[0][0]*B[0][1] + A[0][1]*B[1][1]],
                [A[1][0]*B[0][0] + A[1][1]*B[1][0], A[1][0]*B[0][1] + A[1][1]*B[1][1]]]

    def matrix_pow(M, p):
        if p == 1:
            return M
        if p % 2 == 0:
            half = matrix_pow(M, p//2)
            return matrix_mult(half, half)
        return matrix_mult(M, matrix_pow(M, p-1))

    if n <= 1:
        return n
    F = [[1, 1], [1, 0]]
    result = matrix_pow(F, n)
    return result[0][1]
```
- approach_type: "mathematical-optimization"
- expected_strengths: O(log n) time complexity
- expected_weaknesses: Complex, harder to understand

**Solution 5: Closed-Form (Binet's Formula)**
```python
import math

def fib_binet(n):
    phi = (1 + math.sqrt(5)) / 2
    psi = (1 - math.sqrt(5)) / 2
    return int((phi**n - psi**n) / math.sqrt(5))
```
- approach_type: "closed-form-mathematical"
- expected_strengths: O(1) time (if exponentiation is O(1))
- expected_weaknesses: Floating point precision errors for large n

---

### PHASE 3: EVALUATE

**Test inputs:** n = 0, 1, 2, 5, 10, 20, 30, 50, 100

**Results:**

| Solution | Correctness | Time (n=30) | Readability | Robustness | **Fitness** |
|----------|-------------|-------------|-------------|------------|-------------|
| Naive Recursive | 100% (up to n=30) | 832ms | 95 | 60 | **63.6** |
| Iterative | 100% | 0.8ms | 85 | 80 | **96.24** |
| Memoized | 100% | 1.2ms | 75 | 70 | **93.64** |
| Matrix | 100% | 0.3ms | 50 | 90 | **88.09** |
| Binet | 95% (fails n>70) | 0.1ms | 70 | 50 | **76.97** |

**Ranking:**
1. Iterative (96.24)
2. Memoized (93.64)
3. Matrix (88.09)
4. Binet (76.97)
5. Naive Recursive (63.6)

---

### PHASE 4: EVOLVE (Generation 1)

**Selection:** Keep top 3 (Iterative, Memoized, Matrix)

**Mutations:**

**M1: Fix Memoized default argument bug**
```python
def fib_memoized_v2(n, memo=None):
    if memo is None:
        memo = {}
    if n in memo:
        return memo[n]
    if n <= 1:
        return n
    memo[n] = fib_memoized_v2(n-1, memo) + fib_memoized_v2(n-2, memo)
    return memo[n]
```
- Mutation type: ERROR_HANDLING_ENHANCEMENT

**M2: Add input validation to Iterative**
```python
def fib_iterative_v2(n):
    if not isinstance(n, int) or n < 0:
        raise ValueError("Input must be a non-negative integer")
    if n <= 1:
        return n
    a, b = 0, 1
    for _ in range(2, n+1):
        a, b = b, a + b
    return b
```
- Mutation type: ERROR_HANDLING_ENHANCEMENT

**M3: Crossover (Iterative + Memoization concept)**
```python
# Cache results for reuse across calls
_fib_cache = {0: 0, 1: 1}

def fib_cached_iterative(n):
    if n in _fib_cache:
        return _fib_cache[n]

    # Compute all fib numbers from last cached up to n
    max_cached = max(_fib_cache.keys())
    a, b = _fib_cache[max_cached-1], _fib_cache[max_cached]

    for i in range(max_cached+1, n+1):
        a, b = b, a + b
        _fib_cache[i] = b

    return _fib_cache[n]
```
- Mutation type: CROSSOVER + OPTIMIZATION_INJECTION

---

### PHASE 5: VERIFY

**Verification of M1 (Memoized bug fix):**

```
CLAIM: M1 fixes mutable default argument bug

PROOF:
  1. IDENTIFY BUG:
     - Multiple calls to fib_memoized share same memo dict
     - Test: Call fib_memoized(5), then fib_memoized(3)
     - Second call reuses cached values incorrectly if memo state persists

  2. VERIFY FIX:
     - M1 creates new memo dict on each call (when None)
     - Each invocation has isolated state
     - Test passes: repeated calls produce correct results

  3. NO REGRESSION:
     - All previous test cases still pass
     - Performance unchanged (O(n) time complexity preserved)

  ∴ Improvement proven ✓
```

**Verification of M2 (Input validation):**

```
CLAIM: M2 improves robustness

PROOF:
  1. EDGE CASES ADDED:
     - E1: fib_iterative(-5) → was: incorrect behavior
     - E2: fib_iterative("string") → was: TypeError
     - E3: fib_iterative(3.5) → was: incorrect behavior

  2. VERIFY HANDLING:
     - M2 raises ValueError with clear message for all E1-E3

  3. BACKWARD COMPATIBILITY:
     - All valid inputs (n >= 0, integer) behave identically

  ∴ Improvement proven ✓
```

**Verification of M3 (Cached iterative):**

```
CLAIM: M3 improves performance for multiple calls

PROOF:
  1. BASELINE:
     - 10 calls to fib_iterative(30): 8ms total

  2. MUTATION:
     - 10 calls to fib_cached_iterative(30):
       First call: 0.8ms, subsequent 9 calls: 0.001ms each
       Total: ~0.81ms

  3. COMPLEXITY ANALYSIS:
     - First call: O(n)
     - Subsequent calls with n <= max_cached: O(1)
     - Amortized improvement for multiple calls

  4. CORRECTNESS:
     - All test cases pass
     - Cache correctly accumulates values

  ∴ Improvement proven for multi-call scenario ✓
```

---

### PHASE 6: CONVERGE

**Updated population fitness:**

| Solution | Fitness |
|----------|---------|
| **fib_iterative_v2** | **98.24** ← +2 for robustness |
| fib_cached_iterative | 97.5 ← (depends on use case) |
| fib_memoized_v2 | 95.64 ← +2 for bug fix |
| fib_iterative | 96.24 |
| fib_matrix | 88.09 |

**Decision:** `fib_iterative_v2` meets success criteria
- Correctness: 100%
- Performance: Excellent for single calls, O(n) time, O(1) space
- Readability: High
- Robustness: Input validation added

**→ DELIVER fib_iterative_v2**

---

### PHASE 7: REFLECT

**SOLUTION REFLECTION:**
- **Winner:** Iterative approach with input validation
- **Decisive trait:** Optimal balance of simplicity, performance, and robustness
- **Why others lost:**
  - Naive recursive: Too slow (exponential time)
  - Matrix: Over-engineered for this problem
  - Binet: Precision issues
  - Memoized: More complex than needed for single-call use case

**PROCESS REFLECTION:**
- **Explored right space?** Yes - covered major algorithmic approaches
- **What missed?** Could have explored generator-based solution for memory efficiency
- **Premature pruning?** No - gave each approach fair evaluation

**ASSUMPTION AUDIT:**
- ✓ VALIDATED: Iterative is fast enough for reasonable n
- ✓ VALIDATED: Readability matters for Fibonacci (teaching example)
- ✗ INVALIDATED: Assumed memoization always better (not for single calls)
- ? UNTESTED: Assumption about n upper bound (optimized for n < 1000)

**MUTATION ANALYSIS:**
- **Helpful:** Input validation (M2), bug fix (M1)
- **Context-dependent:** Cached iterative (M3) - helps for multiple calls
- **Wasted:** None in this run
- **Should have tried:** Generator approach, consider n > 10^6 case

**PROOF QUALITY:**
- Empirical benchmarks: Rigorous ✓
- Correctness verification: Complete test coverage ✓
- Complexity analysis: Formal O-notation proofs ✓
- Overall: **8/10** (could formalize edge case enumeration more)

**FAILURE ANALYSIS:**
- No failures in this run
- If recursive solution timed out earlier → would have caught with timeout thresholds

**FRAMEWORK REFLECTION:**
- ToT was optimal choice ✓
- Branching allowed efficient pruning of naive recursive
- Didn't need GoT (no cross-branch synthesis required)

**REASONING QUALITY SCORE: 8/10**
- **Justification:**
  - ✓ Systematic exploration
  - ✓ Formal fitness function
  - ✓ Rigorous verification
  - ✗ Could have explored edge cases earlier (n > 10^6)
  - ✗ Slightly biased toward simplicity (may not scale to complex domains)

---

### PHASE 8: META-IMPROVE

**LESSONS EXTRACTED:**
1. **Lesson:** For optimization problems, define fitness function BEFORE genesis
   - **Why it helps:** Prevents subjective bias in evaluation
   - **Apply to:** All future optimization tasks

2. **Lesson:** Input validation should be standard mutation for any function
   - **Why it helps:** Catches robustness issues systematically
   - **Apply to:** Add to default mutation set

3. **Lesson:** Memoization != always better (context matters)
   - **Why it helps:** Prevents cargo-cult optimization
   - **Apply to:** Evaluate based on actual use case

4. **Lesson:** O(1) solutions can be worse than O(n) if constant factors high
   - **Why it helps:** Complexity analysis must include practical measurement
   - **Apply to:** Always benchmark, don't trust Big-O alone

**PROCESS IMPROVEMENTS:**
1. **Proposal:** Add "use case analysis" to DECOMPOSE phase
   - **Verification:** Would have identified single-call vs multi-call earlier
   - **→ ADD TO ACTIVE_LESSONS** ✓

2. **Proposal:** Create mutation priority queue based on problem type
   - **Verification:** Would save time on obviously beneficial mutations
   - **→ ADD TO ACTIVE_LESSONS** ✓

**ACTIVE_LESSONS (for this conversation):**
- Define fitness function before genesis
- Include use case analysis in decomposition
- Prioritize mutations by problem type
- Benchmark don't assume

---

## QUICK REFERENCE DECISION TREE

```
START
  │
  ├─ Is problem simple with obvious solution path?
  │  YES → Use CoT, execute linearly
  │  NO ↓
  │
  ├─ Are there multiple valid approaches to explore?
  │  YES ↓
  │  │
  │  ├─ Do approaches need to share insights?
  │  │  YES → Use GoT (graph exploration + synthesis)
  │  │  NO → Use ToT (tree exploration + pruning)
  │  │
  │  NO ↓
  │
  └─ Default → Start with CoT, escalate if stuck
```

## COMPLEXITY SCALING GUIDE

| Problem Complexity | Framework | Population Size | Generations | Total Thoughts (ST) |
|-------------------|-----------|----------------|-------------|---------------------|
| Trivial | CoT | N/A | N/A | 3-8 |
| Simple | CoT | N/A | N/A | 8-15 |
| Medium | ToT | 3-5 | 2-3 | 15-30 |
| Complex | ToT | 5-7 | 3-5 | 30-50 |
| Very Complex | GoT | 5-7 | 3-5 | 50-100+ |
| Research-level | GoT | 7+ | 5+ | 100-200+ |

---

## ANTI-PATTERNS TO AVOID

```
❌ ANTI-PATTERN: Premature optimization
   - Optimizing before establishing correctness
   → FIX: Always prioritize correctness in fitness function

❌ ANTI-PATTERN: Analysis paralysis
   - Infinite exploration without convergence
   → FIX: Set generation limits, use plateau detection

❌ ANTI-PATTERN: Proof hand-waving
   - Accepting "seems better" without verification
   → FIX: Require measurable improvement or logical proof

❌ ANTI-PATTERN: Ignoring edge cases
   - Only testing happy path
   → FIX: Enumerate edge cases in DECOMPOSE phase

❌ ANTI-PATTERN: Over-engineering
   - Using GoT for simple problems
   → FIX: Follow framework selection matrix strictly

❌ ANTI-PATTERN: Mutation spam
   - Applying too many mutations at once
   → FIX: 1-3 mutations per generation max

❌ ANTI-PATTERN: Skipping reflection
   - Moving to next problem without learning
   → FIX: Phase 7-8 are MANDATORY, not optional
```

---

## FINAL NOTES

This framework is **not** meant for every problem. Use it when:
- ✓ Problem is complex enough to warrant exploration
- ✓ First-attempt solutions typically fail
- ✓ You need the "best possible" solution, not just "good enough"
- ✓ Learning and meta-improvement matter

**Do NOT use** for:
- ✗ Simple CRUD operations
- ✗ Straightforward refactoring
- ✗ Questions with obvious answers
- ✗ Time-critical responses

**Remember:** The framework is a tool, not a religion. Adapt as needed, but always:
1. Select appropriate reasoning framework (CoT/ToT/GoT)
2. Verify improvements formally
3. Reflect on the process
4. Extract reusable lessons

---

**END OF DARWIN-GÖDEL MACHINE SPECIFICATION**

