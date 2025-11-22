#!/usr/bin/env python3
import os
import json
import sys
import requests
from typing import Dict, Any, List

# Configuration
AI_PROVIDER = os.getenv("AI_PROVIDER", "openai").lower() # openai, anthropic, gemini, openrouter
API_KEY = os.getenv("AI_API_KEY")
GITHUB_REPOSITORY = os.getenv("GITHUB_REPOSITORY")
GITHUB_REF = os.getenv("GITHUB_REF")

# Report Paths (Environment variables or defaults)
ZAP_REPORT_PATH = os.getenv("ZAP_REPORT_PATH", "zap-report.json")
SEMGREP_REPORT_PATH = os.getenv("SEMGREP_REPORT_PATH", "semgrep-results.json")

def load_zap_report(path: str) -> List[Dict[str, Any]]:
    """Load and summarize the ZAP JSON report."""
    if not os.path.exists(path):
        return []
    try:
        with open(path, 'r') as f:
            data = json.load(f)
        
        alerts = []
        site = data.get('site', [])
        if isinstance(site, list):
            for s in site:
                for alert in s.get('alerts', []):
                    risk = alert.get('riskdesc', '').split(' ')[0] # High, Medium, Low, Informational
                    if risk in ['High', 'Medium']:
                        alerts.append({
                            'tool': 'ZAP (DAST)',
                            'risk': risk,
                            'name': alert.get('alert', 'Unknown Alert'),
                            'description': alert.get('desc', '')[:200] + "...",
                            'file_or_url': alert.get('instances', [{}])[0].get('uri', 'Unknown URL')
                        })
        return alerts
    except Exception as e:
        print(f"Error loading ZAP report: {e}")
        return []

def load_semgrep_report(path: str) -> List[Dict[str, Any]]:
    """Load and summarize Semgrep JSON report."""
    if not os.path.exists(path):
        return []
    try:
        with open(path, 'r') as f:
            data = json.load(f)
        
        alerts = []
        for result in data.get('results', []):
            extra = result.get('extra', {})
            severity = extra.get('severity', 'UNKNOWN')
            if severity in ['ERROR', 'WARNING']:
                alerts.append({
                    'tool': 'Semgrep (SAST)',
                    'risk': severity,
                    'name': result.get('check_id', 'Unknown Check'),
                    'description': extra.get('message', '')[:300] + "...",
                    'file_or_url': f"{result.get('path')}:{result.get('start', {}).get('line')}"
                })
        return alerts
    except Exception as e:
        print(f"Error loading Semgrep report: {e}")
        return []

def generate_pr_content(alerts: List[Dict[str, Any]]) -> str:
    """Generate PR content using an LLM."""
    if not alerts:
        return "No High or Medium risk vulnerabilities found."

    prompt = f"""
    You are an expert Security Engineer. Analyze the following vulnerabilities found in a security scan.
    
    Vulnerabilities:
    {json.dumps(alerts, indent=2)}
    
    Task:
    1. Summarize the critical security risks.
    2. Provide specific, actionable code fixes or configuration changes to remediate these issues.
    3. Format the output as a GitHub Pull Request description in Markdown.
    4. Be concise, professional, and "expertly crafted".
    
    Output Format:
    # 🛡️ Security Remediation: Automated Analysis
    
    ## 🚨 Critical Findings
    (Summary of risks)
    
    ## 🛠️ Recommended Fixes
    (Step-by-step remediation)
    
    ## 📝 Implementation Notes
    (Any caveats)
    """

    if AI_PROVIDER == "openai":
        return call_openai(prompt)
    elif AI_PROVIDER == "anthropic":
        return call_anthropic(prompt)
    else:
        return call_openai(prompt) # Default

def call_openai(prompt: str) -> str:
    """Call OpenAI API."""
    if not API_KEY:
        return "Error: AI_API_KEY not set."
    
    headers = {
        "Authorization": f"Bearer {API_KEY}",
        "Content-Type": "application/json"
    }
    data = {
        "model": "gpt-4o",
        "messages": [
            {"role": "system", "content": "You are a senior security engineer."},
            {"role": "user", "content": prompt}
        ]
    }
    try:
        resp = requests.post("https://api.openai.com/v1/chat/completions", headers=headers, json=data)
        resp.raise_for_status()
        return resp.json()['choices'][0]['message']['content']
    except Exception as e:
        return f"Error calling OpenAI: {e}"

def call_anthropic(prompt: str) -> str:
    """Call Anthropic API."""
    if not API_KEY:
        return "Error: AI_API_KEY not set."

    headers = {
        "x-api-key": API_KEY,
        "anthropic-version": "2023-06-01",
        "content-type": "application/json"
    }
    data = {
        "model": "claude-3-opus-20240229",
        "max_tokens": 2000,
        "messages": [
             {"role": "user", "content": prompt}
        ]
    }
    try:
        resp = requests.post("https://api.anthropic.com/v1/messages", headers=headers, json=data)
        resp.raise_for_status()
        return resp.json()['content'][0]['text']
    except Exception as e:
        return f"Error calling Anthropic: {e}"

def main():
    all_alerts = []
    all_alerts.extend(load_zap_report(ZAP_REPORT_PATH))
    all_alerts.extend(load_semgrep_report(SEMGREP_REPORT_PATH))
    
    if not all_alerts:
        print("No significant alerts found. Skipping PR generation.")
        sys.exit(0)
        
    pr_body = generate_pr_content(all_alerts)
    
    with open("pr_body.md", "w") as f:
        f.write(pr_body)
    
    print("PR content generated successfully.")

if __name__ == "__main__":
    main()
