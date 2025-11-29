Goal:
Generate a per-system assessment inventory by comparing the architectural systems identified in the most recent architecture analysis with the existing documentation in docs/assessments/.
The purpose is to determine which systems already have an assessment file and which still need one.

Context:
The architecture analysis (provided as context in this chat or nearby file) lists all major systems and subsystems of this Ruby on Rails application.
Partial system assessments already exist under docs/assessments/ (each system may have its own Markdown file such as content_management.md, community_management.md, etc.).
Each system’s assessment typically includes strengths, weaknesses, opportunities, and recommendations.

Instructions for Copilot

Extract System List

Parse the architecture analysis to obtain the complete list of top-level systems and significant subsystems.

Example: Platform Management, Community Management, Content Management, Messaging, Metrics, Financial Value Exchange, Agreements, Infrastructure & Integrations.

Scan the docs/assessments Directory

Enumerate all files in docs/assessments/.

Match each filename to the corresponding system or subsystem.

Treat differences in naming (underscores, hyphens, capitalization) as equivalent.

Create Assessment Inventory

Produce a structured table with columns:
| System | Assessment File Present (Y/N) | Filename (if exists) | Notes |

Mark systems missing an assessment as “No” and suggest a placeholder filename (e.g., docs/assessments/<system>_assessment.md).

Optionally include a short description from the architecture analysis for context.

Summarize Coverage and Next Actions

Provide counts and percentages of systems with/without assessments.

List recommended next steps for completing coverage (e.g., “Draft missing assessments for Messaging and Metrics systems”).

Deliverable:
Output the results as:

A Markdown table inventory (system → assessment status → file).

A short textual summary highlighting coverage gaps.

Optionally, a bullet list of next tasks to reach full documentation coverage.

Expected Format Example:

## System Assessment Inventory

| System | Assessment File Present | Filename | Notes |
|---------|--------------------------|-----------|-------|
| Platform Management | ✅ | docs/assessments/platform_management.md | Complete |
| Messaging | ❌ | docs/assessments/messaging_assessment.md | Generated new template |

**Coverage:** 5 / 8 systems (62%)  

### Next Actions  
- Fill out newly generated assessments for Messaging, Metrics, and Financial Exchange.  
- Review cross-system dependencies for updated architecture diagram alignment.  

End with a short summary of key gaps and recommended priorities for completing all assessments.