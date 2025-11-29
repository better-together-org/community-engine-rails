# Event Invitations Management (Organizers & Hosts)

This guide covers how organizers and event hosts invite people to events, manage invitation delivery, and track RSVP outcomes.

## Permissions & Access

- You must be the event creator, a platform manager, or a host representative for the event to manage invitations.
- Host representative status is determined by the `EventPolicy` (`event_host_member?`).

## Inviting Members vs External Emails

From the event page’s “Invitations” panel:

- Invite Member:
  - Use the “Invite Member” tab to select an existing person.
  - The selector uses `available_people` to show members not already invited and with an email.
  - Locale defaults from the person if set.
- Invite by Email:
  - Use the “Invite by Email” tab to invite someone via email address.
  - Set a preferred locale for the invitation.

## Delivery & Throttling

- Member invitations send a Noticed notification (in-app) and may send an email.
- Email invitations send via `EventInvitationsMailer` only.
- To prevent spam, repeated sends are throttled if the last send was within 15 minutes.
- You can resend an invitation from the invitations table when appropriate.

## Managing Invitations

- View all invitations in the “Invitations” section of the event page.
- Status lifecycle: `pending` → `accepted` or `declined`.
- Duplicate protection prevents inviting the same person/email again while pending/accepted.
- You can delete invitations that are no longer needed.

## Private Platform Access via Token

- Invitation links include a token that grants access to the specific event on private platforms.
- Invitees who aren’t signed in will be prompted to sign in or register; the token is saved to complete the response after authentication.

## RSVP Effects

- Accepting an event invitation automatically:
  - Ensures the invitee is a member of the host community (standard member role).
  - Sets RSVP to “Going” and creates a calendar entry for the invitee.

## Best Practices

- Use “Invite Member” when possible (richer delivery + better tracking).
- Stagger resends: avoid sending the same invite within 15 minutes.
- Monitor the “Attendees” section for Going/Interested counts to plan capacity.
- Include clear descriptions and schedule times so RSVP is available.

## Troubleshooting

- Duplicate errors: someone was already invited or accepted — review the invitations table first.
- No results in “Select Person”: the person may lack an email address; ask them to add one to their profile.
- Invitee can’t open link on private platform: confirm the token matches the correct event and is not expired.
