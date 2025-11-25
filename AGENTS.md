# Code Guidelines

```
setup{type,cmd}:
  python,uv venv .venv
  tree,eza -aT -L2 --git

knowledge: knowledge-base/

docs{component}:
  Purpose,Inputs,Outputs,Examples,Edge cases,Errors

security{check}:
  input validation,auth,sql injection,xss,csrf,env vars,error handling,rate limiting

encryption{scope}:
  at rest,in transit,asymmetric (RSA/Ed25519)

crypto:
  mode: hybrid (classical + PQC)
  standards{algo,use}:
    ML-KEM,key encapsulation
    ML-DSA,signatures
    SLH-DSA,hash signatures

threats{type,mitigation}:
  exfiltration,access controls
  unauthorized,auth & monitoring

practices{rule}:
  validate inputs,role-based prompts,filter output,monitor patterns,maintain context
```
