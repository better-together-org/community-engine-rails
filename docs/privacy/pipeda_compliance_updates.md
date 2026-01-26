# PIPEDA Compliance Updates

**Date:** November 20, 2025  
**Purpose:** Document PIPEDA-specific updates to privacy policy and cookie consent agreement

## Overview

Added comprehensive PIPEDA (Personal Information Protection and Electronic Documents Act) compliance information to both the Privacy Policy and Cookie Consent Agreement to meet Canadian federal privacy law requirements.

## Files Updated

1. `app/views/better_together/static_pages/privacy.html.erb`
2. `app/views/better_together/static_pages/cookie_consent.html.erb`

## Privacy Policy Updates

### Added New Section: "Does Better Together comply with Canadian privacy law (PIPEDA)?"

**Location:** After CCPA section, before "Where can I access data about me?"

**Key Content Added:**

1. **PIPEDA Applicability Statement**
   - Explains why PIPEDA applies to Better Together
   - Notes operation in Newfoundland and Labrador
   - Mentions cross-border data handling

2. **PIPEDA's Ten Fair Information Principles**
   - Complete enumeration of all 10 principles with Better Together-specific explanations:
     1. Accountability (Privacy Officer designated)
     2. Identifying Purposes
     3. Consent (meaningful consent practices)
     4. Limiting Collection
     5. Limiting Use, Disclosure, and Retention
     6. Accuracy
     7. Safeguards
     8. Openness
     9. Individual Access
     10. Challenging Compliance
   - Each principle links to relevant sections of the privacy policy

3. **Your Rights Under PIPEDA**
   - Right to know why information is collected
   - Right to expect reasonable protection
   - Right to access personal information
   - Right to challenge accuracy
   - Right to withdraw consent
   - Right to file complaints

4. **Consent Under PIPEDA**
   - Express consent for sensitive information
   - Implied consent for less sensitive information
   - Withdrawal of consent procedures

5. **Data Breach Notification**
   - Reporting breaches to Privacy Commissioner of Canada
   - Notifying affected individuals
   - Maintaining breach records

6. **Cross-Border Data Transfers**
   - Reference to data storage section
   - Commitment to comparable protection levels

7. **Filing a Complaint Under PIPEDA**
   - Complete contact information for Office of the Privacy Commissioner of Canada
   - Address, phone numbers (toll-free and regular), TTY
   - Website link

### Updated Table of Contents
- Added link to new PIPEDA section

### Enhanced Contact Section

**Updated:** "How can I contact Better Together about privacy?"

**Changes:**
- Designated "Privacy Officer" title
- Added response timeline (30 days standard, with extension notification)
- Separated contact guidance by jurisdiction:
  - Canadian residents (PIPEDA)
  - European Union residents (GDPR)
  - California residents (CCPA)

## Cookie Consent Agreement Updates

### Added New Section: "Canadian and International Privacy Laws"

**Location:** After cookie management section, before updates section  
**Renumbered:** Previous section 8 (GDPR) became part of new section 8 (Privacy Laws)

**Key Content Added:**

1. **Canadian Privacy Law Compliance (PIPEDA) Subsection**
   - Explains Cookie Policy as part of PIPEDA compliance
   - Lists specific PIPEDA requirements for cookies:
     - Consent requirements (essential vs. optional)
     - Purpose identification
     - Access rights
     - Withdrawal procedures
     - Security safeguards

2. **Your Rights Under PIPEDA**
   - Right to know what cookies collect and why
   - Right to access cookie information
   - Right to withdraw consent for optional cookies
   - Right to file complaints

3. **Privacy Officer Contact Information**
   - Email: privacy@bettertogethersolutions.com

4. **Filing a Complaint Process**
   - Office of the Privacy Commissioner of Canada contact details
   - Website and phone numbers

5. **GDPR Rights Subsection**
   - Retained existing GDPR rights content
   - Reorganized under "Privacy Laws" section

### Updated Table of Contents
- Added "Canadian and International Privacy Laws" entry
- Renumbered subsequent sections (9-10 instead of 8-9)

