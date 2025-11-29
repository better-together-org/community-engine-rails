# Safety and Reporting Tools

**Target Audience:** All community members  
**Document Type:** User Guide  
**Last Updated:** November 20, 2025

## Overview

Your safety is our priority. This guide explains the tools and processes available to help you stay safe on the platform, report concerning content or behavior, and protect your privacy.

## Personal Safety Tools

### Block Users

Blocking prevents another user from interacting with you on the platform.

**What happens when you block someone:**
- They cannot send you messages
- They cannot see your profile (if set to members-only)
- They cannot comment on your posts
- They cannot invite you to events
- They cannot create exchange agreements with you

**How to block a user:**
1. Visit the user's profile page
2. Click the "Block User" button
3. Confirm the action
4. The user is immediately blocked

**Managing blocks:**
- View your blocked users at `/person_blocks`
- Unblock users at any time
- Blocks are private - the blocked user is not notified

See implementation: `BetterTogether::PersonBlocksController`

### Privacy Settings

Control who can see your content and information.

**Privacy Levels:**
- **Public** - Visible to everyone, including non-members
- **Members Only** - Visible only to platform members
- **Community Members** - Visible only to community members
- **Private** - Visible only to you and authorized users

**What you can control:**
- Profile visibility
- Post and comment visibility
- Event participation visibility
- Community membership visibility

**How to adjust privacy:**
1. Go to Settings → Privacy (when available)
2. Set default privacy levels
3. Override per-content if needed

### Notification Controls

Manage what notifications you receive and how.

**Notification types:**
- Email notifications
- In-app notifications
- Real-time notifications (via Action Cable)

**Control options:**
- Turn categories on/off
- Adjust frequency (immediate, daily digest, weekly)
- Mute specific communities or conversations

**How to manage:**
1. Go to Settings → Notifications (when available)
2. Adjust preferences by category
3. Save changes

## Reporting System

### What You Can Report

Report content or behavior that violates [Community Guidelines](community_guidelines.md):

**Content Reports:**
- Posts and comments
- Messages (if harassing)
- Events (if inappropriate)
- Offers and requests (if fraudulent)
- Profiles (if impersonation or abuse)

**Behavior Reports:**
- Harassment or bullying
- Hate speech or discrimination
- Spam or scams
- Privacy violations
- Platform abuse

### How to Submit a Report

**Step-by-step reporting:**

1. **Find the report button**
   - Available on posts, comments, profiles, and other content
   - Look for flag icon or "Report" link

2. **Choose report category**
   - Harassment or abuse
   - Spam or scam
   - Inappropriate content
   - Privacy violation
   - Misinformation
   - Other (with description)

3. **Provide details**
   - Explain what guideline was violated
   - Add context if helpful
   - Include screenshots if relevant
   - Be specific and factual

4. **Submit report**
   - Review your report
   - Confirm submission
   - Receive confirmation message

**After you report:**
- You'll receive an acknowledgment
- Moderators will review the report
- You may receive updates on the outcome
- Reports are handled according to severity

### Report Status and Updates

Track your submitted reports:

**Report statuses:**
- **Pending** - Under review by moderators
- **In Review** - Being actively investigated
- **Resolved** - Action has been taken
- **Dismissed** - No violation found
- **Closed** - Report closed (with or without action)

**Where to check:**
- View your reports at `/reports` (if available)
- Receive email updates when status changes
- See resolution notes (if provided by moderators)

### What Happens to Reports

**Review process:**
1. **Initial triage** - Report is categorized and prioritized
2. **Investigation** - Moderators review the reported content and context
3. **Decision** - Determine if guidelines were violated
4. **Action** - Take appropriate action if needed
5. **Notification** - Inform reporter and (sometimes) reported user

**Possible outcomes:**
- **No action** - No violation found
- **Warning** - User receives a warning
- **Content removal** - Content is deleted
- **Temporary restriction** - User loses some privileges
- **Suspension** - User is temporarily banned
- **Permanent ban** - User is permanently removed

**Priority levels:**
- **Critical** - Immediate threats or illegal content (reviewed immediately)
- **High** - Serious violations like harassment (reviewed within 24 hours)
- **Normal** - Standard violations (reviewed within 3-5 days)
- **Low** - Minor issues (reviewed within 7 days)

### Reporting Anonymously

**Your privacy in reporting:**
- Reports are private by default
- Your identity is known to moderators
- The reported user does not automatically see who reported them
- However, context may make it obvious in some cases

**Tips for anonymous reporting:**
- Don't include identifying information in the report details
- If you're concerned about retaliation, mention this in your report
- Consider having another user submit the report if needed

## Safety Features by Content Type

### Profile Safety
- Block users from your profile page
- Set profile visibility to private
- Report profiles for impersonation or harassment

### Post and Comment Safety
- Report individual posts or comments
- Block users who repeatedly post concerning content
- Set default privacy on your own posts

### Event Safety
- Report inappropriate events
- Block users from inviting you to events
- Set RSVP visibility preferences

### Messaging Safety
- Block users to prevent messages
- Report harassing messages
- Delete conversations
- Control who can message you

### Exchange Safety (Joatu)
- Report fraudulent offers or requests
- Block users from exchange interactions
- Review agreements carefully before accepting
- Report agreement violations

