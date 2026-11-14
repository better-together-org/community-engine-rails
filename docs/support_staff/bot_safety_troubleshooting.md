# Bot Safety Troubleshooting

**Target Audience:** Support staff and platform support responders  
**Document Type:** Troubleshooting guide  
**Last Updated:** April 2026

## Overview

Community Engine `0.11.0` adds built-in form protection for sign-up, membership requests, and safety reports. Most people will never notice it, but support staff may hear about it when a legitimate submission is rejected.

## Common support scenarios

### “My form submission failed”

Ask:

1. which form failed
2. whether the page was open for a long time before submission
3. whether the person refreshed and retried
4. whether they were using heavy autofill, browser automation, or unusual extensions

### “The page worked once and then stopped”

Likely causes:

- the signed proof was reused
- the page state went stale
- the person retried without refreshing after a failure

### “Our integration robot cannot read content”

Ask for:

- the robot identifier
- the target path or content type
- the intended scope level

Then confirm whether the robot has the required content scope.

## Safe first steps

- ask the person to refresh the page and try again
- avoid telling them to disable accessibility tools unless there is strong evidence a tool is causing the issue
- do not ask them to expose secrets, tokens, or private report contents in a support ticket

## Escalate when

- multiple people report the same form failing in the same time window
- robot access fails after a token rotation or configuration change
- a host app wants stronger protection than the built-in baseline
- support suspects active automated abuse or targeted harassment

## Related references

- [Submission Protection and Security Checks](../end_users/submission_protection_and_bot_checks.md)
- [Bot Safety Operations](../platform_organizers/bot_safety_operations.md)
- [Bot Safety Baseline](../security/bot_safety_baseline.md)

