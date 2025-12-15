---
name: cognitive-hypercluster
description: |
  Structured reasoning framework for maximum-power analysis. Combines adversarial debate, iterative refinement, tool-augmented verification, and recursive self-improvement. Activates on: "ultrathink", "hyperthink", "godmode", "max power". Provides 5-15x improvement on complex problems.
---

# Cognitive Hypercluster (Claude-Only)

A structured reasoning framework that orchestrates multiple cognitive passes with specialized roles to achieve **5-15x improvement** over single-shot responses on complex problems.

## Core Philosophy

**Role Specialization**: Same model, different cognitive modes via prompt framing
**Adversarial Pressure**: Structured self-challenge through debate simulation
**Grounded Verification**: Claims verified through tool execution, not just reasoning
**Iterative Refinement**: Multiple candidates → score → improve → converge

## Important Clarifications

1. **Not true multi-agent**: This runs in a single context window, simulating different roles sequentially. You cannot surprise yourself, but structured opposition still helps.

2. **Not actual MCTS**: The "search" is iterative best-of-N refinement, not tree search with backpropagation. Simpler but still effective.

3. **Gains vary**: 5-15x improvement is realistic for code/math/analysis. Creative/subjective tasks see smaller gains.

---

## QUICK REFERENCE (TL;DR)

```
┌────────────────────────────────────────────────────────────────────────────────┐
│                 COGNITIVE HYPERCLUSTER (CLAUDE-ONLY)                           │
├────────────────────────────────────────────────────────────────────────────────┤
│  TRIGGERS: ultrathink, hyperthink, godmode, max power, full send               │
├────────────────────────────────────────────────────────────────────────────────┤
│  ROLES:                                                                        │
│  • VALIDATOR: Find flaws, prove, edge cases (conservative mode)                │
│  • EXPLORER: Diverge, cross-domain, reframe (creative mode)                    │
│  • SYNTHESIZER: Complete, implement, actionable (practical mode)               │
├────────────────────────────────────────────────────────────────────────────────┤
│  PHASES:                                                                       │
│  0. Classify → Problem type, config selection                                  │
│  1. Validator → Assumptions, edge cases, uncertainties                         │
│  2. Explorer → Reframe, 5+ approaches, analogies                               │
│  3. Synthesizer → Draft complete solution                                      │
│  4. Debate → Attack/defend up to 5 rounds                                      │
│  5. Verify → Execute code, check facts, test                                   │
│  6. Improve → Critique/revise up to 3 iterations                               │
│  7. Synthesize → Final answer with confidence                                  │
├────────────────────────────────────────────────────────────────────────────────┤
│  CONFIGS:                                                                      │
│  • BUDGET: ~$2, ~30s, quick check                                              │
│  • OPTIMIZED: ~$8, 2-5min, most tasks [DEFAULT]                                │
│  • MAXIMUM: ~$25, 10-20min, critical decisions                                 │
├────────────────────────────────────────────────────────────────────────────────┤
│  EARLY EXIT:                                                                   │
│  • Consensus > 85% → done                                                      │
│  • No new points in debate → done                                              │
│  • No substantive critiques → done                                             │
├────────────────────────────────────────────────────────────────────────────────┤
│  REALISTIC GAINS: 5-15x on complex problems (not 100x, be honest)              │
└────────────────────────────────────────────────────────────────────────────────┘
```

---

## LITE MODE (1 minute version)

For quick enhancement without full ceremony. Use when time-constrained or problem is medium complexity.

**Trigger:** "ultrathink lite" or "quick ultrathink"

```
⚡ HYPERCLUSTER LITE

📋 ASSUMPTIONS (list 3):
1. [assumption + risk level]
2. [assumption + risk level]  
3. [assumption + risk level]

⚠️ EDGE CASES (list 3):
1. [edge case + severity]
2. [edge case + severity]
3. [edge case + severity]

💡 ALTERNATIVES (list 2):
1. [different approach + trade-off]
2. [different approach + trade-off]

📝 BEST OPTION: [which and why]

🎯 CONFIDENCE: [X]%

⚠️ MAIN RISK: [single biggest concern]
```

**When to use Lite vs Full:**
- **Lite:** Medium complexity, time pressure, iterating quickly
- **Full:** High stakes, novel problems, need verification, complex decisions

---

## WHY THIS WORKS WITH SINGLE MODEL

You don't need different model families. The power comes from:

1. **Role injection** - Same Claude, different thinking modes
2. **Adversarial structure** - Forcing self-challenge
3. **Tool grounding** - External verification
4. **Search breadth** - Many candidates, not one
5. **Recursive depth** - Solutions improving solutions

---

## ARCHITECTURE

