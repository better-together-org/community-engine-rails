# Conversations & Messaging System

This document explains the real-time messaging system, conversation management, notification delivery, and user interaction patterns within the Better Together Community Engine.

## Process Flow Diagram

```mermaid
flowchart TD

  %% Conversation Creation Flow
  subgraph CONV_CREATE[Conversation Creation]
    C1[User initiates conversation] --> C2[Select participants]
    C2 --> C3{Platform manager?}
    C3 -->|Yes| C4[Can message anyone]
    C3 -->|No| C5[Limited to platform managers]
    C4 --> C6[Create conversation]
    C5 --> C6
    C6 --> C7[Add creator as participant]
    C7 --> C8[Conversation created]
  end

  %% Message Flow
  subgraph MSG_FLOW[Message Creation & Delivery]
    M1[User sends message] --> M2[Validate conversation access]
    M2 --> M3[Create encrypted message]
    M3 --> M4[Set sender to current person]
    M4 --> M5[Save message with rich text content]
    M5 --> M6[Touch conversation timestamp]
    
    %% Real-time broadcasting
    M6 --> RT1[Broadcast via Action Cable]
    RT1 --> RT2[ConversationsChannel stream]
    RT2 --> RT3[Real-time DOM update]
    RT3 --> RT4[Auto-scroll to new message]
    RT4 --> RT5[Mark sender's message styling]
  end

  %% Participant Management
  subgraph PARTICIPANTS[Participant Management]
    P1[Add participants] --> P2{User authorized?}
    P2 -->|Yes| P3[Create ConversationParticipant]
    P2 -->|No| P4[Access denied]
    P3 --> P5[Participant joined]
    P6[Leave conversation] --> P7[Remove ConversationParticipant]
    P7 --> P8[Participant left]
  end

  %% Notification System
  subgraph NOTIFY[Notification Integration]
    N1[New message created] --> N2[NewMessageNotifier]
    N2 --> N3[Check notification preferences]
    N3 --> N4{Notify by email enabled?}
    N4 -->|Yes| N5[Schedule email notification]
    N4 -->|No| N6[Skip email notification]
    N5 --> N7[Email sent after delay]
    N2 --> N8[Action Cable notification]
    N8 --> N9[Real-time notification badge]
  end

  %% Privacy & Security
  subgraph SECURITY[Privacy & Security]
    S1[Message encryption] --> S2[Action Text encrypted storage]
    S3[Conversation access control] --> S4[Pundit policy authorization]
    S5[Participant validation] --> S6[Platform manager restrictions]
  end

  %% User Interface Integration  
  subgraph UI[User Interface]
    U1[Conversations index] --> U2[List user conversations]
    U2 --> U3[Show unread counts]
    U3 --> U4[Click conversation]
    U4 --> U5[Load conversation view]
    U5 --> U6[Display message history]
    U6 --> U7[Message composition form]
    U7 --> U8[Submit via Turbo]
    U8 --> U9[Real-time message append]
  end

  %% Flow connections
  C8 --> M1
  M6 --> N1
  M2 --> S3
  M3 --> S1
  C6 --> P1
  U8 --> M1
  N8 --> U3

  classDef creation fill:#e3f2fd
  classDef messaging fill:#f3e5f5  
  classDef participants fill:#e8f5e8
  classDef notifications fill:#fff3e0
  classDef security fill:#ffebee
  classDef ui fill:#f1f8e9

  class C1,C2,C3,C4,C5,C6,C7,C8 creation
  class M1,M2,M3,M4,M5,M6,RT1,RT2,RT3,RT4,RT5 messaging
  class P1,P2,P3,P4,P5,P6,P7,P8 participants
  class N1,N2,N3,N4,N5,N6,N7,N8,N9 notifications
  class S1,S2,S3,S4,S5,S6 security
  class U1,U2,U3,U4,U5,U6,U7,U8,U9 ui
```

**Diagram Files:**
- 📊 [Mermaid Source](../../diagrams/source/conversations_messaging_flow.mmd) - Editable source
- 🖼️ [PNG Export](../../diagrams/exports/png/conversations_messaging_flow.png) - High-resolution image
- 🎯 [SVG Export](../../diagrams/exports/svg/conversations_messaging_flow.svg) - Vector graphics

