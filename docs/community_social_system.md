# Community & Social System

This document provides a comprehensive overview of the community and social interaction system within the Better Together Community Engine, including user safety mechanisms, content reporting, user blocking, privacy controls, and community moderation features.

## What's Implemented

### Core Social Infrastructure
- **Multi-tenant Platform Architecture**: Platform → Community → Person hierarchy with database tables
- **Person Profile System**: Basic person profiles with identifier, name, and privacy settings
- **Membership System**: Role-based community and platform memberships with database relationships
- **Basic Privacy Controls**: Public/private privacy enum implemented on models

### User Safety Features (Basic Implementation)
- **Person Blocking System**: Users can create blocks to prevent interactions (PersonBlock model)
- **Content Reporting System**: Basic reporting with reason field (Report model)  
- **Platform Manager Protection**: Cannot block users with platform management permissions
- **Policy-Based Authorization**: Pundit policies for blocking and reporting actions

### Authentication & Authorization  
- **Devise Integration**: User authentication with person profile linkage
- **Role-Based Access Control**: Permission system with cached role lookups
- **Policy Framework**: Pundit policies for authorization checks
- **Session Management**: Basic session security with CSRF protection

## What's Not Implemented Yet

### Essential Missing Features
- **Community Membership UI**: No interface for joining/leaving communities
- **Block Management Interface**: No UI for managing blocked users list
- **Report Review System**: No admin interface for reviewing reports
- **Moderation Tools**: No content removal or user suspension capabilities
- **Privacy Settings UI**: No interface for users to configure privacy settings

### Advanced Social Features (Not Started)
- **Friend/Follow System**: Social connections and relationship management
- **Activity Feeds**: User activity streams and social updates  
- **Social Media Integration**: External platform connections
- **Rich Notifications**: Comprehensive notification system with preferences
- **Social Groups**: Sub-communities and interest-based groups
- **Content Comments**: User commenting system on posts/pages
- **Profile Social Connections**: Detailed social relationship tracking

### Trust & Safety (Not Started)
- **Trust Score System**: Algorithmic user reputation tracking
- **Community Badges**: Achievement and recognition system
- **AI Content Moderation**: Automated inappropriate content detection
- **Appeals Process**: User appeals for moderation actions
- **Bulk Moderation**: Mass user and content management
- **Community Guidelines**: Platform-specific community rules

### Content & Communication (Limited)
- **Rich Content Creation**: Posts and pages exist but limited social features
- **Real-time Communication**: Conversations exist but basic implementation
- **Content Privacy**: Privacy controls exist but not fully integrated
- **Content Moderation**: No systematic content review process

## Core Models & Associations

### Platform Model
- **Purpose**: Multi-tenant platform hosting multiple communities
- **Location**: `app/models/better_together/platform.rb`
- **Key Features**:
  - Host platform designation with unique constraints
  - Invitation requirements and community privacy controls
  - Time zone and localization settings
  - URL-based routing and domain management
  - Custom CSS and branding configuration

```ruby
class Platform < ApplicationRecord
  include PlatformHost, Identifier, Joinable, Privacy
  
  has_community
  joinable joinable_type: 'platform', member_type: 'person'
  
  has_many :invitations, class_name: 'PlatformInvitation'
  store_attributes :settings do
    requires_invitation Boolean, default: false
  end
  
  validates :url, presence: true, uniqueness: true
  has_one_attached :profile_image, :cover_image
end
```

### Community Model
- **Purpose**: Individual communities within platforms
- **Location**: `app/models/better_together/community.rb`
- **Key Features**:
  - Creator ownership and community management
  - Host community designation for primary community
  - Event hosting with calendar integration
  - Rich media attachments (profile image, cover image, logo)
  - Multi-language content support with Action Text

```ruby
class Community < ApplicationRecord
  include Contactable, HostsEvents, Identifier, Joinable, Privacy
  
  belongs_to :creator, class_name: 'Person', optional: true
  has_many :calendars, dependent: :destroy
  joinable joinable_type: 'community', member_type: 'person'
  
  translates :name, :description
  has_one_attached :profile_image, :cover_image, :logo
  
  validates :name, presence: true
end
```

### Person Model
- **Purpose**: Individual user profiles and social identity
- **Location**: `app/models/better_together/person.rb`
- **Key Features**:
  - User account integration through identification system
  - Social connections (conversations, blocking, reporting)
  - Rich profile with contact details and preferences
  - Multi-community membership with role-based permissions
  - Notification preferences and privacy settings

