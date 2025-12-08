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