## What's Implemented

- **Conversations**: Multi-participant encrypted conversation threads with titles and metadata
- **Messages**: Rich-text encrypted messages with Action Text support and real-time delivery
- **Participants**: Flexible participant management with join/leave capabilities  
- **Real-time Messaging**: WebSocket-based instant message delivery via Action Cable
- **Notification System**: Comprehensive in-app and email notifications with deduplication
- **Authorization**: Policy-based access control with platform manager restrictions
- **Read Status Tracking**: Automatic notification marking when viewing conversations
- **Email Integration**: Delayed email notifications with user preferences and anti-spam
- **Internationalization**: Full i18n support across all messaging components

## What's Not Implemented Yet

- **Message Reactions**: Emoji reactions and message status indicators
- **File Attachments**: Direct file sharing within conversations (uses Action Text attachments)
- **Message Search**: Full-text search across conversation history
- **Conversation Archiving**: Archive/restore functionality for conversations
- **Message Threading**: Reply-to-message threading within conversations
- **Typing Indicators**: Real-time typing status display
- **Message Editing**: Edit/delete message capabilities after sending
- **Push Notifications**: Mobile push notifications for offline users
- **Conversation Templates**: Pre-defined message templates or auto-replies
- **Advanced Moderation**: Message filtering, reporting, and moderation tools

## Core Models & Associations

### Conversation Model
- **Purpose**: Groups messages and manages participants for multi-person discussions
- **Location**: `app/models/better_together/conversation.rb`
- **Key Features**:
  - Encrypted title storage with deterministic encryption
  - Creator tracking (belongs to Person)
  - Participant validation (at least one participant required)
  - Touch associations for last activity tracking

```ruby
class Conversation < ApplicationRecord
  encrypts :title, deterministic: true
  belongs_to :creator, class_name: 'BetterTogether::Person'
  has_many :messages, dependent: :destroy
  has_many :conversation_participants, dependent: :destroy
  has_many :participants, through: :conversation_participants, source: :person
end
```

### ConversationParticipant Model  
- **Purpose**: Join model connecting people to conversations
- **Location**: `app/models/better_together/conversation_participant.rb`
- **Key Features**:
  - Simple join table between conversations and people
  - Enables flexible participant management
  - Supports leave/join functionality

```ruby
class ConversationParticipant < ApplicationRecord
  belongs_to :conversation
  belongs_to :person
end
```

### Message Model
- **Purpose**: Individual messages within conversations with rich text support
- **Location**: `app/models/better_together/message.rb`
- **Key Features**:
  - Encrypted rich text content via Action Text
  - Real-time broadcasting after creation
  - Touch parent conversation for activity updates
  - Sender association to Person model

```ruby
class Message < ApplicationRecord
  belongs_to :conversation, touch: true
  belongs_to :sender, class_name: 'BetterTogether::Person'
  has_rich_text :content, encrypted: true
  validates :content, presence: true
  after_create_commit -> { broadcast_append_later_to conversation, target: 'conversation_messages' }
end
```

## Controllers & Authorization

### ConversationsController
- **Location**: `app/controllers/better_together/conversations_controller.rb`
- **Key Features**:
  - Full CRUD operations with Turbo Stream support
  - Participant management and conversation updates
  - Authorization via Pundit policies
  - Notification read marking integration
  - Real-time updates via Turbo Streams

#### Key Actions:
- `index`: List user's conversations with participants and last messages
- `show`: Display conversation with all messages and mark notifications as read
- `create`: Create new conversation and add creator as participant
- `update`: Update conversation details and participant list
- `leave_conversation`: Remove current user from conversation participants

### MessagesController
- **Location**: `app/controllers/better_together/messages_controller.rb`
- **Key Features**:
  - Message creation with sender assignment
  - Participant notification triggering
  - Real-time broadcasting via Action Cable
  - Turbo Stream response support

#### Message Creation Flow:
1. Validate conversation access
2. Create message with current person as sender
3. Trigger notifications to all participants except sender
4. Broadcast to conversation channel
5. Return Turbo Stream response for real-time UI update

## Real-time Communication

### Action Cable Channels

#### ConversationsChannel
- **Location**: `app/channels/better_together/conversations_channel.rb`
- **Purpose**: Real-time message delivery within conversations
- **Features**:
  - Stream messages to conversation participants
  - Automatic subscription management
  - Message broadcasting integration

