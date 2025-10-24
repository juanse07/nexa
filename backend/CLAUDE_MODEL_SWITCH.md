# AI Model Configuration Guide

This document explains how to switch between AI models for chat (Claude Haiku/Sonnet and OpenAI GPT-4o/GPT-4o-mini).

## Current Configuration

### Claude (provider: 'claude')
**Active Model:** Claude Sonnet 4.5 (2025-09-29) - Best for chat, complex reasoning
**Previous Model:** Claude Haiku 4 (2025-01-01) - Fast but not good enough for chat apps

### OpenAI (provider: 'openai')
**Active Model:** GPT-4o - More capable, better reasoning
**Previous Model:** GPT-4o-mini - Faster and cheaper

## How to Switch Models

### Claude Models - Using Environment Variables (Recommended)
Edit `backend/.env` and set:
```bash
# For Sonnet (currently active - best for chat)
CLAUDE_MODEL=claude-sonnet-4-5-20250929

# For Haiku (commented out - not recommended for chat apps)
# CLAUDE_MODEL=claude-haiku-4-20250101
```

Or edit `backend/src/routes/ai.ts` line 348:
```typescript
// Current default (Sonnet)
const claudeModel = process.env.CLAUDE_MODEL || 'claude-sonnet-4-5-20250929';
```

### OpenAI Models - Using Environment Variables (Recommended)
Edit `backend/.env` and set:
```bash
# For GPT-4o (currently active)
OPENAI_TEXT_MODEL=gpt-4o

# For GPT-4o-mini (commented out - uncomment to switch back)
# OPENAI_TEXT_MODEL=gpt-4o-mini
```

Or edit `backend/src/routes/ai.ts` line 266:
```typescript
// Current default (GPT-4o)
const textModel = process.env.OPENAI_TEXT_MODEL || 'gpt-4o';
```

## Model Comparison

### Claude Models
| Feature | Haiku 4 | Sonnet 4.5 |
|---------|---------|------------|
| Speed | ⚡️ Fastest | Moderate |
| Cost | 💰 Cheapest | More expensive |
| Capability | Good for simple tasks | Best for complex reasoning |
| Best for | Quick responses, high volume | Complex event planning, detailed analysis |
| Prompt Caching | ✅ Yes | ✅ Yes |

### OpenAI Models
| Feature | GPT-4o-mini | GPT-4o |
|---------|-------------|--------|
| Speed | ⚡️ Very fast | Moderate |
| Cost | 💰 Cheapest | More expensive |
| Capability | Good for most tasks | Best reasoning, complex tasks |
| Best for | High volume, simple queries | Complex analysis, better quality |
| Prompt Caching | ❌ No | ❌ No |

## Prompt Caching

**Claude Only** - Both Claude models use **prompt caching** to reduce costs by up to 90%:
- System prompts are cached automatically
- Date/time context is cached
- Reduces redundant processing of instructions
- Location: `backend/src/routes/ai.ts` lines 377-383

**OpenAI** - Does not support prompt caching yet, so repeated system prompts are billed at full price

## After Switching
1. **Restart backend server** for changes to take effect
2. If deployed, restart Docker container:
   ```bash
   ssh app@198.58.111.243 "cd /srv/app && docker compose restart api"
   ```

## Configuration Files
- `.env` - Environment variables
  - Claude: line 34 (`CLAUDE_MODEL`)
  - OpenAI: line 23 (`OPENAI_TEXT_MODEL`)
- `src/routes/ai.ts` - Model logic
  - Claude: line 348 (`handleClaudeRequest()` - lines 335-442)
  - OpenAI: line 266 (`handleOpenAIRequest()` - lines 253-330)

## Provider Selection in Frontend
The frontend sends a `provider` parameter in the request to choose between models:
- `provider: 'claude'` → Uses Claude (Haiku or Sonnet based on config)
- `provider: 'openai'` → Uses OpenAI (GPT-4o or GPT-4o-mini based on config)
