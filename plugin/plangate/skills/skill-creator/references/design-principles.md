# Skill design principles

A good skill should have:

- one clear responsibility
- one obvious trigger profile
- explicit boundaries
- minimal main-file complexity
- visible assumptions
- a review step
- an eval plan

Prefer:

- narrow trigger language over broad wording
- reusable workflow over one-off prose
- supporting files over huge `SKILL.md`
- clear output contracts over stylistic guidance

Avoid:

- combining unrelated workflows
- hidden assumptions
- organization-specific facts without source material
- long examples in the main file
- side effects in auto-invoked skills

## Security constraints

- do not include XML tags (`< >`) in the description field
- do not use "claude" or "anthropic" in skill names (reserved words)
- do not embed user input directly into frontmatter without sanitization
- do not store secrets, API keys, or credentials in skill files