```ruby
class Person < ApplicationRecord
  include Author, Contactable, FriendlySlug, Member, Privacy
  
  # Social connections
  has_many :conversation_participants, dependent: :destroy
  has_many :conversations, through: :conversation_participants
  
  # Safety mechanisms
  has_many :person_blocks, foreign_key: :blocker_id, dependent: :destroy
  has_many :blocked_people, through: :person_blocks, source: :blocked
  has_many :reports_made, foreign_key: :reporter_id, dependent: :destroy
  has_many :reports_received, as: :reportable, dependent: :destroy
  
  # Membership system
  member member_type: 'person', joinable_type: 'community'
  member member_type: 'person', joinable_type: 'platform'
  
  # User preferences
  store_attributes :preferences do
    locale String, default: I18n.default_locale.to_s
    time_zone String
  end
  
  store_attributes :notification_preferences do
    notify_by_email Boolean, default: true
    show_conversation_details Boolean, default: false
  end
end
```

### PersonBlock Model
- **Purpose**: User blocking system for preventing unwanted interactions
- **Location**: `app/models/better_together/person_block.rb`
- **Key Features**:
  - Bidirectional blocker/blocked relationship
  - Platform manager protection (cannot block platform managers)
  - Self-blocking prevention
  - Unique constraint to prevent duplicate blocks

```ruby
class PersonBlock < ApplicationRecord
  belongs_to :blocker, class_name: 'Person'
  belongs_to :blocked, class_name: 'Person'
  
  validates :blocked_id, uniqueness: { scope: :blocker_id }
  validate :not_self, :blocked_not_platform_manager
  
  private
  
  def blocked_not_platform_manager
    return unless blocked&.permitted_to?('manage_platform')
    errors.add(:blocked, I18n.t('errors.person_block.cannot_block_manager'))
  end
end
```

### Report Model  
- **Purpose**: Content and user reporting system for community safety
- **Location**: `app/models/better_together/report.rb`
- **Key Features**:
  - Polymorphic reportable association (any content type)
  - Reporter tracking and reason documentation
  - Integration with moderation workflows
  - Audit trail for safety investigations

```ruby
class Report < ApplicationRecord
  belongs_to :reporter, class_name: 'Person'
  belongs_to :reportable, polymorphic: true
  
  validates :reason, presence: true
end
```

### Membership Models
- **PersonCommunityMembership**: Joins people to communities with roles
- **PersonPlatformMembership**: Joins people to platforms with roles  
- **Key Features**:
  - Role-based permission assignment
  - Unique membership constraints
  - Membership lifecycle management
  - Platform and community scope isolation

## Controllers & Authorization

### Community Management
- **CommunitiesController**: Basic CRUD operations for community management
  - Community listing with privacy scope filtering
  - Creator-based ownership and editing permissions  
  - Basic form handling (no rich media upload interface yet)
  - Turbo Stream integration for form updates

### Person Blocking System  
- **PersonBlocksController**: Basic user blocking functionality
  - Block creation with Pundit policy authorization
  - Blocked user listing (index method)
  - Block removal (destroy method)
  - **Missing**: No UI implemented for block management

```ruby
class PersonBlocksController < ApplicationController
  def create
    @person_block = current_person.person_blocks.new(person_block_params)
    authorize @person_block
    
    if @person_block.save
      redirect_to blocks_path, notice: t('flash.person_block.blocked')
    else
      redirect_to blocks_path, alert: @person_block.errors.full_messages.to_sentence
    end
  end
end
```

### Content Reporting System
- **ReportsController**: Basic content and user reporting
  - Report creation with reason validation
  - Polymorphic reportable content support
  - Authorization preventing self-reporting
  - **Missing**: Admin review interface not implemented

### Membership Management
- **PersonCommunityMembershipsController**: Community membership CRUD
  - Basic membership creation and deletion
  - Turbo Stream integration for member list updates
  - **Missing**: Role assignment interface not implemented
  - **Missing**: Membership approval workflow not implemented

## Authorization & Privacy

### Policy Framework
All social interactions are governed by comprehensive Pundit policies:

**PersonBlockPolicy**: Controls user blocking permissions
- Only users can block other users (never themselves)
- Platform managers cannot be blocked
- Users can only manage their own blocks

**ReportPolicy**: Controls content reporting permissions  
- Authenticated users can report content/users
- Users cannot report themselves
- All reports require documented reasons

**CommunityPolicy**: Controls community access and management
- Public communities visible to all users
- Private communities require membership
- Creator permissions for community management

### Privacy Controls
The system implements granular privacy controls:

**Profile Privacy**: User-controlled visibility of personal information
**Content Privacy**: Public/private settings for all user-generated content
**Contact Privacy**: Granular controls for addresses, phone numbers, emails
**Platform Privacy**: Community-level visibility controls
**Activity Privacy**: User control over activity visibility and tracking

## User Interface Components

### Basic Community Features
- **Community Listing**: Basic community index page (implemented)
- **Community Profiles**: Basic community show pages (implemented)
- **Community Forms**: Create/edit community forms (implemented)