#### NotificationsChannel  
- **Location**: `app/channels/better_together/notifications_channel.rb`
- **Purpose**: Real-time notification delivery system-wide
- **Features**:
  - Stream to individual persons
  - Unread count updates
  - Cross-system notification delivery

### JavaScript Integration
- **Conversation Messages Controller**: `app/javascript/controllers/better_together/conversation_messages_controller.js`
  - Auto-scroll to newest messages
  - Mark sender's own messages with styling
  - DOM mutation observation for real-time updates

## Notification System

### NewMessageNotifier
- **Location**: `app/notifiers/better_together/new_message_notifier.rb`
- **Purpose**: Notify conversation participants about new messages
- **Delivery Channels**:
  - **Action Cable**: Immediate real-time notification
  - **Email**: Delayed 15 minutes with deduplication logic

#### Key Features:
- **Email Deduplication**: One email per unread conversation per recipient
- **User Preferences**: Respects `notify_by_email` settings
- **Localized Content**: Message titles and bodies in recipient's preferred language
- **Unread Counting**: Includes current unread notification count in real-time delivery

#### Notification Logic:
```ruby
def should_send_email?
  unread_notifications = recipient.notifications.where(
    event_id: BetterTogether::NewMessageNotifier.where(params: { conversation_id: conversation.id }).select(:id),
    read_at: nil
  ).order(created_at: :desc)
  
  unread_notifications.any? && message.id == unread_notifications.last.event.record_id
end
```

### Email Integration
- **ConversationMailer**: `app/mailers/better_together/conversation_mailer.rb`
- **Template**: `app/views/better_together/conversation_mailer/new_message_notification.html.erb`
- **Features**:
  - Respects user privacy preferences for sender details
  - Includes direct links to conversations with message anchors
  - Platform branding and localized signatures
  - Conditional sender information based on `show_conversation_details` preference

## Authorization & Privacy

### Access Control
- **Platform Managers**: Can message anyone
- **Regular Users**: Can only message platform managers (configurable restriction)
- **Privacy Levels**: Conversation visibility based on participant membership
- **Policy Integration**: Full Pundit policy enforcement across all actions

### ConversationPolicy
Key authorization checks:
- `show?`: Participant membership or platform manager role
- `update?`: Creator or authorized participant
- `leave_conversation?`: Current participant with multiple participants remaining
- `create?`: Based on platform permissions and participant availability

## User Interface Components

### Conversation Layout
- **Sidebar Navigation**: Active conversation list with participant previews
- **Main Content Area**: Message thread with rich text rendering
- **Message Composer**: Trix editor with real-time submission
- **Participant Management**: Add/remove participants interface
- **Conversation Options**: Edit title, leave conversation, settings

### Message Display
- **Message Bubbles**: Styled differently for sender vs. recipients
- **Timestamp Display**: Localized time formatting
- **Sender Attribution**: Name and avatar display
- **Rich Content**: Full Action Text rendering with attachments
- **Real-time Updates**: Smooth DOM insertion without page refresh

### Responsive Design
- **Mobile Optimized**: Touch-friendly interface elements
- **Bootstrap Integration**: Consistent styling with platform theme
- **Accessibility**: ARIA labels, keyboard navigation, screen reader support

## Technical Implementation

### Encryption & Security
- **Message Encryption**: All message content encrypted at rest via Action Text
- **Title Encryption**: Conversation titles use deterministic encryption for searchability
- **CSRF Protection**: Full Rails CSRF token validation
- **Input Sanitization**: HTML content filtering via Action Text allow-lists

### Performance Optimization
- **Eager Loading**: Conversation queries include participants and messages with proper includes
- **Touch Associations**: Automatic timestamp updates for conversation activity
- **Query Optimization**: Efficient participant filtering and message ordering
- **Real-time Efficiency**: Targeted DOM updates via Turbo Streams

### Internationalization
- **Full i18n Coverage**: All user-facing strings translated across English, Spanish, French
- **Email Localization**: Notification emails rendered in recipient's preferred language
- **Time Zone Support**: Message timestamps displayed in user's local timezone
- **Locale-specific Formatting**: Date/time formatting respects cultural preferences