```
                              ┌─────────────────────────────────┐
                              │          USER QUERY              │
                              └─────────────────────────────────┘
                                              │
                                              ▼
┌─────────────────────────────────────────────────────────────────────────────────────┐
│  PHASE 0: CLASSIFY                                                                   │
│  ├─ Determine problem type (FACTUAL/ANALYTICAL/CREATIVE/IMPLEMENTATION/DECISION)    │
│  ├─ Select config (BUDGET/OPTIMIZED/MAXIMUM)                                         │
│  └─ Output: "⚡ HYPERCLUSTER ACTIVATED | Type: [X] | Config: [Y]"                    │
└─────────────────────────────────────────────────────────────────────────────────────┘
                                              │
                  ┌───────────────────────────┼───────────────────────────┐
                  ▼                           ▼                           ▼
┌─────────────────────────────────────────────────────────────────────────────────────┐
│  PHASE 1: VALIDATOR         PHASE 2: EXPLORER         PHASE 3: SYNTHESIZER          │
│  ┌───────────────────┐      ┌───────────────────┐      ┌───────────────────┐        │
│  │ Mode: Conservative│      │ Mode: Creative    │      │ Mode: Practical   │        │
│  │ ─────────────────│      │ ─────────────────│      │ ─────────────────│        │
│  │ • Assumptions     │      │ • Reframe problem │      │ • Draft solution  │        │
│  │ • Edge cases      │      │ • 5+ approaches   │      │ • Complete answer │        │
│  │ • Uncertainties   │      │ • Cross-domain    │      │ • Actionable      │        │
│  │ • Risk ratings    │      │ • Wild cards      │      │ • Requirements    │        │
│  └───────────────────┘      └───────────────────┘      └───────────────────┘        │
└─────────────────────────────────────────────────────────────────────────────────────┘
                                              │
                                              ▼
┌─────────────────────────────────────────────────────────────────────────────────────┐
│  PHASE 4: ADVERSARIAL DEBATE (up to 5 rounds, early termination)                     │
│  ┌─────────────────────────────────────────────────────────────────────────────┐    │
│  │  Round N:                                                                    │    │
│  │  ATTACK: "What's wrong with this solution?"                                  │    │
│  │  DEFEND: "Here's why it holds / here's the fix"                              │    │
│  │  JUDGE:  "The stronger argument is..."                                       │    │
│  │                                                                              │    │
│  │  Exit early if:                                                              │    │
│  │  • Consensus > 85%                                                           │    │
│  │  • No new points raised                                                      │    │
│  │  • One side clearly dominates                                                │    │
│  └─────────────────────────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────────────────────┘
                                              │
                                              ▼
┌─────────────────────────────────────────────────────────────────────────────────────┐
│  PHASE 5: TOOL VERIFICATION (if applicable)                                          │
│  ├─ Code claims → Execute in sandbox, run tests                                      │
│  ├─ Factual claims → Web search cross-reference                                      │
│  ├─ Math claims → Compute/verify symbolically                                        │
│  └─ All claims → Test with adversarial inputs                                        │
└─────────────────────────────────────────────────────────────────────────────────────┘
                                              │
                                              ▼
┌─────────────────────────────────────────────────────────────────────────────────────┐
│  PHASE 6: SELF-IMPROVEMENT (up to 3 iterations)                                      │
│  ├─ CRITIQUE: "What's still wrong? Be harsh."                                        │
│  ├─ REVISE: "Fix those issues."                                                      │
│  ├─ CHECK: "Did the fix work?"                                                       │
│  └─ Exit when no substantive critiques remain                                        │
└─────────────────────────────────────────────────────────────────────────────────────┘
                                              │
                                              ▼
┌─────────────────────────────────────────────────────────────────────────────────────┐
│  PHASE 7: FINAL SYNTHESIS                                                            │
│  ├─ Merge best solution with debate insights                                         │
│  ├─ Attach verification results                                                      │
│  ├─ Calculate calibrated confidence                                                  │
│  ├─ Document dissent and limitations                                                 │
│  └─ Produce final answer with provenance                                             │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

**Note:** This is a sequential single-context execution. The diagram shows logical flow, not parallel processing. For true parallel/ensemble execution, see API ORCHESTRATION section below.

---

## ROLE PROMPTS

### CLAUDE:VALIDATOR

```
You are operating in VALIDATOR mode. Your cognitive style:

PRIME DIRECTIVE: Find what's wrong, missing, or uncertain.

THINKING ALLOCATION:
- 30% Assumption excavation (surface every hidden assumption)
- 30% Edge case generation (adversarial inputs that break things)
- 25% Proof construction (verify claims formally)
- 15% Uncertainty quantification (what remains unknown)

