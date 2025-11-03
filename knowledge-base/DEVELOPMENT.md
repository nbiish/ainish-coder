# Development Workflow for ainish-coder

**Date:** 2025-11-02  
**Purpose:** Guide for developers working on ainish-coder tooling

---

## Installation & PATH Setup

### Current Setup (✅ Already Configured)

Your shell is configured with:
```bash
# In ~/.zshrc (line 488)
export PATH="$HOME/code/ainish-coder/bin:$PATH"
```

This means the `ainish-coder` command points directly to:
```
/Users/nbiish/code/ainish-coder/bin/ainish-coder
```

### Verification Commands

```bash
# Check if ainish-coder is in PATH
which ainish-coder

# Verify it points to your development directory
ls -l $(which ainish-coder)

# Test the command works
ainish-coder --version
```

---

## Development Workflow

### ✅ NO REINSTALL NEEDED!

Since `ainish-coder` is accessed directly from your repository via PATH, **any changes you make are immediately active**. No build, install, or reload step required!

### Making Changes

1. **Edit files directly** in your repository:
   ```bash
   cd /Users/nbiish/code/ainish-coder
   
   # Edit main CLI
   vim bin/ainish-coder
   
   # Edit molecule scripts
   vim population/molecules/deploy_*.sh
   
   # Edit atom utilities
   vim population/atoms/*.sh
   ```

2. **Test immediately**:
   ```bash
   ainish-coder --help    # Changes are live!
   ```

3. **No compilation or installation step needed** - bash scripts are interpreted

---

## When You DO Need to Reload

### Shell Configuration Changes

If you modify `~/.zshrc` or shell configuration:
```bash
# Reload shell configuration
source ~/.zshrc

# Or start a new terminal session
```

### PATH Issues

If `ainish-coder` command is not found:
```bash
# Verify PATH includes the bin directory
echo $PATH | grep ainish-coder

# If missing, add to ~/.zshrc:
echo 'export PATH="$HOME/code/ainish-coder/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

### File Permission Issues

If you get "Permission denied":
```bash
# Make the main script executable
chmod +x /Users/nbiish/code/ainish-coder/bin/ainish-coder

# Make all molecule scripts executable
chmod +x /Users/nbiish/code/ainish-coder/population/molecules/*.sh
chmod +x /Users/nbiish/code/ainish-coder/population/atoms/*.sh
```

---

## Testing Your Changes

### Quick Test Loop

```bash
# 1. Edit a file
vim bin/ainish-coder

# 2. Test immediately (no install needed)
ainish-coder --test-flag

# 3. Debug if needed
bash -x $(which ainish-coder) --test-flag
```

### Comprehensive Testing

```bash
# Create a clean test directory
cd /tmp
rm -rf test-ainish
mkdir test-ainish
cd test-ainish

# Test core commands
ainish-coder --rules
ainish-coder --tier 1
ainish-coder --cursor
ainish-coder --commands cursor

# Verify output
ls -la
cat AGENTS.md
cat MAIRULES.md
```

### Testing Specific Molecules

```bash
# Source and test individual functions
cd /Users/nbiish/code/ainish-coder
source population/atoms/colors.sh
source population/molecules/deploy_cursor.sh

# Test the function directly
deploy_cursor /tmp/test-dir
```

---

## Debugging

### Enable Bash Debug Mode

```bash
# See exactly what's executing
bash -x $(which ainish-coder) --your-command

# Or add to top of bin/ainish-coder temporarily:
set -x  # Enable debug mode
```

### Check for Syntax Errors

```bash
# Validate bash syntax without running
bash -n bin/ainish-coder

# Check all scripts
for script in population/molecules/*.sh; do
    echo "Checking $script..."
    bash -n "$script" || echo "❌ Syntax error in $script"
done
```

### Common Issues

1. **Undefined variable errors**:
   - Check `set -euo pipefail` at top of script
   - Ensure all variables are defined before use
   - Use `${VAR:-default}` for optional variables

2. **Function not found**:
   - Verify `source` statements load required files
   - Check function names match between files

3. **File not found**:
   - Check paths are absolute or properly resolved
   - Verify `SCRIPT_DIR` and `REPO_DIR` are correct

---

## Architecture Overview

### Script Structure

```
bin/ainish-coder              # Main CLI entry point
├── sources atoms/            # Core utilities (colors, paths, validation)
├── sources molecules/        # Deployment functions (deploy_*.sh)
└── main() function          # Command routing and execution
```

### Execution Flow

1. User runs: `ainish-coder --cursor`
2. Shell resolves: `/Users/nbiish/code/ainish-coder/bin/ainish-coder`
3. Script loads atoms (utilities)
4. Script loads molecules (deployment functions)
5. `main()` routes `--cursor` → `deploy_cursor()`
6. Function executes and copies files

### Adding New Commands

1. **Create molecule** (if needed):
   ```bash
   vim population/molecules/deploy_newtool.sh
   ```

2. **Add function**:
   ```bash
   deploy_newtool() {
       local target_dir="${1:-$(pwd)}"
       print_info "Deploying newtool configuration"
       # Your deployment logic here
   }
   ```

3. **Source in main CLI**:
   ```bash
   # Add to bin/ainish-coder
   source "${POPULATION_DIR}/molecules/deploy_newtool.sh"
   ```

4. **Add command handler**:
   ```bash
   # In main() function's case statement
   --newtool)
       deploy_newtool "$target_dir"
       ;;
   ```

5. **Test immediately** (no install needed):
   ```bash
   ainish-coder --newtool
   ```

---

## Version Control Workflow

### Before Committing

```bash
# Test all major commands
cd /tmp/test-clean
ainish-coder --rules
ainish-coder --tier all
ainish-coder --cursor

# Check syntax
bash -n bin/ainish-coder

# Verify no debug code left
grep -r "set -x" bin/ population/
```

### Commit Changes

```bash
cd /Users/nbiish/code/ainish-coder
git status
git add bin/ainish-coder population/molecules/deploy_*.sh
git commit -m "feat: Add new deployment function"
git push
```

---

## Rollback Changes

### Quick Rollback

```bash
# Undo uncommitted changes
git checkout bin/ainish-coder

# Undo last commit (keep changes)
git reset --soft HEAD~1

# Undo last commit (discard changes)
git reset --hard HEAD~1
```

### Use Backup

```bash
# The repo has a backup file
cp bin/ainish-coder.bak bin/ainish-coder
```

---

## Performance Tips

### Reduce Startup Time

- Minimize `source` statements (only load needed molecules)
- Avoid expensive operations in global scope
- Use lazy loading for rarely-used functions

### Avoid Subshells

```bash
# Slower (creates subshell)
var=$(cat file.txt)

# Faster (built-in)
var=$(<file.txt)
```

---

## Summary

**🎯 Key Takeaway:** Since `ainish-coder` is in your PATH and points directly to your development directory, **changes are immediately active** - just edit and run!

**No build step. No install step. No reload step.**

Just code and test! 🚀
