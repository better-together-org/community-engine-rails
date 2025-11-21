# Messaging and Communication Guide

**Target Audience:** Community members  
**Document Type:** User Guide  
**Last Updated:** November 20, 2025

## Overview

The Better Together platform provides multiple communication tools to help community members connect, collaborate, and coordinate. This guide explains how to use messaging, conversations, and notifications effectively.

## Communication Systems

### Conversations and Messages

The platform uses a **conversations-based messaging system** where messages are organized into conversation threads.

**Key features:**
- **Private messaging** - One-on-one or group conversations
- **Real-time updates** - Messages appear immediately via Action Cable
- **Read receipts** - See when messages are read (optional)
- **Notifications** - Email and in-app alerts for new messages
- **Search** - Find conversations and messages
- **Privacy controls** - Control who can message you

### Notifications

Stay informed about platform activity through notifications.

**Notification types:**
- **Messages** - New conversation messages
- **Events** - Invitations, RSVPs, and updates
- **Communities** - New posts and announcements
- **Exchanges** - Offer responses and agreement updates
- **System** - Account and platform updates

**Delivery methods:**
- **In-app** - View in notification center
- **Email** - Receive via email
- **Real-time** - Instant browser notifications

## Starting Conversations

### Creating a New Conversation

**From a user's profile:**
1. Visit the user's profile page
2. Click "Send Message" or "Start Conversation"
3. Enter your message subject
4. Type your message
5. Click "Send"

**From conversations page:**
1. Go to `/conversations` or click Messages in navigation
2. Click "New Conversation" button
3. Select recipient(s)
4. Enter subject line
5. Type your message
6. Click "Send"

### Adding Participants

**Group conversations:**
- Add multiple recipients when creating a conversation
- Add participants to existing conversations
- Remove yourself from group conversations
- Participants can see full conversation history

**Privacy note:** All participants can see the full conversation, including messages sent before they joined.

## Managing Conversations

### Conversation List

View all your conversations in one place.

**Conversation states:**
- **Unread** - Contains unread messages (highlighted)
- **Active** - Recently updated conversations
- **Archived** - Older or completed conversations

**Sorting options:**
- By most recent activity
- By unread status
- By participant names
- By date created

### Reading Messages

**In a conversation:**
- Messages appear in chronological order
- Your messages appear on the right
- Others' messages appear on the left
- Timestamps show when messages were sent
- Read receipts show when messages were read (if enabled)

**Real-time updates:**
- New messages appear automatically
- No need to refresh the page
- Typing indicators show when others are composing
- Presence indicators show who's online (if enabled)

### Sending Messages

**Compose a message:**
1. Type in the message compose field
2. Use formatting if available (Markdown, rich text)
3. Add attachments if supported
4. Press Enter or click "Send"

**Message features:**
- **Text formatting** - Bold, italic, links
- **Mentions** - @username to notify specific users
- **Attachments** - Share files, images, documents
- **Emoji** - Express yourself with emoji reactions
- **Edit** - Edit recent messages (if enabled)
- **Delete** - Remove messages you sent

### Organizing Conversations

**Management actions:**
- **Archive** - Move inactive conversations out of main list
- **Delete** - Permanently remove conversations
- **Mute** - Stop notifications for specific conversations
- **Star** - Mark important conversations
- **Search** - Find specific conversations or messages

## Privacy and Safety

### Who Can Message You

Control who can start conversations with you:

**Settings options:**
- **Everyone** - Any platform member can message you
- **Communities** - Only members of your communities
- **Connections** - Only users you've interacted with
- **No one** - Disable incoming messages

**How to adjust:**
1. Go to Settings → Privacy
2. Find "Message Privacy" section
3. Select your preference
4. Save changes

### Blocking Users

Prevent specific users from messaging you:

**What blocking does:**
- Blocked users cannot send you messages
- Existing conversations are hidden
- You won't see their messages in group conversations
- They won't know they're blocked

**How to block:**
1. Visit user's profile or conversation
2. Click "Block User"
3. Confirm the action

See [Safety and Reporting Tools](safety_reporting.md) for more about blocking.

### Reporting Messages

Report inappropriate messages or conversations:

**What to report:**
- Harassment or bullying
- Spam or scams
- Inappropriate content
- Privacy violations
- Threatening behavior

**How to report:**
1. Click report button in conversation or message
2. Select violation category
3. Provide context
4. Submit report

See [Safety and Reporting Tools](safety_reporting.md) for the full reporting process.

## Notification Management

### Configuring Notifications

Control how you're notified about messages:

**Global settings:**
1. Go to Settings → Notifications
2. Adjust message notification preferences:
   - Email notifications (on/off)
   - In-app notifications (on/off)
   - Real-time notifications (on/off)
3. Set notification frequency:
   - Immediate (default)
   - Daily digest
   - Weekly summary
4. Save preferences

**Per-conversation settings:**
- Mute specific conversations
- Priority notifications for important conversations
- Override global settings per conversation

### Viewing Notifications

**Notification center:**
- Click bell icon in navigation
- See all recent notifications
- Mark as read/unread
- Clear notifications
- Go directly to referenced content