BEHAVIORAL RULES:
- Mode: Conservative, precise, skeptical
- Default stance: "What could go wrong?"
- When uncertain: Say so explicitly
- When something is wrong: Prove it with counterexample

OUTPUT MUST INCLUDE:
1. Assumption table with risk ratings
2. Edge cases with severity scores
3. Proof status for each claim (PROVEN / UNPROVEN / UNPROVABLE)
4. Confidence score with justification
5. Critical uncertainties that remain

You are NOT trying to be creative. You are trying to be correct.
```

### CLAUDE:EXPLORER

```
You are operating in EXPLORER mode. Your cognitive style:

PRIME DIRECTIVE: Find paths others won't think of.

THINKING ALLOCATION:
- 40% Divergent generation (many different approaches)
- 25% Cross-domain transfer (analogies from other fields)
- 20% Frame challenging (is this the right question?)
- 15% Constraint relaxation (what if we broke rules?)

BEHAVIORAL RULES:
- Mode: Creative, expansive, divergent
- Default stance: "What else? What if?"
- Generate minimum 5 distinct approaches before evaluating
- Include at least 1 "wild card" unconventional idea

OUTPUT MUST INCLUDE:
1. Frame analysis (alternative ways to see the problem)
2. Solution population (5+ approaches with trade-offs)
3. Cross-domain analogies (insights from other fields)
4. Constraint experiments (what opens up if we bend rules)
5. Novelty score for each approach

You are NOT trying to be safe. You are trying to be innovative.
```

### CLAUDE:SYNTHESIZER

```
You are operating in SYNTHESIZER mode. Your cognitive style:

PRIME DIRECTIVE: Produce complete, actionable output.

THINKING ALLOCATION:
- 30% Requirements consolidation (capture everything needed)
- 30% Implementation planning (step-by-step execution)
- 25% Output generation (the actual deliverable)
- 15% Coverage verification (nothing missing)

BEHAVIORAL RULES:
- Temperature: 0.5 (balanced)
- Default stance: "Is this complete?"
- Code must be runnable, not pseudocode
- Content must be usable, not abstract

OUTPUT MUST INCLUDE:
1. Consolidated requirements
2. Complete deliverable (code/content/analysis)
3. Implementation notes
4. Coverage matrix (all requirements addressed?)
5. Completeness and actionability scores

You are NOT trying to be creative OR critical. You are trying to be comprehensive.
```

---

## ADVERSARIAL DEBATE PROTOCOL

```
DEBATE STRUCTURE (5 rounds max, early termination):

Round 1: 
  - PROPOSER (Validator): Present initial solution with proofs
  - ADVERSARY (Explorer): Attack from unexpected angles
  - JUDGE (Synthesizer): Evaluate practical merit

Round 2:
  - PROPOSER (Explorer): Present alternative framing
  - ADVERSARY (Synthesizer): Attack completeness gaps  
  - JUDGE (Validator): Evaluate logical soundness

Round 3:
  - PROPOSER (Synthesizer): Present unified solution
  - ADVERSARY (Validator): Attack edge cases
  - JUDGE (Explorer): Evaluate if better approaches exist

[Roles continue rotating...]

EARLY TERMINATION TRIGGERS:
- Convergence > 85%: All roles agree → EXIT
- Plateau: < 5% score change for 2 rounds → EXIT
- Dominant winner: One solution leads by > 30% → EXIT

ADVERSARY ATTACK TEMPLATE:
"Your proposal fails because:
1. LOGICAL FLAW: [specific contradiction]
2. COUNTEREXAMPLE: [concrete case that breaks it]
3. HIDDEN ASSUMPTION: [unstated belief that may be false]
4. SUPERIOR ALTERNATIVE: [better approach if I have one]
Attack the weakest point with maximum force."
```

---

## CONFIGURATIONS

### BUDGET (~30 seconds, ~$2)
```
budget_config = {
    "thinking_budget": 16000,
    "debate_rounds": 2,
    "refinement_candidates": 5,
    "ensemble_candidates": 5,
    "self_improve_iterations": 1,
    "tools": ["code_execution"]
}
```

### OPTIMIZED (~2-5 minutes, ~$8) [DEFAULT]
```
optimized_config = {
    "thinking_budget": 64000,
    "debate_rounds": 5,
    "refinement_candidates": 15,
    "ensemble_candidates": 25,
    "self_improve_iterations": 3,
    "tools": ["code_execution", "web_search", "math_verify"]
}
```

### MAXIMUM (~10-20 minutes, ~$25)
```
maximum_config = {
    "thinking_budget": 128000,
    "debate_rounds": 10,
    "refinement_candidates": 30,
    "ensemble_candidates": 50,
    "self_improve_iterations": 5,
    "tools": ["code_execution", "web_search", "math_verify", "fuzzer"]
}
```

---

## EXECUTABLE BOOTSTRAP

When hypercluster is triggered, execute this flow. Output phase markers so user can follow progress.

### THE ACTUAL EXECUTION SEQUENCE

```
═══════════════════════════════════════════════════════════════════
PHASE 0: CLASSIFY
═══════════════════════════════════════════════════════════════════
Determine problem type: FACTUAL | ANALYTICAL | CREATIVE | IMPLEMENTATION | DECISION
Select config: BUDGET | OPTIMIZED | MAXIMUM
Output: "⚡ HYPERCLUSTER ACTIVATED | Type: [X] | Config: [Y]"

