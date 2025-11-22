# 🎉 GitHub Actions Auto-Sanitization

## ✅ DONE! Your repository now has automatic secret sanitization!

### What I Added:

1. **`.github/workflows/auto-sanitize.yml`**
   - 🤖 Automatically detects and removes secrets on every push
   - 📝 Commits cleaned files back to your branch
   - 💬 Comments on PRs when secrets are found
   - ⚡ Uses `[skip ci]` to prevent infinite loops

2. **`.github/workflows/detect-secrets.yml`**
   - 🚨 Scans for secrets using TruffleHog and Gitleaks
   - 🛑 Blocks PRs that contain secrets
   - 🔍 Custom pattern matching for your specific secrets
   - 💬 Helpful PR comments with remediation steps

3. **`.github/workflows/llms.txt`**
   - 📚 Complete documentation
   - 🎨 Visual workflow diagram
   - 🔧 Customization guide
   - 🐛 Troubleshooting section

4. **`test-github-actions.sh`**
   - 🧪 Test workflows locally using `act`
   - 🔎 Verify before pushing to GitHub

5. **Advanced Security Suite**
   - 🛡️ **OWASP ZAP**: Dynamic Application Security Testing (DAST)
   - ⚛️ **PQC Audit**: Post-Quantum Cryptography readiness checks
   - 🔍 **CodeQL**: Static Analysis (SAST) with Copilot Autofix support
   - 📚 **Security Guide**: `knowledge-base/SECURITY_IMPLEMENTATION.md` for LLM-assisted remediation

## 🤖 Instructions for AI Agents

If you are an LLM (Copilot, Cursor, Cline, etc.) working in this repository:

1.  **Read the Master Guide**: `knowledge-base/SECURITY_IMPLEMENTATION.md` contains the TOON-formatted security architecture.
2.  **Analyze SARIF**: Check `.github/workflows/` to understand the scanning schedule.
3.  **Remediation**: When fixing alerts, strictly follow the "Hybrid Mode" PQC standards defined in the guide.

### 🚀 How to Enable:

#### Step 1: Enable Actions Permissions

**Detailed Steps:**

1. Go to your repository: `https://github.com/nbiish/ainish-coder`
2. Click **Settings** (gear icon under repository name)
3. In the **left sidebar**, click **Actions** → **General**
4. Scroll down to the **"Workflow permissions"** section (near the bottom)
5. Select: **"Read and write permissions"** radio button
6. ✅ Check the box: **"Allow GitHub Actions to create and approve pull requests"**
7. Click **Save** button

**Visual Path:**
```
Repository → Settings (tab) → Actions (left sidebar) → General → 
Scroll to bottom → Workflow permissions section
```

#### Step 2: Push These Changes

```bash
git add .github/workflows/
git commit -m "feat: add automatic secret sanitization"
git push
```

#### Step 3: Test It!

```bash
# Add a test secret
echo '{"BRAVE_API_KEY": "BSAtestkey12345678901234567"}' > CONFIGURATIONS/MCP/test.json

# Commit and push
git add CONFIGURATIONS/MCP/test.json
git commit -m "test: trigger auto-sanitize"
git push

# Watch the magic happen! 🎩✨
# Go to: https://github.com/nbiish/ainish-coder/actions
```

### 📊 How It Works:

```
┌─────────────────────────────────────────────────────────┐
│  You: git push                                          │
└─────────────────┬───────────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────────┐
│  GitHub Actions: Detect secrets in CONFIGURATIONS/     │
└─────────────────┬───────────────────────────────────────┘
                  │
         ┌────────┴────────┐
         ▼                 ▼
    ┌─────────┐      ┌──────────┐
    │ Secrets │      │ No       │
    │ Found   │      │ Secrets  │
    └────┬────┘      └────┬─────┘
         │                │
         ▼                ▼
    ┌─────────┐      ┌──────────┐
    │ Auto-   │      │ ✅ Pass  │
    │ Clean   │      └──────────┘
    └────┬────┘
         │
         ▼
    ┌─────────┐
    │ Commit  │
    │ Changes │
    └────┬────┘
         │
         ▼
    ┌─────────┐
    │ Comment │
    │ on PR   │
    └─────────┘
```

### 🛡️ Three Layers of Protection:

