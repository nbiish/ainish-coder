# TRAE AI IDE - Quick Reference

**Last Updated:** November 3, 2025  
**Full Documentation:** [TRAE_INTEGRATION.md](./TRAE_INTEGRATION.md)

---

## ⚠️ SECURITY ALERT

**ByteDance Data Collection Active**

TRAE collects extensive telemetry including:

- Code and interactions (used for AI training)
- Device fingerprinting (persists across reinstalls)
- Regular 30-second server connections (even when idle)
- Multi-region data transmission (US, Singapore, Malaysia)

**DO NOT USE FOR:**

- ❌ Proprietary/confidential code
- ❌ Client work under NDA
- ❌ Production systems
- ❌ Security-critical components
- ❌ Indigenous intellectual property

**SAFE FOR:**

- ✅ Open-source projects
- ✅ Student work and learning
- ✅ Public portfolios
- ✅ Rapid prototypes (non-sensitive)

---

## What is TRAE?

Free AI-powered IDE by ByteDance with:

- **Builder Mode** - Autonomous project generation
- **SOLO Mode** - End-to-end development automation
- **MCP Support** - Custom agent integration
- **Multimodal** - Process images/designs
- **Multi-Model** - GPT-4o, Claude 3.5/3.7/4.0, Gemini 2.5

---

## Quick Start

### Installation

1. Download from [trae.ai](https://www.trae.ai/)
2. Install application (macOS/Windows)
3. Sign in (GitHub/Google/Guest)
4. Enable Privacy Mode (Settings → Privacy)

### Essential Configuration

Create `.traeignore`:

```gitignore
.env
*.key
secrets/
config/production*
node_modules/
.git/
```

Enable Privacy Mode:

- Settings → Privacy → Enable Privacy Mode

### Basic Usage

**Builder Mode:**

1. Click "Builder" button
2. Describe project: "Create React app with authentication"
3. Review generated plan
4. Accept/Reject changes

**Chat Mode:**

- Ask questions about code
- Request refactoring
- Debug with AI assistance

---

## MCP Server Setup

Configuration file: `~/.trae/mcp.json`

```json
{
  "mcpServers": {
    "coding-agent": {
      "command": "npx",
      "args": ["coding-agent-mcp"],
      "autoApprove": ["read_file", "list_directory"]
    }
  }
}
```

---

## Comparison with Alternatives

| Feature | TRAE | Cursor | Cline | Windsurf |
|---------|------|--------|-------|----------|
| Price | Free | $20/mo | Free | $10/mo |
| Privacy | ⚠️ Low | Medium | ✅ High | Medium |
| Builder Mode | ✅ Yes | ❌ No | ❌ No | ❌ No |
| Open Source | ❌ No | ❌ No | ✅ Yes | ❌ No |

**Choose TRAE if:** Free tier critical, need Builder Mode, open-source projects

**Choose Cline if:** Privacy critical, need full control, sensitive code

---

## Deployment with Ainish-Coder

```bash
# Deploy TRAE configuration (when implemented)
./bin/ainish-coder trae /path/to/project
```

**Recommended Tiers:**

- Tier 0-1: ❌ DO NOT DEPLOY
- Tier 2: ⚠️ CAUTION (public docs only)
- Tier 3-4: ✅ APPROVED (non-sensitive)

---

## Network Monitoring

**Block telemetry (optional):**

```bash
# Add to /etc/hosts
0.0.0.0 mon-va.byteoversea.com
0.0.0.0 maliva-mcs.byteoversea.com
0.0.0.0 api-sg-central.trae.ai
```

⚠️ May break TRAE functionality

---

## Best Practices

1. **Always use .traeignore** for sensitive files
2. **Enable Privacy Mode** in settings
3. **Review generated code** before accepting
4. **Security audit** AI-generated code
5. **Never commit credentials** to TRAE projects
6. **Regular privacy audits** of indexed files
7. **Use for non-sensitive work only**

---

## Resources

- **Full Guide:** [TRAE_INTEGRATION.md](./TRAE_INTEGRATION.md)
- **Official Site:** https://www.trae.ai/
- **Documentation:** https://docs.trae.ai/
- **Security Research:** Unit 221B Analysis (March 2025)

---

## Quick Decision Guide

**Use TRAE when:**

- Building open-source projects
- Learning new technologies
- Rapid prototyping non-sensitive apps
- Creating public portfolios
- Need free AI coding assistant

**Use Alternatives when:**

- Working with proprietary code
- Building production systems
- Handling sensitive data
- Privacy is paramount
- Under NDA/confidentiality agreements

---

**Document Type:** Quick Reference  
**Full Documentation:** 1,500+ lines in TRAE_INTEGRATION.md  
**Last Security Review:** November 3, 2025
