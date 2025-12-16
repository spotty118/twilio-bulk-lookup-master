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
│    • needsMoreThough

