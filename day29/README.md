# Day 29: Fine-Tuning Terraform Exam Prep with Practice Exams

## What I Did Today

Completed two more practice exams (Exams 3 and 4) for the Terraform Associate certification. Exam 3: 66% (failed), Exam 4: 70% (passed). Analyzed the four-exam trend showing alternating pass/fail results, identified persistent knowledge gaps, and performed targeted hands-on revision on weak areas.

## Exam Results Trend

| Exam | Score | Time | Result | Day |
|------|-------|------|--------|-----|
| Exam 1 | 56% (32/57) | 34 min | FAIL | 28 |
| Exam 2 | 70% (40/57) | 46 min | PASS | 28 |
| Exam 3 | 66% (38/57) | 39 min | FAIL | 29 |
| Exam 4 | 70% (40/57) | 33 min | PASS | 29 |

**Pattern**: Alternating fail/pass indicates inconsistency, not knowledge plateau. The real issue is exam-day anxiety from inconsistent performance.

## Readiness Assessment

**Rating: Nearly Ready**

- Two passes at exactly 70%
- Two fails just below threshold
- Knowledge exists but consistency needs improvement
- **Critical Gaps**: Terraform Fundamentals (38-43%), HCP Terraform (40-57%)

## Persistent Wrong Answer Topics

1. **required_providers vs provider block**
   - `required_providers`: Declaration (source, version) inside `terraform {}` block
   - `provider`: Configuration (region, credentials) at top level
   - Alias goes in provider block, not required_providers

2. **TF_LOG disable**
   - Correct: `unset TF_LOG`
   - Invalid: `TF_LOG=NONE` or `TF_LOG=OFF`

3. **State locking during terraform plan**
   - Plan acquires state lock (performs refresh)
   - Skip with: `-lock=false`

4. **HCP Terraform execution models**
   - CLI-driven: Local plan, remote execution
   - VCS-driven: Repo triggers automatic runs
   - API-driven: External orchestrator calls HCP API

5. **Version constraints**
   - `~> 3.0`: Allows minor/patch within major
   - `~> 3.0.0`: Allows only patch within minor

6. **Module output reference**
   - Correct: `module.<name>.<output>`
   - Wrong: `module.<name>.outputs.<output>` or `var.<name>.<output>`

7. **HCP Terraform drift detection**
   - Detects divergence, notifies (does NOT auto-remediate)

8. **terraform apply with empty config**
   - Destroys all resources (matches desired empty state)

## Hands-On Revision Performed

### State Commands
```bash
terraform state list
terraform state show <resource>
terraform state rm <resource>  # Remove from state without destroying
```

### Workspace Commands
```bash
terraform workspace new <name>
terraform workspace select <name>
terraform workspace list
terraform workspace delete <name>  # Must switch away first
```

### Provider Version Constraints
```hcl
# Only patch updates: ~> 6.21.0
# Minor + patch: ~> 6.0
# Any version >= 5.95.0: >= 5.95.0
```

## Today's Exam Analysis

- **for_each reference**: `aws_subnet.app["private"].id` (key in brackets)
- **Import syntax**: `to = resource` and `id = "..."` (not `from`)
- **plan vs refresh-only**: Plan shows changes; refresh-only updates state without proposing changes
- **lifecycle**: `ignore_changes` prevents reverting external changes; `precondition` validates before creation

## Final Study Priorities for Day 30

1. **Terraform Fundamentals** (43-38%): required_providers vs provider blocks, alias placement, installation paths
2. **HCP Terraform**: Three workflows, permissions (Read/Plan/Write/Admin), variable sets, projects, Explorer, change requests
3. **Version constraints**: `~> 3.0` vs `~> 3.0.0` (rightmost digit rule)
4. **Import blocks**: `to` and `id` syntax; does not generate .tf config
5. **Lifecycle meta-arguments**: ignore_changes, precondition, postcondition, check blocks

## Key Lessons

- Inconsistent scores indicate knowledge not yet solid
- Terraform Fundamentals is the biggest exam risk
- Import uses `to` and `id` only
- `unset TF_LOG` to disable logging
- Plan acquires state locks
- HCP drift detection notifies, doesn't auto-fix

## Next Steps

Day 30: Final exam simulation with focus on consistency and confidence in Fundamentals and HCP Terraform domains.

## Blog Post

For the full detailed analysis of all four exams, see [BLOG.md](BLOG.md).