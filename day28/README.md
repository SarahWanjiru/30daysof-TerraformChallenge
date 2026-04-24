# Day 28: Terraform Associate Exam Preparation and Practice

## What I Did Today

Completed two full Terraform Associate practice exams to assess readiness for certification. The first attempt scored 56% (failed), while the second attempt scored 70% (passed). Analyzed the domain breakdowns, identified common mistakes, and recognized patterns in incorrect assumptions about Terraform behavior.

## Exam Details

- **Format**: 57 questions, 60 minutes, no references allowed
- **Pass Mark**: 70%
- **Attempt 1**: 56% (32/57 correct) - Failed in 34 minutes
- **Attempt 2**: 70% (40/57 correct) - Passed in 46 minutes

The key difference was taking more time to validate Terraform behavior rather than guessing based on familiarity.

## Domain Performance

| Domain | Attempt 1 | Attempt 2 | Notes |
|--------|-----------|-----------|-------|
| IaC Concepts | 60% | 100% | Stable |
| Core Workflow | 56% | 89% | Improved |
| State Management | 57% | 86% | Strong improvement |
| Configuration | 58% | 69% | Borderline |
| Modules | 67% | 63% | Weak |
| Terraform Fundamentals | 43% | 57% | Weak |
| Maintain Infrastructure | 50% | 50% | No change |
| HCP Terraform | 57% | 40% | Regressed - knowledge gap |

## Common Mistakes Identified

1. **Value Transformation**: Expressions and built-in functions transform values, not just variables
2. **Backend Credentials**: Use environment variables to keep secrets out of state
3. **Import Blocks**: Temporary constructs that can be removed after apply
4. **Destroy Commands**: `apply -destroy` executes, `plan -destroy` previews
5. **Resource Movement**: Use `removed` block for state separation
6. **Drift Handling**: Terraform enforces configuration → infrastructure
7. **HCP Explorer**: Cross-workspace resource discovery tool
8. **Execution Model**: CLI triggers remote execution on HCP Terraform

## Recurring Patterns

- **HCP Terraform gaps**: Conceptual understanding needs reinforcement
- **Execution confusion**: Mixing plan/apply/destroy behaviors
- **Direction model**: Configuration always drives infrastructure
- **Module boundaries**: Outputs required for cross-module access
- **Variable precedence**: CLI overrides all other sources

## Hands-On Validation

Practiced state operations, import workflows, and variable precedence to reinforce correct behaviors.

## Preparation Plan

**Day 29**: Deep dive into weak domains (HCP Terraform, Fundamentals, Maintenance)  
**Day 30**: Final 57-question simulation targeting 80%+ score

## Key Insight

The difference between failing and passing wasn't additional knowledge, but reducing incorrect assumptions about how Terraform operates under the hood.

## Resources Used

- Days 1-27 of this Terraform challenge
- Official Terraform Associate Study Guide
- Udemy Terraform Associate 004 practice questions



