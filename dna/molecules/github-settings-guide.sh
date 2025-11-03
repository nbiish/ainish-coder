#!/bin/bash
# Visual guide to finding GitHub Actions settings

cat << 'EOF'

╔══════════════════════════════════════════════════════════════════╗
║          📍 HOW TO FIND GITHUB ACTIONS SETTINGS (2025)          ║
╚══════════════════════════════════════════════════════════════════╝

🌐 STEP-BY-STEP GUIDE:

1️⃣  Go to your repository on GitHub
   👉 https://github.com/nbiish/ainish-coder

2️⃣  Click the "Settings" tab
   👉 Look for the ⚙️ gear icon under your repository name
   👉 It's in the top navigation bar alongside Code, Issues, Pull requests, etc.

3️⃣  In the LEFT SIDEBAR, find "Actions"
   👉 Click "Actions" (it has a ▶️ play icon)
   👉 Then click "General" underneath it

4️⃣  Scroll DOWN to the bottom of the page
   👉 Look for the "Workflow permissions" section
   👉 It's near the bottom, after other settings

5️⃣  Select the radio button for:
   ✅ "Read and write permissions"
   
   (NOT "Read repository contents and packages permissions")

6️⃣  Check the checkbox:
   ✅ "Allow GitHub Actions to create and approve pull requests"

7️⃣  Click the "Save" button

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📍 VISUAL PATH:

Repository Homepage
    ↓
[Settings] tab (⚙️ gear icon)
    ↓
Left Sidebar → [Actions] (▶️ icon)
    ↓
Click [General]
    ↓
Scroll to bottom ↓↓↓
    ↓
"Workflow permissions" section
    ↓
○ Read repository contents... 
● Read and write permissions  ← SELECT THIS
    ↓
☑ Allow GitHub Actions to create and approve pull requests  ← CHECK THIS
    ↓
[Save] button

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🔍 CAN'T FIND IT?

• Make sure you're in the repository settings (not your profile settings)
• The "Settings" tab appears ONLY if you have admin access to the repo
• Look for the ⚙️ gear icon in the tabs under the repository name
• "Actions" is in the LEFT sidebar (not the main content area)
• "Workflow permissions" is at the BOTTOM of the General page

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📚 OFFICIAL DOCUMENTATION:

https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/enabling-features-for-your-repository/managing-github-actions-settings-for-a-repository#setting-the-permissions-of-the-github_token-for-your-repository

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

✅ AFTER ENABLING:

Once you've enabled these permissions, push your GitHub Actions workflows:

  git add .github/workflows/
  git commit -m "feat: add automatic secret sanitization"
  git push

Then check: https://github.com/nbiish/ainish-coder/actions

╚══════════════════════════════════════════════════════════════════╝

EOF