**Email notifications:**
- Receive formatted email alerts
- Include message preview
- Quick reply from email (if supported)
- Unsubscribe from specific notification types

## Advanced Features

### Search and Filter

**Search conversations:**
- Search by participant name
- Search by message content
- Search by date range
- Filter by read/unread status
- Filter by conversation type

**Search tips:**
- Use quotes for exact phrases
- Combine search terms
- Use date filters to narrow results
- Save frequent searches

### Message Drafts

**Auto-save drafts:**
- Messages are saved as you type
- Resume drafts from any device
- Drafts expire after 30 days
- Delete drafts you no longer need

### Conversation Settings

**Per-conversation options:**
- Rename conversation
- Add/remove participants (group)
- Set conversation as priority
- Archive when complete
- Export conversation history
- Delete conversation

## Email Integration

### Email Notifications

Receive message notifications via email:

**Email contents:**
- Sender name and message preview
- Link to view full conversation
- Quick action buttons (if supported)
- Unsubscribe link

**Customization:**
- Choose which notifications to receive
- Set notification frequency
- Customize email templates (platform organizers)

### Email Replies

Some platforms support replying to messages via email:

**If enabled:**
- Reply directly to notification emails
- Your reply is added to the conversation
- Attachments are included
- Maintains conversation thread

## Best Practices

### Effective Communication

**Message etiquette:**
- Be clear and concise
- Use appropriate tone
- Respect others' time
- Respond promptly when possible
- Use subject lines effectively

**Group conversations:**
- Add relevant participants only
- Stay on topic
- Use @mentions for specific people
- Consider creating new thread if topic changes
- Respect notification preferences

### Privacy Considerations

**What to avoid in messages:**
- Sharing sensitive personal information
- Financial information or passwords
- Content that violates guidelines
- Spam or unsolicited commercial messages

**Safe practices:**
- Verify user identity before sharing information
- Use caution with links from unknown users
- Report suspicious messages
- Keep professional boundaries
- Don't share conversation screenshots without consent

### Performance Tips

**Keep conversations manageable:**
- Archive old conversations
- Delete unnecessary messages
- Limit attachment sizes
- Clear old drafts
- Use search instead of scrolling

## Mobile and Accessibility

### Mobile Access

Messages are accessible on mobile devices:

**Mobile features:**
- Responsive design works on all screen sizes
- Touch-optimized interface
- Real-time notifications
- Offline message drafts (if supported)
- Mobile app (if available)

### Accessibility

The messaging system supports:

**Screen readers:**
- Semantic HTML for navigation
- ARIA labels for interactive elements
- Keyboard navigation support
- Focus management for new messages

**Customization:**
- Adjustable text size
- High contrast mode
- Reduced motion options
- Notification sound customization

## Integration with Other Features

### Event Coordination

Messages integrate with events:

**Event-related messaging:**
- Message event attendees
- Send updates to RSVPs
- Coordinate logistics
- Share event-related files

### Exchange Communication (Joatu)

Coordinate exchanges through messaging:

**Exchange conversations:**
- Discuss offer/request details
- Negotiate terms
- Coordinate meeting times
- Share delivery information
- Confirm completion

### Community Discussions

Messages complement community features:

**Private discussions:**
- Follow up on community posts
- Coordinate community projects
- Private community leadership discussions
- Member-to-member connections

## Troubleshooting

### Common Issues

**Messages not sending:**
- Check internet connection
- Verify recipient hasn't blocked you
- Ensure message meets size limits
- Try refreshing the page

**Not receiving notifications:**
- Check notification settings
- Verify email address is correct
- Check spam/junk folder
- Ensure browser permissions are enabled

**Can't find a conversation:**
- Check archived conversations
- Use search function
- Verify it wasn't deleted
- Check if you were removed from group

**Real-time updates not working:**
- Refresh the page
- Check browser WebSocket support
- Verify network allows WebSocket connections
- Clear browser cache

### Getting Help

If you continue to experience issues:

1. **Check documentation** - Review this guide
2. **Ask community** - Post in help forums
3. **Contact support** - Reach out to platform administrators
4. **Report bugs** - Submit bug reports for technical issues

## Future Features

Potential upcoming messaging features:

- **Voice messages** - Send audio recordings
- **Video messages** - Share short video clips
- **Message reactions** - React with emoji
- **Message threading** - Reply to specific messages
- **Advanced search** - More sophisticated search filters
- **Message scheduling** - Send messages at scheduled times
- **Translation** - Automatic message translation
- **Better mobile app** - Native mobile applications

> Note: Availability depends on platform configuration and development roadmap.

## Related Documentation

- [User Management Guide](user_management_guide.md)
- [Safety and Reporting Tools](safety_reporting.md)
- [Community Guidelines](community_guidelines.md)
- [Privacy Policy](privacy_policy.md)
- [Event Invitations and RSVP](events_invitations_and_rsvp.md)

## Platform-Specific Information

> **Note:** Platform hosts should customize this section with:
> - Specific messaging features enabled
> - Character limits and attachment size limits
> - Email notification templates
> - Mobile app availability
> - Real-time notification support
> - Integration with external messaging systems

---

**Remember:** Effective communication builds stronger communities. Use messaging tools respectfully and responsibly to foster positive connections.
