# Claude Code Skills

This folder contains custom skills for Claude Code that enhance AI-assisted development on this project.

## Available Skills

### darwin-godwin-machine
Evolutionary reasoning with formal verification. Automatically activates when you need:
- Complex architecture decisions
- Debugging hard problems
- Exploring multiple solution approaches
- Optimizing existing code

**Trigger phrases:** "find the best approach", "explore all options", "powerful reasoning", "debug this"

### phantom-protocol
PHANTOM v5: Cognitive architecture for debugging, code review, generation, and self-analysis. Combines:
- **Abductive Fault Inversion** - Work backwards from symptoms to causes
- **Spectral Execution Tracing** - Ghost (intended) vs Demon (actual) dual traces
- **Dialectical Assumption Collapse** - Systematically invert assumptions until one cracks
- **Cognitive Immune System (CIS)** - 15 antibodies for real-time failure mode detection

**Activates for:** debugging, code review, "why isn't this working", architecture design, high-stakes reasoning

**Phases:**
- MANIFESTATION → DIVINATION → SUMMONING → INQUISITION → TRIANGULATION → EXORCISM → CONSECRATION

## Usage

These skills are automatically detected by Claude Code when you work in this repository. No explicit invocation needed — Claude will use them when relevant based on your request.

## Adding More Skills

Create a new folder under `.claude/skills/` with a `SKILL.md` file:

```
.claude/skills/
├── darwin-godwin-machine/
│   └── SKILL.md
└── your-new-skill/
    └── SKILL.md
```

See [Claude Code Skills Documentation](https://code.claude.com/docs/en/skills) for details.