### Missing UI Components (Not Implemented)
- **Block Management Interface**: No UI for viewing/managing blocked users
- **Report Forms**: No contextual reporting forms for content and users  
- **Privacy Settings Dashboard**: No interface for privacy controls
- **Membership Management**: No UI for joining/leaving communities
- **Member Directories**: No community member listing interfaces
- **Profile Management**: Limited profile editing capabilities
- **Social Navigation**: No social relationship indicators or navigation

## Technical Implementation

### Database Schema
The community system uses a hierarchical multi-tenant architecture:

**Platform → Community → Person Structure**:
```sql
-- Core entities
better_together_platforms (host platform, settings, privacy)
better_together_communities (within platforms, creator-owned)  
better_together_people (cross-community profiles)

-- Safety mechanisms
better_together_person_blocks (blocker_id, blocked_id, timestamps)
better_together_reports (reporter_id, reportable polymorphic, reason)

-- Membership system  
better_together_person_community_memberships (member, joinable, role)
better_together_person_platform_memberships (member, joinable, role)
```

**Key Relationships**:
- Platforms can have multiple communities (1:many)
- People can be members of multiple communities and platforms (many:many through memberships)
- Blocking is bidirectional with unique constraints
- Reports are polymorphic, supporting any content type

### Privacy Implementation
Privacy controls are implemented through the `Privacy` concern:
- **Enum-based Privacy**: `public` and `private` privacy levels
- **Scoped Queries**: Privacy-filtered database queries
- **Policy Integration**: Privacy-aware authorization policies
- **UI Controls**: Form helpers for privacy selection

### Caching Strategy
The system implements comprehensive caching for performance:
- **Permission Caching**: 12-hour cache for role and permission checks
- **Member Associations**: Cached membership lookups and role associations
- **Privacy Scopes**: Cached privacy-filtered query results
- **Profile Information**: Cached profile data with cache invalidation

## Integration Points

### User Authentication
- **Devise Integration**: Full integration with Devise authentication system
- **Multi-factor Authentication**: Support for enhanced authentication methods
- **Session Management**: Secure session handling with CSRF protection
- **Account Recovery**: Secure password reset and account recovery workflows

### Notification System
- **Noticed Integration**: Rich notification system for social interactions
- **Email Notifications**: Configurable email notification preferences
- **Real-time Updates**: Action Cable integration for live updates
- **Notification Privacy**: User-controlled notification visibility

### Content Management
- **Rich Text Support**: Action Text integration for formatted content
- **File Attachments**: Active Storage integration for media uploads
- **Content Versioning**: Version tracking for content changes
- **Content Privacy**: Granular content visibility controls

### External Services
- **Email Delivery**: Action Mailer with SMTP/SendGrid integration
- **File Storage**: S3/MinIO integration for scalable file storage
- **Background Jobs**: Sidekiq integration for async processing
- **Analytics**: Optional analytics integration for community insights

## Anti-Spam & Content Moderation

### Basic Protection (Limited Implementation)
- **Rate Limiting**: Rack::Attack protection against abuse (basic configuration)
- **Input Validation**: Rails built-in input sanitization and validation
- **Policy Authorization**: Pundit-based authorization checks
- **Database Constraints**: Unique constraints preventing duplicate blocks/reports

### Missing Moderation Features (Not Implemented)
- **Spam Detection**: No Akismet or automated spam filtering
- **Content Review Tools**: No administrative interfaces for reviewing reports
- **User Suspension**: No tools for blocking or suspending user accounts
- **Content Removal**: No systematic content moderation or removal tools
- **Moderation Queue**: No workflow for processing reported content
- **Appeal Process**: No system for handling user appeals

### Basic Trust Controls
- **Role-Based Permissions**: Community-specific role and permission management (basic)
- **Platform Manager Protection**: Cannot block users with elevated permissions
- **Self-Action Prevention**: Cannot block yourself or report your own content

## Testing Strategy

### Model Testing
```ruby
RSpec.describe PersonBlock do
  it 'prevents self-blocking'
  it 'prevents blocking platform managers'
  it 'enforces unique blocker-blocked pairs'
  it 'allows valid blocking relationships'
end

RSpec.describe Community do
  it 'validates required attributes'
  it 'handles privacy settings correctly'
  it 'manages member relationships'
  it 'integrates with authorization policies'
end
```

### Controller Testing  
```ruby
RSpec.describe PersonBlocksController do
  context 'when creating blocks' do
    it 'authorizes block creation'
    it 'prevents unauthorized blocking'
    it 'handles blocking errors gracefully'
  end
end
```

### Integration Testing
```ruby
RSpec.describe 'Community Management' do
  it 'allows community creation'
  it 'enforces privacy controls'
  it 'manages memberships correctly'
  it 'integrates safety features'
end
```