| Layer | Tool | When | Action |
|-------|------|------|--------|
| 🥇 Local | git-secrets | Before commit | **BLOCKS** commit |
| 🥈 Local | pre-commit hook | Before push | **BLOCKS** push |
| 🥉 Cloud | GitHub Actions | After push | **AUTO-CLEANS** |

### 🎯 What Gets Auto-Cleaned:

- ✅ **AI & LLM Keys**:
  - `OPENAI_API_KEY`, `ANTHROPIC_API_KEY`, `GEMINI_API_KEY`
  - `GOOGLE_API_KEY`, `MISTRAL_API_KEY`, `COHERE_API_KEY`
  - Hugging Face: `HUGGINGFACE_TOKEN`, `HUGGINGFACEHUB_API_TOKEN`, `HUGGINGFACE_API_KEY`, `HF_TOKEN`
  - ElevenLabs: `ELEVENLABS_API_KEY`, `ELEVEN_API_KEY`
  - Nebius Token Factory: `NEBIUS_API_KEY`, `NEBIUS_TOKEN`
  - Modal: `MODAL_API_KEY`
  - Blaxel: `BLAXEL_API_KEY`
  - SambaNova: `SAMBANOVA_API_KEY`, `SAMBANOVA_TOKEN`
  - `REPLICATE_API_TOKEN`, `GROQ_API_KEY`, `OPENROUTER_API_KEY`, `TOGETHER_API_KEY`, `DEEPSEEK_API_KEY`
  - `PERPLEXITY_API_KEY`, `ZENMUX_API_KEY`, `QWEN_API_KEY`
  - `GITHUB_TOKEN`, `AZURE_OPENAI_API_KEY`
  - *And generic `*_API_KEY`, `*_TOKEN`, `*_SECRET` patterns*

- ✅ **Database & Cloud Keys**:
  - `SUPABASE_KEY`, `FIREBASE_API_KEY`, `MONGODB_URI`
  - `PINECONE_API_KEY`, `WEAVIATE_API_KEY`, `QDRANT_API_KEY`
  - `REDIS_URL`, `DATABASE_URL`, `POSTGRES_PASSWORD`
  - `ALGOLIA_API_KEY`, `STRIPE_SECRET_KEY`, `VERCEL_TOKEN`
  - `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`

- ✅ **Specific Patterns**:
  - OpenAI `sk-...` keys
  - Google `AIza...` keys
  - Brave `BSA...` keys
  - Tavily `tvly-...` keys

- ✅ **Local Environment**:
  - Local paths (`/Volumes/...`, `/Users/...`) → `/path/to/your/...`
  - Memory file paths → `/path/to/your/memory/memories.jsonl`

### 💡 Best Practice Workflow:

```bash
# 1. Make changes locally
vim CONFIGURATIONS/MCP/TIER_1/settings.json

# 2. git-secrets checks BEFORE commit (if installed)
git add .
git commit -m "update config"  # ← git-secrets blocks if secrets found

# 3. If git-secrets not installed, just push
git push  # ← GitHub Actions auto-cleans secrets!

# 4. Check Actions tab to see sanitization
# Go to: https://github.com/nbiish/ainish-coder/actions
```

### 🧪 Testing Locally (Optional):

```bash
# Install act (GitHub Actions local runner)
brew install act

# Test the workflows
./test-github-actions.sh
```

### 📖 Documentation:

- **Full guide:** `.github/workflows/llms.txt`
- **Setup details:** `KNOWLEDGE_BASE/SECRET_PROTECTION_SETUP.md`
- **Quick reference:** Run `bash dna/atoms/secret-protection-help.sh`

### 🔄 What Changed:

1. **Old way:** You had to manually run `bash dna/atoms/sanitize-settings.sh` before each commit
2. **New way:** GitHub Actions does it automatically on push!
3. **Best way:** Use both! Local git-secrets for immediate feedback + GitHub Actions as safety net

### ⚠️ Important Notes:

1. **Secrets briefly exist in history** - If you push a secret, it's in git history even after auto-clean
2. **Rotate exposed keys** - If a real key reaches GitHub, rotate it immediately
3. **Use git-secrets locally** - For best security, prevent secrets from ever being pushed
4. **First push will trigger** - Actions will scan and may auto-clean on first run

### 🎊 You're All Set!

Just push these changes and GitHub Actions will start protecting your secrets automatically!

```bash
git add .
git commit -m "feat: add automatic secret protection with GitHub Actions"
git push
```

Then visit: https://github.com/nbiish/ainish-coder/actions to see it in action! 🚀