## Legal Compliance Summary

### PIPEDA Requirements Met

✅ **Accountability** - Privacy Officer designated and contact provided  
✅ **Identifying Purposes** - Clear explanations throughout both documents  
✅ **Consent** - Describes express and implied consent mechanisms  
✅ **Limiting Collection** - States minimum necessary collection  
✅ **Limiting Use, Disclosure, and Retention** - Documented in privacy policy  
✅ **Accuracy** - User rights to correct information explained  
✅ **Safeguards** - Security measures described  
✅ **Openness** - Public privacy policies with detailed practices  
✅ **Individual Access** - Access procedures documented  
✅ **Challenging Compliance** - Complaint procedures with Privacy Commissioner contact

### Key Improvements

1. **Explicit PIPEDA Compliance Statement**: Clear declaration of compliance with Canadian law
2. **Privacy Officer Designation**: Accountable individual identified
3. **Detailed Consent Framework**: Express vs. implied consent explained
4. **Breach Notification Protocol**: PIPEDA breach reporting requirements documented
5. **Complaint Procedures**: Multi-jurisdictional complaint filing guidance
6. **Cross-Border Transfer Safeguards**: Commitment to comparable protection
7. **Response Timelines**: 30-day response commitment with extension notification

## Implementation Notes

### No Code Changes Required
These updates are documentation-only and require no backend changes to existing functionality.

### Existing Practices Already PIPEDA-Compliant
- Platform already obtains meaningful consent through registration
- Security safeguards (encryption, access controls) already in place
- User access and correction mechanisms already implemented
- Data retention practices already documented

### Next Steps (Recommended)

1. **Privacy Officer Designation**: Formally designate Privacy Officer role (likely existing contact)
2. **Breach Response Plan**: Document internal procedures for breach assessment and notification
3. **Staff Training**: Ensure team understands PIPEDA obligations
4. **Vendor Agreements**: Review subprocessor contracts for PIPEDA compliance
5. **Consent Audit**: Review all consent mechanisms to ensure PIPEDA compliance
6. **Annual Review**: Schedule annual PIPEDA compliance review

## Comparison with Other Jurisdictions

### PIPEDA (Canada)
- **Scope**: Commercial activities in provinces without substantially similar law
- **Key Feature**: 10 Fair Information Principles
- **Enforcement**: Office of the Privacy Commissioner of Canada
- **Breach Reporting**: Required for real risk of significant harm

### GDPR (EU)
- **Scope**: EU residents' data
- **Key Feature**: Data subject rights, accountability requirements
- **Enforcement**: Data Protection Authorities in each EU country
- **Breach Reporting**: Required within 72 hours for certain breaches

### CCPA (California)
- **Scope**: California residents' data for qualifying businesses
- **Key Feature**: Consumer rights (access, deletion, opt-out of sale)
- **Enforcement**: California Attorney General, private right of action
- **Breach Reporting**: Different requirements under California breach notification law

**Better Together's Approach**: Implement strongest protections across all three frameworks to ensure comprehensive compliance.

## Resources

- [PIPEDA Official Text](https://laws-lois.justice.gc.ca/eng/acts/P-8.6/)
- [Office of the Privacy Commissioner of Canada](https://www.priv.gc.ca)
- [PIPEDA Fair Information Principles](https://www.priv.gc.ca/en/privacy-topics/privacy-laws-in-canada/the-personal-information-protection-and-electronic-documents-act-pipeda/p_principle/)
- [PIPEDA Breach Reporting](https://www.priv.gc.ca/en/privacy-topics/business-privacy/safeguards-and-breaches/privacy-breaches/respond-to-a-privacy-breach-at-your-business/gd_pb_201810/)

## Review and Approval

**Technical Review**: ✅ Completed  
**Legal Review**: ⏳ Recommended before production deployment  
**Stakeholder Approval**: ⏳ Pending

---

**Document Version:** 1.0  
**Last Updated:** November 20, 2025  
**Next Review Date:** November 20, 2026 (annual review recommended)
