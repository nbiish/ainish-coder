# mini-swe-agent Integration for OSA Framework

**Version:** 1.0
**Date:** 2026-02-17
**Source:** https://github.com/SWE-agent/mini-swe-agent

---

## Overview

mini-swe-agent is a minimal AI software engineering agent developed by the Princeton/Stanford team behind SWE-bench. It's integrated into the OSA Framework as the **Priority 0** (highest priority) agent for software engineering tasks.

### Key Features

- **Minimal**: ~100 lines of Python for the agent class
- **Performant**: >74% on SWE-bench verified benchmark
- **Simple**: No tools other than bash — uses the shell to its full potential
- **Transparent**: Completely linear history — perfect for debugging and fine-tuning
- **Stable**: Stateless subprocess execution (no stateful shell sessions)
- **Compatible**: Works with all models via litellm

---

## Installation

### Option 1: Quick Try (Anonymous Virtual Environment)

```bash
pip install uv && uvx mini-swe-agent
# or
pip install pipx && pipx ensurepath && pipx run mini-swe-agent
```

### Option 2: Install in Current Environment

```bash
pip install mini-swe-agent
mini --help
```

### Option 3: Install from Source

```bash
git clone https://github.com/SWE-agent/mini-swe-agent.git
cd mini-swe-agent && pip install -e .
mini --help
```

---

## Usage

### CLI (Recommended)

```bash
# Basic usage
mini --task "Fix the bug in src/main.py"

# With specific model
mini --task "Implement user authentication" --model anthropic/claude-sonnet-4-5-20250929

# With config file
mini --task "Write tests for the API" --config .osa/mini/config/osa_coder.yaml
```

### Python Bindings

```python
from minisweagent.agents.default import DefaultAgent
from minisweagent.environments.local import LocalEnvironment
from minisweagent.models.litellm_model import LitellmModel
import yaml

# Load OSA configuration
with open('.osa/mini/config/osa_coder.yaml') as f:
    config = yaml.safe_load(f)

# Create agent
agent = DefaultAgent(
    LitellmModel(model_name="anthropic/claude-sonnet-4-5-20250929"),
    LocalEnvironment(),
    **config['agent']
)

# Run task
result = agent.run("Implement a REST API endpoint")
```

---

## OSA Role Configurations

| Config File | Role | Use Case |
|-------------|------|----------|
| `osa_default.yaml` | General | Default configuration |
| `osa_orchestrator.yaml` | Orchestrator | Planning, coordination, task decomposition |
| `osa_coder.yaml` | Coder | Implementation, refactoring, documentation |
| `osa_security.yaml` | Security | Vulnerability assessment, security audits |
| `osa_qa.yaml` | QA | Testing, code review, verification |

---

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `MSWEA_MODEL_NAME` | Default model name | `anthropic/claude-sonnet-4-5-20250929` |
| `LITELLM_MODEL_REGISTRY_PATH` | Custom model registry | None |
| `MSWEA_COST_TRACKING` | Cost tracking mode | `default` |

---

## Integration with OSA Framework

### Agent Registry Entry

```python
"mini": AgentConfig(
    name="mini-swe-agent",
    cli_command="mini",
    yolo_flag="--task",
    osa_roles={OSARole.ORCHESTRATOR, OSARole.CODER, OSARole.SECURITY, OSARole.QA},
    capabilities={
        AgentCapability.CODE_GENERATION,
        AgentCapability.TESTING,
        AgentCapability.SECURITY_AUDIT,
        AgentCapability.DOCUMENTATION,
        AgentCapability.PLANNING,
    },
    priority=0,  # Highest priority
),
```

### Usage in OSA Workflow

```bash
# As Orchestrator
mini --task "Plan the implementation of a user authentication system" \
     --config .osa/mini/config/osa_orchestrator.yaml

# As Coder
mini --task "Implement the login function" \
     --config .osa/mini/config/osa_coder.yaml

# As Security
mini --task "Audit the authentication code for vulnerabilities" \
     --config .osa/mini/config/osa_security.yaml

# As QA
mini --task "Write unit tests for the auth module" \
     --config .osa/mini/config/osa_qa.yaml
```

---

## Comparison with Other OSA Agents

| Agent | Priority | Best For | Performance |
|-------|----------|----------|-------------|
| **mini** | 0 | Software engineering, bug fixes, code implementation | >74% SWE-bench |
| **Gemini** | 1 | Orchestration, planning, merging | High |
| **Qwen** | 2 | Fast code generation | High |
| **OpenCode** | 3 | Schema validation, security | High |
| **Crush** | 4 | Security audit, code review | High |
| **Claude** | 5 | Architecture, QA | Very High |

---

## Why mini-swe-agent?

### Advantages

1. **Simplicity**: ~100 lines of core code, easy to understand and modify
2. **Performance**: Competitive with Claude Code on SWE-bench
3. **Flexibility**: Works with all models via litellm
4. **Transparency**: Linear history perfect for debugging
5. **Stability**: Stateless execution vs. stateful shell sessions
6. **Research-Backed**: Built by the team that created SWE-bench

### When to Use mini vs. Other Agents

**Use mini when:**
- You want a quick command line tool that works locally
- You need an agent with very simple control flow
- You want faster, simpler & more stable sandboxing
- You are doing FT or RL and don't want to overfit to a specific scaffold

**Use other agents when:**
- You need specific tool interfaces (swe-agent)
- You want to experiment with different history processors

---

## Resources

- **Documentation**: https://mini-swe-agent.com/latest/
- **GitHub**: https://github.com/SWE-agent/mini-swe-agent
- **SWE-bench**: https://swebench.com
- **Paper**: https://arxiv.org/abs/2405.15793

---

## Citation

```bibtex
@inproceedings{yang2024sweagent,
  title={{SWE}-agent: Agent-Computer Interfaces Enable Automated Software Engineering},
  author={John Yang and Carlos E Jimenez and Alexander Wettig and Kilian Lieret and Shunyu Yao and Karthik R Narasimhan and Ofir Press},
  booktitle={The Thirty-eighth Annual Conference on Neural Information Processing Systems},
  year={2024},
  url={https://arxiv.org/abs/2405.15793}
}
```

---

*Integrated into OSA Framework v2.0*