═══════════════════════════════════════════════════════════════════
PHASE 1: VALIDATOR PASS
═══════════════════════════════════════════════════════════════════
Ask yourself in conservative mode:
- What assumptions am I making?
- What edge cases could break this?
- What claims need verification?
- What am I uncertain about?

Output:
📋 ASSUMPTIONS: [list with risk levels]
⚠️ EDGE CASES: [list with severity]
❓ UNCERTAINTIES: [list]

═══════════════════════════════════════════════════════════════════
PHASE 2: EXPLORER PASS  
═══════════════════════════════════════════════════════════════════
Ask yourself in creative mode:
- Is this the right framing?
- What are 5+ different approaches?
- What would [other domain] do?
- What if I relaxed constraints?

Output:
🔀 REFRAME: [alternative framings]
💡 APPROACHES: [5+ options with trade-offs]
🌉 CROSS-DOMAIN: [analogies that help]

═══════════════════════════════════════════════════════════════════
PHASE 3: SYNTHESIZER PASS
═══════════════════════════════════════════════════════════════════
Ask yourself in practical mode:
- What's the most complete solution?
- Does it address the edge cases?
- Is it immediately actionable?

Output:
📝 DRAFT SOLUTION: [complete answer]

═══════════════════════════════════════════════════════════════════
PHASE 4: ADVERSARIAL DEBATE (up to 5 rounds)
═══════════════════════════════════════════════════════════════════
Round N:
- ATTACK: "What's wrong with this solution?"
- DEFEND: "Here's why it holds / here's the fix"
- JUDGE: "The stronger argument is..."

Exit early if:
- Agreement > 85%
- No new points raised
- One side clearly dominates

Output:
⚔️ DEBATE ROUND [N]: [key point contested]
🏁 RESOLUTION: [consensus | split | dominant winner]

═══════════════════════════════════════════════════════════════════
PHASE 5: TOOL VERIFICATION (if applicable)
═══════════════════════════════════════════════════════════════════
- Code? → Execute it, run tests
- Math? → Compute/verify
- Facts? → Search to confirm
- Logic? → Trace the proof

Output:
🔧 VERIFIED: [what was checked]
✓/✗ RESULTS: [pass/fail]

═══════════════════════════════════════════════════════════════════
PHASE 6: SELF-IMPROVEMENT (up to 3 iterations)
═══════════════════════════════════════════════════════════════════
- CRITIQUE: "What's still wrong? Be harsh."
- REVISE: "Fix those issues."
- CHECK: "Did the fix work?"

Exit when no substantive critiques remain.

Output:
🔄 ITERATION [N]: [what was improved]

═══════════════════════════════════════════════════════════════════
PHASE 7: FINAL SYNTHESIS
═══════════════════════════════════════════════════════════════════
Combine everything into final answer with:
- The solution
- Confidence level
- What was verified
- What remains uncertain
- Known limitations

Output: [Use the OUTPUT FORMAT below]
```

### FAILURE RECOVERY

If any phase produces poor output:
1. **Garbage output** → Retry phase with more explicit constraints
2. **Deadlock in debate** → Force judge to pick winner or declare tie
3. **All candidates bad** → Step back, reframe problem, restart from Phase 2
4. **Tools unavailable** → Note as unverified, increase uncertainty
5. **Budget exhausted** → Output best current answer with "INCOMPLETE" flag

---

## API ORCHESTRATION (Advanced)

The phases above run sequentially in a single conversation. For **true parallel execution** and **ensemble generation**, you need API-level orchestration.

### What Requires API Access

| Feature | In-Conversation | Requires API |
|---------|-----------------|--------------|
| Role simulation | ✓ Yes | - |
| Sequential debate | ✓ Yes | - |
| Tool verification | ✓ Yes | - |
| Self-improvement | ✓ Yes | - |
| **True parallel agents** | ✗ No | ✓ Yes |
| **N separate candidates**