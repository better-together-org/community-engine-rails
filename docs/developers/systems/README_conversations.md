# Conversations and Messaging System Documentation

This directory contains comprehensive documentation for the Better Together Community Engine's conversations and messaging system.

## Documentation Files

### 1. conversations_messaging_system.md
Comprehensive technical documentation covering:
- **System Overview**: Architecture and feature summary
- **Models**: Conversation, ConversationParticipant, Message, and associations
- **Controllers**: ConversationsController and MessagesController with full CRUD operations
- **Real-time Features**: Action Cable channels for live messaging and notifications
- **Notification System**: NewMessageNotifier with email deduplication logic
- **Email Integration**: ConversationMailer with localized templates
- **Authorization**: Pundit policies and platform manager restrictions
- **Views & JavaScript**: Turbo Stream integration and Stimulus controllers
- **Internationalization**: Complete i18n support across all user-facing text

### 2. conversations_messaging_flow.mmd / conversations_messaging_flow.png
Visual process flow diagram illustrating:
- **Conversation Creation**: User flow with platform restrictions
- **Message Delivery**: From creation to real-time broadcasting
- **Notification System**: Both in-app and email notifications with deduplication
- **Read Status Management**: How messages are marked as read
- **Participant Management**: Adding/removing conversation participants
- **Authorization Flow**: Pundit policy enforcement
- **UI Updates**: Real-time Turbo Stream updates

## Key System Features

### Real-time Messaging
- **Action Cable Integration**: ConversationsChannel streams messages in real-time
- **Live UI Updates**: Messages appear instantly without page refreshes
- **Auto-scrolling**: New messages automatically scroll into view
- **Sender Styling**: Visual distinction for user's own messages

### Intelligent Notifications
- **Deduplication Logic**: Only sends one email per conversation until read
- **15-minute Delay**: Prevents email spam for rapid message exchanges
- **Multi-channel Delivery**: Browser notifications + email + in-app badges
- **Read Status Tracking**: Marks notifications as read when conversation is viewed

### Privacy & Security
- **Encrypted Storage**: Message content encrypted at rest using Active Record Encryption
- **Platform Restrictions**: Non-managers can only message platform managers
- **Authorization Policies**: Comprehensive Pundit policy enforcement
- **Participant Validation**: Strict controls on who can join conversations

### User Experience
- **Rich Text Support**: Full Trix editor integration for message composition
- **Responsive Design**: Bootstrap-based mobile-friendly interface
- **Accessibility**: WCAG AA compliance with proper ARIA labels and keyboard navigation
- **Internationalization**: Full i18n support in English, French, and Spanish

## Implementation Notes

The messaging system is built with Rails 7+ best practices:
- **Hotwire Integration**: Turbo Streams for seamless real-time updates
- **Stimulus Controllers**: JavaScript interactivity without jQuery
- **Background Jobs**: Sidekiq for email delivery and cleanup tasks
- **Database Optimization**: Proper indexing and N+1 query prevention
- **Test Coverage**: Comprehensive RSpec test suite with FactoryBot

## Getting Started

To understand the system:
1. Read `conversations_messaging_system.md` for technical details
2. Review `conversations_messaging_flow.png` for visual workflow
3. Explore the actual code in `app/models/better_together/conversation.rb` and related files
4. Check the test suite in `spec/models/better_together/` for usage examples

## Contributing

When modifying the messaging system:
- Update both documentation files when adding features
- Regenerate the PNG diagram using `bin/render_diagrams` 
- Follow the patterns established in the existing codebase
- Add comprehensive test coverage for all changes
- Ensure proper i18n support for any new user-facing text