### Policy Testing
```ruby
RSpec.describe PersonBlockPolicy do
  it 'allows users to block others'
  it 'prevents blocking platform managers'  
  it 'prevents self-blocking'
  it 'allows block removal by blocker'
end
```

## Configuration & Deployment

### Environment Variables
```bash
# Platform configuration
PLATFORM_PRIVACY=public
REQUIRES_INVITATION=false
PLATFORM_TIME_ZONE=UTC

# Safety configuration  
ENABLE_CONTENT_REPORTING=true
AUTO_BLOCK_THRESHOLD=10
SPAM_DETECTION=true

# Privacy defaults
DEFAULT_PROFILE_PRIVACY=private
DEFAULT_CONTENT_PRIVACY=private
```

### Database Configuration
```ruby
# Migration considerations
# - Ensure proper indexing for performance
# - Add constraints for data integrity
# - Consider partitioning for large datasets

class CreatePersonBlocks < ActiveRecord::Migration[7.1]
  def change
    create_table :better_together_person_blocks, id: :uuid do |t|
      t.references :blocker, null: false, type: :uuid
      t.references :blocked, null: false, type: :uuid
      t.timestamps
      
      t.index [:blocker_id, :blocked_id], unique: true, name: 'unique_person_blocks'
    end
  end
end
```

### Performance Considerations
- **Membership Caching**: Cache expensive membership queries
- **Privacy Filtering**: Optimize privacy-aware database queries
- **Bulk Operations**: Efficient bulk membership and permission operations
- **Search Indexing**: Elasticsearch integration for community and user search

## Development Guidelines

### Adding New Social Features
1. **Model Design**: Follow existing association patterns and privacy controls
2. **Authorization**: Implement comprehensive Pundit policies
3. **UI Integration**: Use existing UI patterns and Turbo Stream updates
4. **Testing**: Comprehensive test coverage for all social interactions
5. **Privacy**: Default-private approach with explicit public controls

### Extending Safety Features
1. **Report Types**: Add new reportable content types with polymorphic associations
2. **Moderation Tools**: Build on existing policy framework for new moderation features
3. **Privacy Controls**: Extend privacy concern for new privacy-sensitive features
4. **Notification Integration**: Use Noticed for safety-related notifications

### Performance Optimization
1. **Query Optimization**: Use includes and joins for association-heavy operations
2. **Caching Strategy**: Implement appropriate caching for expensive operations
3. **Background Processing**: Use Sidekiq for time-intensive safety operations
4. **Database Indexing**: Proper indexing for frequently queried associations

## Security Considerations

### Data Protection
- **Encryption at Rest**: Sensitive personal data encrypted using Active Record encryption
- **Secure Communications**: HTTPS enforcement for all platform communications
- **Session Security**: Secure session management with proper timeout controls
- **CSRF Protection**: Comprehensive CSRF token validation

### User Safety
- **Block Enforcement**: Blocked users cannot interact across the platform
- **Report Processing**: Secure handling of sensitive report information
- **Privacy Enforcement**: Strict enforcement of user privacy settings
- **Account Security**: Multi-factor authentication and secure password requirements

### Platform Security
- **Rate Limiting**: Protection against abuse and spam
- **Input Validation**: Comprehensive input sanitization and validation
- **SQL Injection Prevention**: Parameterized queries and safe query building
- **XSS Protection**: Output encoding and Content Security Policy enforcement

## Future Roadmap

### Short-term Enhancements
- **Enhanced Blocking**: Temporary blocks with automatic expiration
- **Advanced Reporting**: Category-based reporting with severity levels
- **Community Moderation**: Distributed moderation with community moderators
- **Privacy Dashboard**: Comprehensive privacy control interface

### Long-term Vision
- **AI Moderation**: Machine learning-powered content and behavior analysis
- **Reputation System**: Algorithmic trust scoring and reputation tracking
- **Federation Support**: ActivityPub integration for decentralized social networking
- **Advanced Analytics**: Community health metrics and engagement analytics

## Troubleshooting

### Common Issues
- **Block Not Working**: Check policy authorization and database constraints
- **Privacy Leaks**: Verify privacy scopes in controllers and views
- **Performance Issues**: Review N+1 queries and implement proper caching
- **Authorization Errors**: Check Pundit policies and user permissions

### Debugging Tools
- **Policy Testing**: Use Pundit test helpers for policy debugging
- **Query Analysis**: Rails query analysis tools for performance debugging
- **Log Analysis**: Structured logging for tracking user interactions
- **Error Monitoring**: Exception tracking for community safety issues

---

This community and social system provides a comprehensive foundation for safe, privacy-conscious social interactions within multi-tenant community platforms, with robust user safety mechanisms, content moderation tools, and granular privacy controls.