## Moderator and Administrator Support

### Community Moderators

Each community may have designated moderators who:
- Review reports within their community
- Enforce community-specific guidelines
- Manage community membership
- Remove inappropriate content
- Issue warnings and restrictions

**How to contact:**
- Through the community's contact information
- Via the reporting system
- Through platform messaging

### Platform Organizers

Platform-level administrators handle:
- Platform-wide guideline enforcement
- Cross-community issues
- Appeals of moderator decisions
- Account-level actions (suspensions, bans)
- Policy violations

**How to contact:**
- Through the main support contact
- Via platform-wide report escalation
- Email to platform administrators

### Escalation Process

If you're unsatisfied with a moderation decision:

1. **Community level** - Contact community moderators first
2. **Platform level** - Escalate to platform administrators
3. **Appeal** - Submit a formal appeal with explanation
4. **Final review** - Platform organizers make final decision

See [Escalation Matrix](../shared/escalation_matrix.md) for details.

## Emergency Situations

### Immediate Threats

If you or someone else is in immediate danger:

**DO NOT rely solely on platform reporting**

1. **Call emergency services** - Contact local police or emergency number
2. **Report to platform** - Also submit a platform report marked as critical
3. **Document everything** - Save screenshots and evidence
4. **Seek support** - Contact trusted friends, family, or crisis services

### Crisis Resources

**Platform cannot replace professional help**

If you're experiencing:
- Suicidal thoughts
- Mental health crisis
- Domestic violence
- Child abuse
- Sexual assault

**Contact appropriate crisis services:**
- Suicide prevention hotlines
- Mental health crisis lines
- Domestic violence support
- Child protection services
- Sexual assault support centers

### Legal Issues

For illegal content or criminal behavior:

1. **Report to platform** - We'll preserve evidence
2. **Contact authorities** - File a police report
3. **Document thoroughly** - Save all evidence
4. **Seek legal advice** - Consult with an attorney if needed

## Best Practices for Safety

### Protect Your Information
- Don't share personal details publicly
- Use privacy settings appropriately
- Be cautious about what you post
- Review profile information regularly

### Recognize Warning Signs
- Requests for personal information
- Pressure to move conversations off-platform
- Unsolicited commercial messages
- Aggressive or threatening behavior
- Too-good-to-be-true offers

### Safe Exchanges (Joatu)
- Meet in public places for in-person exchanges
- Verify user ratings and reviews
- Trust your instincts
- Start with small exchanges to build trust
- Use platform messaging to maintain records

### Secure Your Account
- Use a strong, unique password
- Enable two-factor authentication (if available)
- Don't share your account credentials
- Log out on shared devices
- Review account activity regularly

## Reporting Bugs and Security Issues

### Security Vulnerabilities

If you discover a security vulnerability:

**DO NOT post publicly**

1. **Email security team** - Contact security@[platform-domain]
2. **Provide details** - Describe the vulnerability
3. **Allow time** - Give time to fix before disclosure
4. **Responsible disclosure** - Follow coordinated disclosure practices

See [SECURITY.md](../../SECURITY.md) for details.

### Platform Bugs

For non-security bugs:
- Use the platform's bug reporting system
- Provide steps to reproduce
- Include screenshots if helpful
- Note browser and device information

## Data and Privacy Concerns

### Data Access Requests
- Request access to your data
- Export your information
- Understand what data is collected

### Data Deletion
- Delete specific content
- Request account deletion
- Understand data retention policies

### Privacy Violations
- Report unauthorized data sharing
- Report privacy breaches
- Contact platform administrators

See [Privacy Policy](privacy_policy.md) for details.

## Frequently Asked Questions

**Q: Will the person I report know I reported them?**
A: The reported person is not automatically notified of who submitted the report, but context may make it obvious.

**Q: How long does it take to review a report?**
A: Critical reports are reviewed immediately; most others within 3-5 days depending on priority.

**Q: Can I block someone before reporting them?**
A: Yes, you can block and report. Blocking provides immediate protection while the report is reviewed.

**Q: What if I accidentally reported something?**
A: Contact moderators to explain the situation. Accidental reports can be marked as such.

**Q: Can I appeal a moderation decision?**
A: Yes, use the escalation process outlined above to appeal decisions you believe are incorrect.

**Q: Is my report anonymous?**
A: Reports are private but not fully anonymous - moderators see who submitted reports.

**Q: What if my report is ignored?**
A: Escalate to platform administrators if you believe a report was not properly handled.

## Related Documentation

- [Community Guidelines](community_guidelines.md)
- [Privacy Policy](privacy_policy.md)
- [User Management Guide](user_management_guide.md)
- [Escalation Matrix](../shared/escalation_matrix.md)
- [Democratic Principles](../shared/democratic_principles.md)

## Platform-Specific Information

> **Note:** Platform hosts should customize this section with:
> - Contact information for moderators and administrators
> - Platform-specific reporting procedures
> - Local emergency and crisis resource numbers
> - Security team contact information
> - Jurisdiction-specific legal resources

---

**Remember:** Your safety matters. Don't hesitate to use these tools and report concerning behavior. The platform community is stronger when everyone helps maintain a safe environment.
