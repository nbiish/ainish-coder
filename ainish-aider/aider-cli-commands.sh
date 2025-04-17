#!/bin/bash

# Base configuration for autonomous background tasks
# Uses high-reasoning model and architect mode for complex operations
BASE_CONFIG="aider \\
    --model gemini/gemini-2.5-pro-exp-03-25:free \\
    --architect \\
    --editor-model deepseek/deepseek-chat-v3-0324:free \\
    --no-detect-urls \\
    --no-auto-commit \\
    --yes-always"

# Check if prompt and tag are provided
if [ -z "$1" ] || [ -z "$2" ]; then
  echo "Usage: $0 \"<prompt>\" --<tag>"
  echo "Available tags: --research, --docs, --security, --code, --verify, --progress"
  exit 1
fi

PROMPT="$1"
TAG="$2"

# Execute command based on tag
case "$TAG" in
  --research)
    echo "Running Research Task..."
    $BASE_CONFIG \
      --background \
      --message "Act as a research analyst. Synthesize the key findings, evidence, and implications related to the following topic. Provide a concise summary suitable for a technical team. Topic: $PROMPT"
    ;;
  --docs)
    echo "Running Documentation Generation Task..."
    $BASE_CONFIG \
      --background \
      --message "Act as a technical writer. Generate clear and concise documentation (e.g., explanation, usage guide, API reference) for the following subject, targeting an audience of developers. Subject: $PROMPT"
    ;;
  --security)
    echo "Running Security Analysis Task..."
    $BASE_CONFIG \
      --background \
      --message "Act as an expert security analyst. Review the provided context/code for potential security vulnerabilities (e.g., OWASP Top 10, injection flaws, insecure configurations, logic errors). Clearly identify any findings, explain the risks, and suggest mitigations. Focus area: $PROMPT"
    ;;
  --code)
    echo "Running Code Modification Task..."
    $BASE_CONFIG \
      --background \
      --message "Act as an expert software developer. Implement the following code generation or modification request, ensuring code is efficient, readable, and adheres to best practices. Request: $PROMPT"
    ;;
  --verify)
    echo "Running Verification Task..."
    $BASE_CONFIG \
      --background \
      --message "Act as a meticulous code reviewer. Verify the following code or implementation against the requirements or criteria specified. Identify any discrepancies, potential bugs, logical errors, or areas for improvement (e.g., clarity, performance). Verification request: $PROMPT"
    ;;
  --progress)
    echo "Running Progress-Tracked Task..."
    # Note: --show-progress is not a standard aider flag.
    # You might need a custom implementation or separate script to track progress.
    $BASE_CONFIG \
      --background \
      # --show-progress # This flag doesn't exist in aider options provided
      --message "Provide a status update or progress report based on the following request: $PROMPT"
    ;;
  *)
    echo "Error: Unknown tag '$TAG'"
    echo "Available tags: --research, --docs, --security, --code, --verify, --progress"
    exit 1
    ;;
esac

echo "Task initiated in background."
exit 0