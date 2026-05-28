# 2026 Security & Compliance Research: NIST AI RMF, EU AI Act, CSF 2.0, AIVSS, ISO 42001

> Research date: 2026-05-03
> Status: Current as of research date. Web search API limits prevented live verification; primary sources cited for manual confirmation.

---

## Table of Contents

1. [NIST AI Risk Management Framework (AI RMF)](#1-nist-ai-risk-management-framework-ai-rmf)
2. [EU AI Act Compliance Requirements](#2-eu-ai-act-compliance-requirements)
3. [NIST CSF 2.0 for AI Systems](#3-nist-csf-20-for-ai-systems)
4. [AIVSS v0.8 (AI Vulnerability Scoring System)](#4-aivss-v08-ai-vulnerability-scoring-system)
5. [ISO/IEC 42001 (AI Management System)](#5-isoiec-42001-ai-management-system)
6. [Cross-Reference Matrix](#6-cross-reference-matrix)
7. [Prior Research (April 2026)](#7-prior-research-april-2026)

---

## 1. NIST AI Risk Management Framework (AI RMF)

### 1.1 AI RMF 1.0 Status

| Attribute | Detail |
|-----------|--------|
| **Full designation** | NIST AI 100-1 |
| **Published** | January 2023 |
| **Status (2026)** | Active; remains the authoritative base framework |
| **Mandate** | Voluntary (driven by Executive Order 14110, Oct 2023) |

**Core Functions (4 pillars):**

```
GOVERN  -->  MAP  -->  MEASURE  -->  MANAGE
   |           |          |            |
   v           v          v            v
 Policies    Context    Risk anal.   Action &
 accountability  identification  assessment   monitoring
```

| Function | Purpose | Key Subcategories |
|----------|---------|-------------------|
| **Govern** | Establish policies, roles, accountability | GOV 1-6: Risk culture, roles, supply chain, stakeholder engagement |
| **Map** | Contextualize AI risks | MAP 1-4: Use case, risk sources, metrics, harms/benefits |
| **Measure** | Assess and analyze risks | MEASURE 1-4: Evaluation, benchmarks, bias/fairness, data quality |
| **Manage** | Act on and monitor risks | MANAGE 1-4: Risk treatment, mitigation, monitoring, documentation |

### 1.2 AI RMF 1.1 / 2.0 Update Path

As of May 2026:

- **AI RMF 1.0** remains the operative version with supplemental profiles layered on top.
- **AI RMF 2.0** is anticipated but not yet released. Expected focus areas:
  - Native **agentic AI** risk coverage (autonomous tool use, multi-agent orchestration)
  - Deeper integration with **NIST CSF 2.0** six-function model
  - Updated **frontier AI** governance (models trained >10^25 FLOPs)
  - Alignment with **EU AI Act** Article 55 systemic-risk provisions
  - Enhanced **post-deployment monitoring** and incident reporting requirements

### 1.3 GenAI Profile (NIST AI 600-1)

| Attribute | Detail |
|-----------|--------|
| **Full designation** | NIST AI 600-1 |
| **Published** | July 2024 |
| **Purpose** | Cross-sectoral profile of GenAI-specific risks mapped to AI RMF functions |

**Key Risk Categories Addressed:**

1. **Hallucinations / Confabulations** -- Model generates plausible but false information
2. **Data Privacy & PII Leakage** -- Training data memorization and extraction attacks
3. **Intellectual Property Concerns** -- Copyright, trade secrets in training corpora
4. **Disinformation / Misinformation** -- Deepfakes, synthetic media at scale
5. **Bias Amplification** -- GenAI reproducing and scaling societal biases
6. **Human-AI Configuration** -- Over-reliance, automation bias, deskilling
7. **Prompt Injection** -- Adversarial manipulation of model behavior
8. **Supply Chain** -- Compromised pre-trained weights, poisoned datasets

**GenAI Profile Mapped to AI RMF Functions:**

| AI RMF Function | GenAI-Specific Actions |
|-----------------|----------------------|
| **Govern** | Establish GenAI use policies; define acceptable content generation boundaries; red-team mandates |
| **Map** | Identify hallucination risk zones; map data provenance; catalog IP exposure |
| **Measure** | Benchmark factuality rates; PII extraction testing; bias audits; toxicity scoring |
| **Manage** | Implement output filtering; RLHF guardrails; content provenance (C2PA); incident response |

**Trustworthiness Characteristics (per AI 600-1):**

- Safe, Secure, Resilient
- Explainable, Interpretable
- Privacy-Enhanced
- Fair with Harmful Bias Managed
- Valid, Reliable, Accountable, Transparent

### 1.4 NIST CAISI -- AI Safety Institute & Agent Standards

**NIST U.S. AI Safety Institute (AISI):**

- Established under Executive Order 14110 (October 2023) within NIST
- Mission: Develop standards, tools, and benchmarks for evaluating AI safety
- Focus areas for 2025-2026:
  - **Pre-deployment safety testing** of frontier AI models
  - **Agentic AI evaluation frameworks** -- testing autonomous tool use, planning, and reasoning capabilities
  - **Red-teaming guidance** for dual-use foundation models
  - Collaboration with **UK AISI** and international counterparts

**AI Agent Standards Development:**

- NIST is actively developing guidance specific to **agentic AI systems** (systems that plan, reason, and take autonomous actions)
- Key areas under development:
  - Agent autonomy level classification
  - Tool-use safety boundaries
  - Multi-agent interaction safety protocols
  - Human-in-the-loop (HITL) override requirements
  - Agent behavior monitoring and audit trail requirements

### 1.5 COSAiS -- Community Overlay for AI Safety

| Attribute | Detail |
|-----------|--------|
| **Full name** | Community Overlay for AI Safety (COSAiS) |
| **Type** | Community-driven supplementary framework |
| **Base** | Overlays NIST AI RMF 1.0 |
| **Focus** | Frontier AI safety, catastrophic/existential risk, responsible scaling |

**COSAiS extends the AI RMF with:**

- **Frontier AI model safety** -- Guidance for models at the frontier of capability
- **Catastrophic risk assessment** -- Frameworks for evaluating societal-scale harms
- **Responsible Scaling Policies (RSPs)** -- Threshold-based governance tied to capability evaluations
- **Safety cases** -- Structured arguments that a system is safe enough to deploy
- **Evaluation standards** -- Benchmarks for dangerous capabilities (e.g., CBRNE knowledge, cyber-offense capabilities)

**COSAiS-to-AI RMF Mapping:**

| AI RMF Function | COSAiS Overlay Addition |
|-----------------|------------------------|
| Govern | RSP governance; capability threshold policies; safety case review boards |
| Map | Catastrophic risk pathways; dual-use capability identification |
| Measure | Dangerous capability evaluations; evals for autonomy, persuasion, cyber-offense |
| Manage | Deployment hold decisions; scaled mitigations; incident response for frontier risks |

### 1.6 SP 800-218A -- Secure Development for Generative AI

| Attribute | Detail |
|-----------|--------|
| **Full designation** | NIST SP 800-218A |
| **Parent document** | SP 800-218 (Secure Software Development Framework -- SSDF) |
| **Published** | 2025 |
| **Purpose** | SSDF practices adapted for GenAI/LLM development |

**SP 800-218A maps SSDF practices to GenAI:**

| SSDF Practice Group | GenAI-Specific Adaptation |
|---------------------|--------------------------|
| **Prepare (PO)** | Secure training infrastructure; threat modeling for ML pipelines; GenAI-specific supply chain risk assessment |
| **Define (DE)** | Security requirements for training data curation; model behavior specifications; content safety policies |
| **Implement (IM)** | Secure training pipelines; data poisoning prevention; provenance tracking for weights/data; sandboxed evaluation |
| **Respond (RS)** | Incident response for model compromise; model rollback procedures; vulnerability disclosure for AI-specific flaws |

**Key Threats Addressed:**

- **Prompt injection** (direct and indirect)
- **Training data poisoning**
- **Model extraction / stealing**
- **Data poisoning via fine-tuning**
- **Supply chain compromise** (pre-trained weights, third-party datasets)
- **Output manipulation** and adversarial suffixes
- **Model inversion** and membership inference attacks

**Provenance & Transparency Requirements:**

- Model cards for all deployed models
- Data sheets documenting training data sources
- SBOM (Software Bill of Materials) for model dependencies
- AIBOM (AI Bill of Materials) for model components
- SLSA attestations for training pipeline integrity

---

## 2. EU AI Act Compliance Requirements

### 2.1 Enforcement Timeline

| Date | Milestone |
|------|-----------|
| August 1, 2024 | Regulation entered into force |
| February 2, 2025 | Prohibited AI practices apply (Art. 5) |
| August 2, 2025 | GPAI model obligations apply; penalties enforcement begins |
| August 2, 2026 | **High-risk AI system requirements fully applicable (Annex III)** |
| August 2, 2027 | High-risk AI in regulated products (Annex I) applies |
| August 2, 2028 | Obligations for certain high-risk systems (e.g., safety components) |

### 2.2 High-Risk AI System Requirements (Art. 6-49, enforceable Aug 2026)

**Classification (Annex III):** AI systems used in:

1. Biometric identification and categorization
2. Critical infrastructure management
3. Education and vocational training
4. Employment and worker management
5. Access to essential private/public services
6. Law enforcement
7. Migration, asylum, border control
8. Administration of justice and democratic processes

**Mandatory Technical Requirements:**

| Requirement | Article | Key Provisions |
|-------------|---------|----------------|
| **Risk Management System** | Art. 9 | Continuous iterative process; identify/analyze/mitigate risks throughout lifecycle |
| **Data Governance** | Art. 10 | High-quality training/validation/test data; bias examination; data provenance |
| **Technical Documentation** | Art. 11 & Annex IV | Comprehensive docs demonstrating compliance before market placement |
| **Record-Keeping / Logging** | Art. 12 | Automatic logging of events; traceability; logs retained for appropriate period |
| **Transparency** | Art. 13 | Clear information to users about capabilities, limitations, intended purpose |
| **Human Oversight** | Art. 14 | Designed for effective human oversight; override/stop capability |
| **Accuracy & Robustness** | Art. 15 | Appropriate accuracy levels; resilience against errors, adversarial attacks |
| **Quality Management System** | Art. 17 | Documented QMS covering all compliance aspects |
| **Conformity Assessment** | Art. 43 | Self-assessment or third-party (notified body) depending on system type |
| **Registration** | Art. 49 | Registration in EU AI database before market placement |

### 2.3 GPAI Model Obligations (Art. 51-56)

**All GPAI Model Providers (Art. 52):**

1. Maintain and update **technical documentation** (Annex XII)
2. Provide information to **downstream AI system providers**
3. Implement **copyright compliance policy**
4. Publish **training data summary** (sufficiently detailed)
5. Report **serious incidents** to EU AI Office

**Systemic-Risk GPAI Models (Art. 55):**

Trigger: Trained using >10^25 FLOPs OR designated by European Commission.

Additional obligations:

1. Perform **adversarial testing and red-teaming** (coordinated with AISI equivalents)
2. Conduct and document **risk assessment and mitigation**
3. Report **serious incidents** without undue delay
4. Ensure adequate **cybersecurity protection**
5. Track and report **energy consumption** and carbon footprint
6. Implement **evaluations** for dangerous capabilities

### 2.4 Technical Documentation Requirements (Annex IV / XII)

**High-Risk AI Systems (Annex IV):**

```
Technical documentation shall include:
|
+-- 1. General description
|   +-- System purpose, scope, intended users
|   +-- Architecture, model type, parameters
|   +-- Input/output specifications
|
+-- 2. Development process
|   +-- Design specifications, training methodology
|   +-- Data collection, preparation, labeling
|   +-- Feature engineering, model selection
|   +-- Training compute, hyperparameters
|
+-- 3. Risk management
|   +-- Risk assessment methodology
|   +-- Identified risks and mitigation measures
|   +-- Residual risks
|
+-- 4. Testing and validation
|   +-- Test datasets, metrics, results
|   +-- Performance benchmarks
|   +-- Bias and fairness evaluation
|   +-- Robustness and stress testing
|
+-- 5. Operational documentation
|   +-- Deployment instructions
|   +-- Human oversight measures
|   +-- Logging specifications
|   +-- Update/retraining procedures
```

**GPAI Models (Annex XII):**

- Model architecture, parameter count, compute used
- Training data characteristics and sources
- Evaluation results (benchmarks, known limitations)
- Risk mitigation measures applied during development
- Downstream provider integration guidance

### 2.5 Human Oversight Implementation (Art. 14)

**Required Capabilities:**

| Capability | Implementation Pattern |
|------------|----------------------|
| **Understanding** | User-facing documentation explaining model behavior, confidence levels, failure modes |
| **Interpretation** | Output explanations, feature importance, decision factors presented to operator |
| **Override/Reverse** | Manual override switch; ability to reverse automated decisions |
| **Stop/Interrupt** | "Kill switch" -- immediate system halt; graceful shutdown procedures |
| **Anomaly Detection** | Alerts when system operates outside design parameters or OOD (out-of-distribution) |
| **Automation Bias Mitigation** | Confidence scoring; mandatory review steps; dissented outcomes flagged |

**Code Pattern -- Human Oversight Implementation:**

```python
from enum import Enum
from dataclasses import dataclass, field
from datetime import datetime
from typing import Optional
import logging

class RiskLevel(Enum):
    LOW = "low"
    MEDIUM = "medium"
    HIGH = "high"
    CRITICAL = "critical"

class OversightAction(Enum):
    APPROVE = "approve"
    REJECT = "reject"
    DEFER = "defer"
    OVERRIDE = "override"
    STOP = "stop"

@dataclass
class AIDecision:
    """Represents an AI system output requiring human oversight."""
    decision_id: str
    model_id: str
    risk_level: RiskLevel
    confidence: float
    output: dict
    explanation: dict  # Feature importance, decision factors
    timestamp: datetime = field(default_factory=datetime.utcnow)
    requires_human_review: bool = False

@dataclass
class HumanOversightRecord:
    """Immutable audit trail for human oversight actions."""
    decision_id: str
    human_operator_id: str
    action: OversightAction
    rationale: str
    timestamp: datetime = field(default_factory=datetime.utcnow)

class HumanOversightManager:
    """
    Implements EU AI Act Article 14 -- Human Oversight.
    Ensures meaningful human control over high-risk AI outputs.
    """

    def __init__(self, risk_threshold: RiskLevel = RiskLevel.HIGH):
        self.risk_threshold = risk_threshold
        self._system_active = True
        self._audit_log: list[HumanOversightRecord] = []
        self._logger = logging.getLogger("ai_oversight")

    def evaluate_decision(self, decision: AIDecision) -> AIDecision:
        """
        Determine if a decision requires human review based on
        risk level and confidence thresholds.
        """
        if not self._system_active:
            raise SystemInactiveError("AI system has been stopped by human operator")

        # Auto-flag decisions above risk threshold or low confidence
        if (self._risk_numeric(decision.risk_level) >=
            self._risk_numeric(self.risk_threshold)):
            decision.requires_human_review = True
            self._logger.info(
                f"Decision {decision.decision_id} flagged for human review: "
                f"risk={decision.risk_level.value}, confidence={decision.confidence}"
            )

        if decision.confidence < 0.7:
            decision.requires_human_review = True

        return decision

    def human_override(
        self,
        decision_id: str,
        operator_id: str,
        action: OversightAction,
        rationale: str
    ) -> HumanOversightRecord:
        """Record a human oversight action with immutable audit trail."""
        record = HumanOversightRecord(
            decision_id=decision_id,
            human_operator_id=operator_id,
            action=action,
            rationale=rationale
        )
        self._audit_log.append(record)
        self._logger.info(
            f"Human override: {action.value} on {decision_id} "
            f"by {operator_id}"
        )
        return record

    def stop_system(self, operator_id: str, reason: str) -> None:
        """Emergency stop -- Article 14 'stop button' requirement."""
        self._system_active = False
        self._logger.critical(
            f"SYSTEM STOPPED by {operator_id}: {reason}"
        )

    def resume_system(self, operator_id: str, justification: str) -> None:
        """Resume after stop -- requires documented justification."""
        self._system_active = True
        self._logger.info(
            f"System resumed by {operator_id}: {justification}"
        )

    def get_audit_trail(self) -> list[HumanOversightRecord]:
        """Return immutable copy of audit trail."""
        return list(self._audit_log)

    @staticmethod
    def _risk_numeric(level: RiskLevel) -> int:
        return {
            RiskLevel.LOW: 1,
            RiskLevel.MEDIUM: 2,
            RiskLevel.HIGH: 3,
            RiskLevel.CRITICAL: 4,
        }[level]


class SystemInactiveError(Exception):
    pass
```

### 2.6 Transparency and Logging Requirements

**Transparency (Art. 13):**

```python
@dataclass
class TransparencyReport:
    """Implements EU AI Act Article 13 transparency requirements."""
    system_name: str
    system_version: str
    provider_name: str

    # Intended purpose
    intended_purpose: str
    scope_of_use: str
    target_users: str

    # Capabilities and limitations
    capabilities: list[str]
    known_limitations: list[str]
    failure_modes: list[str]

    # Performance metrics
    accuracy_metrics: dict
    fairness_metrics: dict
    robustness_metrics: dict

    # Model information
    model_type: str
    training_data_summary: str
    feature_descriptions: dict

    # Risk information
    residual_risks: list[str]
    recommended_human_oversight_measures: list[str]

    generated_at: datetime = field(default_factory=datetime.utcnow)
```

**Logging (Art. 12):**

```python
import json
from datetime import datetime
from typing import Any

class AIEventLogger:
    """
    Implements EU AI Act Article 12 -- Record-keeping and logging.
    Automatic logging of events for traceability throughout system lifetime.
    """

    def __init__(self, system_id: str, log_retention_days: int = 365):
        self.system_id = system_id
        self.log_retention_days = log_retention_days
        self._log_buffer: list[dict] = []

    def log_event(
        self,
        event_type: str,
        input_data: dict,
        output_data: dict,
        model_version: str,
        metadata: Optional[dict] = None
    ) -> str:
        """Log an AI system event with full traceability."""
        event_id = f"{self.system_id}-{datetime.utcnow().strftime('%Y%m%d%H%M%S%f')}"

        event = {
            "event_id": event_id,
            "system_id": self.system_id,
            "event_type": event_type,
            "timestamp": datetime.utcnow().isoformat(),
            "model_version": model_version,
            "input_hash": self._hash_data(input_data),
            "output_hash": self._hash_data(output_data),
            "metadata": metadata or {},
        }

        self._log_buffer.append(event)
        return event_id

    def log_anomaly(
        self,
        anomaly_type: str,
        severity: str,
        description: str,
        context: dict
    ) -> str:
        """Log detected anomalies for post-market monitoring."""
        return self.log_event(
            event_type=f"anomaly_{anomaly_type}",
            input_data=context,
            output_data={"severity": severity, "description": description},
            model_version="system",
            metadata={"anomaly": True}
        )

    @staticmethod
    def _hash_data(data: dict) -> str:
        import hashlib
        return hashlib.sha256(
            json.dumps(data, sort_keys=True).encode()
        ).hexdigest()[:16]
```

### 2.7 Penalty Structure

| Violation Type | Maximum Fine |
|---------------|--------------|
| Prohibited AI practices (Art. 5) | EUR 35 million OR 7% global annual turnover |
| High-risk AI system violations | EUR 15 million OR 3% global annual turnover |
| Incorrect/incomplete information | EUR 7.5 million OR 1% global annual turnover |
| GPAI model provider violations | EUR 15 million OR 3% global annual turnover |

---

## 3. NIST CSF 2.0 for AI Systems

### 3.1 Framework Overview

NIST CSF 2.0 (released February 2024) introduces a **six-function model**, adding **Govern** as the new top-level function.

```
                    GOVERN (new in 2.0)
                        |
    +-------+-------+---+---+----------+
    v       v       v       v          v
IDENTIFY  PROTECT  DETECT  RESPOND   RECOVER
```

### 3.2 Six Functions Applied to AI Systems

| Function | AI-Specific Implementation | Key Categories |
|----------|---------------------------|----------------|
| **Govern (GV)** | AI governance policies, risk appetite, AI ethics board, model inventory | GV.OC: Org. Context; GV.RM: Risk Mgmt; GV.RR: Roles; GV.POL: Policy; GV.ED: Oversight |
| **Identify (ID)** | AI asset inventory, data pipeline mapping, model risk classification | ID.AM: Asset Mgmt; ID.RA: Risk Assessment; ID.IM: Improvement |
| **Protect (PR)** | Model access control, training data security, prompt injection defenses | PR.AC: Access Control; PR.DS: Data Security; PR.PS: Processing; PR.IR: Platform |
| **Detect (DE)** | Anomaly detection in model behavior, adversarial input detection, drift monitoring | DE.CM: Continuous Monitoring; DE.AE: Adverse Events |
| **Respond (RS)** | AI incident response, model rollback, containment of adversarial attacks | RS.MA: Mgmt; RS.AN: Analysis; RS.CO: Communication; RS.MI: Mitigation |
| **Recover (RC)** | Model retraining, clean state restoration, post-incident improvement | RC.RP: Recovery Plan; RC.CO: Communication |

### 3.3 Implementation Examples by Function

**Govern (GV) -- AI-Specific:**

```python
# AI Governance Policy Configuration
AI_GOVERNANCE_CONFIG = {
    "risk_appetite": {
        "high_risk_ai_systems": "minimal",       # High-risk = minimal tolerance
        "genai_systems": "low",                    # GenAI = low tolerance
        "internal_tooling": "moderate",            # Internal tools = moderate
    },
    "approval_gates": {
        "model_deployment": "ai_ethics_board",
        "data_source_onboarding": "data_governance_team",
        "third_party_model": "security_review_board",
    },
    "documentation_requirements": [
        "model_card",           # For every deployed model
        "data_sheet",           # For every training dataset
        "impact_assessment",    # For high-risk use cases
        "risk_register_entry",  # In organizational risk register
    ],
    "review_cadence": {
        "high_risk": "quarterly",
        "medium_risk": "semi-annually",
        "low_risk": "annually",
    }
}
```

**Identify (ID) -- AI Asset Inventory:**

```python
@dataclass
class AIAssetInventory:
    """CSF 2.0 ID.AM -- AI-specific asset management."""
    model_id: str
    model_name: str
    model_version: str
    model_type: str               # e.g., "LLM", "classifier", "embedding"
    risk_classification: RiskLevel
    data_sources: list[str]       # Training data origins
    dependencies: list[str]       # Third-party models, APIs, libraries
    deployment_environment: str
    owner: str
    last_risk_assessment: datetime
    compliance_status: dict       # {"eu_ai_act": True, "nist_ai_rmf": True}
```

**Protect (PR) -- AI Input/Output Guards:**

```python
class AIInputGuard:
    """CSF 2.0 PR.DS -- Protect AI system from adversarial inputs."""

    def __init__(self, config: dict):
        self.max_input_length = config.get("max_input_length", 10000)
        self.blocked_patterns = config.get("blocked_patterns", [])
        self.rate_limiter = RateLimiter(
            max_requests=config.get("rate_limit", 100),
            window_seconds=60
        )

    def validate_input(self, user_input: str, context: dict) -> dict:
        """Validate input before passing to AI model."""
        checks = {
            "length_valid": len(user_input) <= self.max_input_length,
            "rate_limit_ok": self.rate_limiter.check(context.get("user_id")),
            "injection_scan": self._scan_for_injection(user_input),
            "pii_detected": self._detect_pii(user_input),
        }

        if not all(checks.values()):
            return {"allowed": False, "violations": checks}

        return {"allowed": True, "sanitized_input": user_input}

    @staticmethod
    def _scan_for_injection(text: str) -> bool:
        """Basic prompt injection detection."""
        # In production: use dedicated ML-based injection classifier
        suspicious_patterns = [
            "ignore previous instructions",
            "system:",
            "override safety",
            "jailbreak",
        ]
        text_lower = text.lower()
        return not any(p in text_lower for p in suspicious_patterns)
```

**Detect (DE) -- AI Behavior Monitoring:**

```python
class AIBehaviorMonitor:
    """CSF 2.0 DE.CM -- Continuous monitoring of AI system behavior."""

    def __init__(self, baseline_metrics: dict):
        self.baseline = baseline_metrics
        self.alert_threshold = 0.15  # 15% deviation from baseline

    def check_drift(self, current_metrics: dict) -> list[dict]:
        """Detect model/data drift by comparing against baseline."""
        alerts = []
        for metric, baseline_value in self.baseline.items():
            current_value = current_metrics.get(metric)
            if current_value is None:
                continue
            deviation = abs(current_value - baseline_value) / baseline_value
            if deviation > self.alert_threshold:
                alerts.append({
                    "metric": metric,
                    "baseline": baseline_value,
                    "current": current_value,
                    "deviation_pct": round(deviation * 100, 2),
                    "severity": "high" if deviation > 0.3 else "medium"
                })
        return alerts
```

**Respond (RS) -- AI Incident Response:**

```python
class AIIncidentResponder:
    """CSF 2.0 RS.MA/RS.MI -- AI-specific incident response."""

    def handle_incident(self, incident: dict) -> dict:
        """Respond to AI security incident."""
        severity = incident.get("severity", "medium")

        response = {
            "incident_id": incident["id"],
            "actions_taken": [],
            "status": "investigating"
        }

        # Immediate containment
        if severity in ("high", "critical"):
            response["actions_taken"].append("circuit_breaker_engaged")
            response["actions_taken"].append("traffic_rerouted_to_safe_model")
            response["status"] = "contained"

        # Analysis
        response["actions_taken"].append("forensic_log_capture")
        response["actions_taken"].append("input_pattern_analysis")

        # Recovery planning
        if incident.get("type") == "data_poisoning":
            response["actions_taken"].append("rollback_to_clean_checkpoint")
            response["actions_taken"].append("retraining_initiated")

        return response
```

---

## 4. AIVSS v0.8 (AI Vulnerability Scoring System)

### 4.1 Overview

| Attribute | Detail |
|-----------|--------|
| **Name** | AI Vulnerability Scoring System (AIVSS) |
| **Current version** | v0.8 (draft/pre-release) |
| **Base standard** | CVSS v4.0 (FIRST.org) |
| **Purpose** | Extend CVSS to cover AI/ML-specific and agentic AI vulnerabilities |
| **Status** | Under development; active community and standards body engagement |

### 4.2 How AIVSS Extends CVSS v4.0

**CVSS v4.0 Base Metrics (inherited):**

| Metric | What It Measures |
|--------|-----------------|
| Attack Vector (AV) | Network, Adjacent, Local, Physical |
| Attack Complexity (AC) | Low, High |
| Attack Requirements (AT) | None, Present |
| Privileges Required (PR) | None, Low, High |
| User Interaction (UI) | None, Passive, Active |
| Impact (VC/VI/VA) | Confidentiality/Integrity/Availability impact on vulnerable system |
| Subsequent Impact (SC/SI/SA) | Impact on subsequent systems |

**AIVSS Additional Metrics (AI-specific extensions):**

| Metric | Abbreviation | Values | What It Measures |
|--------|-------------|--------|-----------------|
| **Agent Autonomy Level** | AAL | supervised, semi-autonomous, fully-autonomous | Degree of independent action the AI agent can take |
| **Tool Access Scope** | TAS | none, read-only, read-write, execute, unrestricted | What external systems/tools/APIs the agent can invoke |
| **Model Manipulability** | MM | low, medium, high | Susceptibility to adversarial inputs, prompt injection, jailbreak |
| **Data Sensitivity Exposure** | DSE | none, limited, significant, critical | Risk of training/inference data leakage |
| **Impact Propagation** | IP | isolated, contained, cascading, systemic | How a vulnerability cascades through connected AI systems |
| **Recovery Complexity** | RC | simple, moderate, complex, infeasible | Difficulty of restoring safe state after exploitation |

### 4.3 Agentic Risk Amplification Factors

AIVSS introduces **Agentic Risk Amplification Factors (ARAF)** that modify the base score when the vulnerable component is an AI agent:

```
AIVSS Score = CVSS_v4_Base_Score x ARAF

Where ARAF = 1.0 + sum(
    agent_autonomy_level_factor,
    tool_access_scope_factor,
    multi_agent_interaction_factor,
    human_oversight_presence_factor,
    blast_radius_of_tool_access_factor
)
```

**ARAF Multiplier Table:**

| Factor | Low (+0.0) | Medium (+0.2) | High (+0.4) | Critical (+0.6) |
|--------|-----------|--------------|------------|----------------|
| Agent Autonomy | Supervised | Semi-autonomous | Autonomous | Fully autonomous, no HITL |
| Tool Scope | No tools | Read-only APIs | Read-write APIs | Code execution / shell |
| Multi-Agent | Single agent | 2-3 agents | 4-10 agents | 10+ agents / swarm |
| Human Oversight | Real-time HITL | Periodic review | Post-hoc audit | No oversight |
| Blast Radius | Single document | Single system | Multiple systems | Organization-wide / internet |

**Maximum ARAF**: 1.0 + (5 x 0.6) = 4.0x amplification

This means a CVSS base score of 7.0 could be amplified to **28.0** (capped at 10.0) for a fully autonomous, multi-agent system with code execution and no human oversight.

### 4.4 Scoring Methodology with Example

**Example Scenario**: Prompt injection vulnerability in an autonomous coding agent (similar to CVE-2025-53773 -- GitHub Copilot YOLO).

**Step 1: CVSS v4.0 Base Metrics**

| Metric | Value | Rationale |
|--------|-------|-----------|
| Attack Vector (AV) | Network | Exploitable via crafted PR description |
| Attack Complexity (AC) | Low | Simple text injection |
| Attack Requirements (AT) | None | No special conditions needed |
| Privileges Required (PR) | None | Any GitHub user can submit PR |
| User Interaction (UI) | Passive | Agent automatically processes PR content |
| Vulnerable System Impact | | |
| -- Confidentiality (VC) | High | Agent has repo read access |
| -- Integrity (VI) | High | Agent can modify/commit code |
| -- Availability (VA) | Low | Could delete files |
| Subsequent System Impact | | |
| -- Confidentiality (SC) | High | Access to CI/CD secrets |
| -- Integrity (SI) | High | Can push to production |
| -- Availability (SA) | Low | Could break build pipeline |

**CVSS v4.0 Base Score: ~8.5 (High)**

**Step 2: AIVSS Agentic Risk Amplification**

| ARAF Factor | Level | Multiplier | Rationale |
|-------------|-------|------------|-----------|
| Agent Autonomy | Critical | +0.6 | Fully autonomous (YOLO mode) |
| Tool Scope | Critical | +0.6 | Code execution with commit access |
| Multi-Agent | Medium | +0.2 | Interacts with CI/CD systems |
| Human Oversight | High | +0.4 | No HITL in YOLO mode |
| Blast Radius | High | +0.4 | Organization-wide; production access |

**ARAF = 1.0 + 0.6 + 0.6 + 0.2 + 0.4 + 0.4 = 3.2**

**Step 3: Final AIVSS Score**

```
AIVSS = min(CVSS_base x ARAF, 10.0)
AIVSS = min(8.5 x 3.2, 10.0)
AIVSS = min(27.2, 10.0)
AIVSS = 10.0 (CRITICAL)
```

**Step 4: AIVSS Vector String**

```
AIVSS:4.0/AV:N/AC:L/AT:N/PR:N/UI:P/VC:H/VI:H/VA:L/
       SC:H/SI:H/SA:L/AAL:C/TAS:C/MAI:M/HOP:H/BOR:H
```

Where additional metrics:
- `AAL:C` = Agent Autonomy Level: Critical
- `TAS:C` = Tool Access Scope: Critical
- `MAI:M` = Multi-Agent Interaction: Medium
- `HOP:H` = Human Oversight Presence: High (meaning HIGH absence of oversight)
- `BOR:H` = Blast Radius Of tool access: High

### 4.5 AIVSS vs CVSS Comparison

| Vulnerability Type | CVSS v4 Score | AIVSS Score | Delta |
|--------------------|--------------|-------------|-------|
| Classic SQL injection (non-AI) | 9.8 | 9.8 (no agentic factors) | 0.0 |
| Prompt injection (supervised agent) | 6.5 | 7.8 | +1.3 |
| Prompt injection (autonomous agent, YOLO) | 8.5 | 10.0 | +1.5 |
| Training data poisoning | 5.3 | 7.1 | +1.8 |
| Model extraction via API | 4.8 | 5.2 | +0.4 |
| Multi-agent cascade failure | 7.2 | 10.0 | +2.8 |

---

## 5. ISO/IEC 42001 (AI Management System)

### 5.1 Standard Overview

| Attribute | Detail |
|-----------|--------|
| **Full designation** | ISO/IEC 42001:2023 |
| **Title** | Information technology -- Artificial intelligence -- Management system |
| **Published** | December 2023 |
| **Type** | Requirements standard (certifiable) |
| **Scope** | Organizations of any size that develop, provide, or use AI systems |
| **Structure** | Annex SL high-level structure (compatible with ISO 9001, 27001, 14001) |

### 5.2 Key Requirements

**Clause Structure:**

| Clause | Title | Key Requirements |
|--------|-------|------------------|
| 4 | Context of the Organization | Understand internal/external AI issues; interested parties; AIMS scope |
| 5 | Leadership | Top management commitment; AI policy; organizational roles |
| 6 | Planning | AI risk assessment; AI system impact assessment; objectives & plans |
| 7 | Support | Resources; competence; awareness; communication; documented information |
| 8 | Operation | AI system development/deployment controls; operational planning; change management |
| 9 | Performance Evaluation | Monitoring, measurement, analysis; internal audit; management review |
| 10 | Improvement | Continual improvement; nonconformity and corrective action |

**Annex A Controls (key AI-specific controls):**

| Control Area | Description |
|-------------|-------------|
| **AI Policy** | Documented AI policy aligned with organizational strategy |
| **AI Risk Management** | Systematic identification and treatment of AI-related risks |
| **AI Impact Assessment** | Assessment of impacts on individuals, groups, and society |
| **AI System Lifecycle** | Controls throughout design, development, deployment, operation, decommission |
| **Data Management** | Quality, provenance, and governance of training and operational data |
| **AI System Transparency** | Documentation and disclosure appropriate to stakeholders |
| **AI System Accountability** | Clear roles, responsibilities, and decision-making authority |
| **AI System Bias** | Identification and mitigation of unfair bias |
| **AI System Robustness** | Resilience against adversarial attacks and edge cases |
| **AI System Security** | Protection against unauthorized access, modification, or extraction |
| **Third-party AI** | Due diligence for procured or outsourced AI components |
| **Human Oversight** | Appropriate level of human involvement in AI decision-making |

### 5.3 Relationship to Other Standards

```
                    ISO/IEC 42001 (AIMS)
                    /        |         \
                   /         |          \
    ISO/IEC 27001    ISO/IEC 23894    NIST AI RMF
    (InfoSec)         (AI Risk Guide)    (US Framework)
         |                  |                 |
         v                  v                 v
    ISO 27001 +       Risk assessment    Govern/Map/
    42001 integrated   guidance for       Measure/Manage
    audit possible     AI systems         four functions
                            |
                            v
                      EU AI Act
                    (Regulatory)
```

**Cross-Standard Mapping:**

| ISO/IEC 42001 | NIST AI RMF | EU AI Act | NIST CSF 2.0 |
|---------------|-------------|-----------|--------------|
| Clause 6 (Planning/Risk) | Govern + Map | Art. 9 (Risk Mgmt) | Govern (GV.RM) |
| Annex A (Data) | Measure | Art. 10 (Data Gov) | Protect (PR.DS) |
| Annex A (Transparency) | Govern | Art. 13 (Transparency) | Govern (GV.POL) |
| Annex A (Human Oversight) | Manage | Art. 14 (Human Oversight) | Govern (GV.OC) |
| Clause 8 (Operation) | Manage | Art. 16-27 (Provider/Deployer) | Protect (PR) |
| Clause 9 (Evaluation) | Measure | Art. 43 (Conformity) | Detect (DE) |
| Clause 10 (Improvement) | Manage | Art. 72 (Post-market) | Respond + Recover |
| Annex A (Security) | Govern/Manage | Art. 15 (Cybersecurity) | Protect (PR.AC) |

### 5.4 Certification Path

1. **Gap Assessment** -- Evaluate current AI governance against 42001 requirements
2. **AIMS Implementation** -- Establish policies, processes, and controls
3. **Internal Audit** -- Verify conformity before certification audit
4. **Stage 1 Audit** -- Documentation review by certification body
5. **Stage 2 Audit** -- On-site implementation verification
6. **Certification** -- ISO/IEC 42001 certificate issued (3-year cycle)
7. **Surveillance Audits** -- Annual surveillance; recertification at year 3

---

## 6. Cross-Reference Matrix

### Compliance Mapping for AI Systems (2026)

| Compliance Area | NIST AI RMF | EU AI Act | NIST CSF 2.0 | ISO 42001 | AIVSS |
|-----------------|-------------|-----------|--------------|-----------|-------|
| Risk Assessment | GOV, MAP | Art. 9 | GV.RM, ID.RA | Clause 6 | Scoring input |
| Data Governance | MEASURE | Art. 10 | PR.DS | Annex A | DSE metric |
| Documentation | MANAGE | Art. 11 | GV.POL | Clause 7 | N/A |
| Logging/Audit | MANAGE | Art. 12 | DE.CM | Clause 9 | IP metric |
| Transparency | GOVERN | Art. 13 | GV.OC | Annex A | N/A |
| Human Oversight | MANAGE | Art. 14 | GV.OC | Annex A | HOP metric |
| Security | GOVERN | Art. 15 | PR.AC | Annex A | CVSS base |
| Incident Response | MANAGE | Art. 72 | RS.MA | Clause 10 | RC metric |
| Supply Chain | GOV 4 | Art. 52 | ID.SC | Annex A | TAS metric |
| Agentic Risk | (GenAI Profile) | (Emerging) | (Emerging) | (Emerging) | ARAF factors |

### Priority Compliance Actions (May 2026)

| Priority | Action | Deadline | Framework |
|----------|--------|----------|-----------|
| 1 | **Prohibited practices audit** -- Ensure no AI systems fall under Art. 5 prohibitions | PASSED (Feb 2025) | EU AI Act |
| 2 | **GPAI model documentation** -- Prepare Annex XII tech docs | PASSED (Aug 2025) | EU AI Act |
| 3 | **High-risk AI system conformity** -- Full Art. 9-15 compliance for Annex III systems | August 2, 2026 | EU AI Act |
| 4 | **AI RMF alignment** -- Map organizational AI governance to AI RMF 1.0 + AI 600-1 | Ongoing | NIST AI RMF |
| 5 | **CSF 2.0 AI integration** -- Apply six functions to AI-specific cybersecurity | Ongoing | NIST CSF 2.0 |
| 6 | **ISO 42001 certification** -- Begin AIMS implementation for certification readiness | Ongoing | ISO 42001 |
| 7 | **AIVSS adoption** -- Integrate AI vulnerability scoring into security operations | Ongoing | AIVSS v0.8 |

---

## 7. Prior Research (April 2026)

*The following sections were part of the original April 2026 research and remain current.*

### 7.1 Cryptography Updates (PQC + Crypto-Agility)

**Algorithm Baselines:**
- **Symmetric (quantum-safe for long-term):** Prefer **AES-256-GCM** over AES-128; prefer **SHA-384/SHA-512** over SHA-256 for long-term confidentiality/integrity.
- **Asymmetric / KEM:** **Hybrid ML-KEM-768 + X25519** is the NIST-permitted interim default (FIPS 140-3 validatable; ANSSI/BSI recommend).
- **Signatures:** **ML-DSA-65** (lattice) as primary; **SLH-DSA** (hash-based) for crypto-diversity backup.
- **On Deck:** **HQC** (code-based KEM backup, finalizing 2026-2027) and **FN-DSA (Falcon)** for constrained systems.

**Crypto-Agility:**
- No hardcoded algorithms. All signing/encryption routes through an abstraction layer permitting algorithm swap without code rewrite.
- NIST sets **2035 hard cutoff** for quantum-vulnerable algorithms in federal/NSS systems.

### 7.2 Language-Specific Updates (2026)

| Lang | Additions to Current Standards |
|------|-------------------------------|
| **Bash** | `shellcheck` in CI; `trap` for cleanup; no `eval` on user input |
| **Python** | **3.13+**; `ruff` (linter+formatter); `ty` or `mypy`/`pyright`; `uv` for packaging; `bandit` for SAST |
| **TypeScript** | Zod/Valibot for all boundary input validation; no `any`; strict `tsconfig` |
| **Rust** | **2024 Edition** (Rust 1.85+); `cargo-audit` + `cargo-deny`; `cargo fuzz` at every attacker-input boundary |
| **Go** | `govulncheck` in CI; native `testing.F` fuzzing; secure error handling |
| **C++** | C++20/23; AddressSanitizer/UBSan in CI; avoid raw `new`/`delete` |

### 7.3 Supply Chain Hardening (2026 baseline)

- **SBOM** (CycloneDX or SPDX) generated per build.
- **SLSA Level 3+** attestations with Sigstore/cosign artifact signing.
- **Dependency gatekeepers:** Upstream proxies with malicious-package scanning.
- **Pinned versions + lockfiles** everywhere; automated renovation with review gates.
- **Reproducible builds** where feasible.

---

## Sources and References

- [NIST AI Risk Management Framework (AI 100-1)](https://www.nist.gov/artificial-intelligence)
- [NIST AI 600-1: Generative AI Profile](https://www.nist.gov/artificial-intelligence)
- [NIST AI Safety Institute (AISI)](https://www.nist.gov/aisi)
- [NIST CSF 2.0](https://www.nist.gov/cyberframework)
- [NIST SP 800-218A (Secure Software Development for GenAI)](https://csrc.nist.gov)
- [NIST SP 800-218 (SSDF)](https://csrc.nist.gov)
- [EU AI Act -- Regulation (EU) 2024/1689](https://eur-lex.europa.eu)
- [EU AI Office](https://digital-strategy.ec.europa.eu/en/policies/ai-office)
- [ISO/IEC 42001:2023](https://www.iso.org/standard/81230.html)
- [ISO/IEC 23894:2023 (AI Risk Management)](https://www.iso.org)
- [FIRST CVSS v4.0](https://www.first.org/cvss/v4.0/)
- [Executive Order 14110 (Oct 2023)](https://www.whitehouse.gov)
- [OWASP LLM Top 10 (2025)](https://owasp.org/www-project-top-10-for-large-language-model-applications/)
- [OWASP Agentic Security Top 10 (ASI 2026)](https://owasp.org)

---

*Note: Web search API limits prevented live verification of certain details. All source URLs should be visited directly for the most current information. This document reflects the state of standards and regulations as understood through training data and available references as of May 2026.*