## Integration Points

### Person Model Integration
```ruby
# Person associations for messaging
has_many :conversation_participants, dependent: :destroy
has_many :conversations, through: :conversation_participants  
has_many :created_conversations, as: :creator, class_name: 'BetterTogether::Conversation'
has_many :messages, foreign_key: :sender_id, class_name: 'BetterTogether::Message'
```

### Notification Integration
- **NotificationReadable Concern**: Automatic read marking when viewing conversations
- **Unread Count Updates**: Real-time badge updates via Action Cable
- **Cross-system Integration**: Notifications work across all platform features

### Action Cable Integration
- **Turbo Stream Broadcasting**: Seamless real-time message delivery
- **Connection Management**: Automatic subscription handling
- **Error Recovery**: Graceful degradation when WebSocket unavailable

## Anti-Spam & Moderation

### Email Deduplication
- **One Email Per Conversation**: Prevents email flooding from active conversations
- **15-minute Delay**: Batches rapid messages into single email notifications
- **User Preference Respect**: Honors individual email notification settings
- **Read Status Integration**: Stops emails when notifications marked as read

### Content Filtering
- **Action Text Integration**: HTML content automatically sanitized
- **XSS Prevention**: Full Rails auto-escaping throughout templates
- **Input Validation**: Server-side validation on all message content
- **Policy Enforcement**: Authorization checks prevent unauthorized access

## Testing Strategy

### Model Testing
- **Factory Integration**: Comprehensive FactoryBot factories for all models
- **Association Testing**: Validates all model relationships and dependencies
- **Validation Testing**: Covers all business rules and constraints
- **Encryption Testing**: Verifies proper encryption/decryption behavior

### Controller Testing  
- **Authorization Testing**: Pundit policy enforcement verification
- **Response Format Testing**: HTML and Turbo Stream response validation
- **Real-time Feature Testing**: Action Cable integration testing
- **Error Handling Testing**: Graceful failure mode validation

### Integration Testing
- **Feature Specs**: Full user workflow testing with Capybara
- **Real-time Testing**: JavaScript-enabled conversation flow testing
- **Notification Testing**: End-to-end notification delivery verification
- **Cross-browser Testing**: Compatibility across different browsers and devices

## Configuration & Deployment

### Environment Variables
- **Action Cable**: WebSocket server configuration
- **Email Settings**: SMTP configuration for notification delivery
- **Encryption Keys**: Rails master key for encrypted content
- **Platform Settings**: Default messaging permissions and restrictions

### Database Considerations
- **Encryption Performance**: Deterministic encryption enables efficient querying
- **Index Strategy**: Optimized indexes for conversation and message queries
- **Migration Strategy**: Handles encrypted field additions and modifications
- **Backup Considerations**: Encrypted data backup and restoration procedures

## Development Guidelines

### Adding New Message Features
1. **Model Changes**: Add fields to Message model with proper encryption
2. **Controller Updates**: Update permitted parameters and authorization
3. **View Updates**: Add UI elements with proper internationalization
4. **Real-time Support**: Ensure Turbo Stream compatibility
5. **Notification Integration**: Add notification triggers if needed
6. **Testing**: Comprehensive test coverage for new functionality

### Extending Conversation Features
1. **Policy Updates**: Add new authorization rules to ConversationPolicy
2. **Association Changes**: Update model associations as needed
3. **UI Integration**: Add new interface elements to conversation layout
4. **Notification Updates**: Extend notification system for new features
5. **Documentation**: Update this document with new functionality

### Performance Considerations
- **Message History**: Consider pagination for conversations with many messages
- **Participant Limits**: Monitor performance with large participant counts
- **Real-time Scaling**: Plan for increased Action Cable connection loads
- **Search Integration**: Future full-text search implementation strategy

## Future Roadmap

### Short-term Enhancements
- **Message Reactions**: Emoji reactions with real-time updates
- **Typing Indicators**: Show when participants are composing messages
- **Message Search**: Full-text search across conversation history
- **File Attachments**: Direct file sharing within conversations

### Long-term Vision
- **Advanced Moderation**: AI-powered content filtering and moderation tools
- **Video/Audio**: Integration with WebRTC for video calling capabilities
- **Integration APIs**: Webhooks and APIs for third-party integrations
