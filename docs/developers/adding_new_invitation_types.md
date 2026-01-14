# Adding New Invitation Types - Implementation Guide

This guide explains how to add new invitation types to the Better Together invitation system, which has been consolidated into a template method pattern with shared base functionality.

## Architecture Overview

The invitation system uses a consolidated architecture with:
- **Base class**: `BetterTogether::Invitation` - Contains all shared functionality
- **Child classes**: Inherit from base and implement specific behavior via template methods
- **Shared concern**: `InvitationTokenAuthorization` - Handles token processing in controllers
- **Template method pattern**: Allows customization at specific extension points

## Step-by-Step Implementation Guide

### 1. Create the Invitation Model

Create a new invitation model that inherits from the base class:

```ruby
# app/models/better_together/project_invitation.rb
module BetterTogether
  class ProjectInvitation < Invitation
    # Association to the invitable resource
    belongs_to :invitable, class_name: 'BetterTogether::Project', 
               foreign_key: :invitable_id, inverse_of: :project_invitations

    # Validation for the specific invitable type
    validates :invitable_type, inclusion: { in: ['BetterTogether::Project'] }

    # Override template methods for custom behavior
    private

    # Called after successful invitation acceptance
    def after_accept!
      # Create project membership
      invitable.project_memberships.create!(
        person: invitee,
        role: role || 'member',
        invited_by: inviter
      )
      
      # Send welcome notification
      ProjectWelcomeNotification.with(
        project: invitable,
        invitee: invitee
      ).deliver(invitee)
    end

    # Generate URL for invitation review/acceptance
    def url_for_review
      Rails.application.routes.url_helpers.project_url(
        invitable,
        invitation_token: token,
        locale: locale
      )
    end
  end
end
```

### 2. Update the Target Model

Add the invitation association to your target model:

```ruby
# app/models/better_together/project.rb
module BetterTogether
  class Project < ApplicationRecord
    # ... existing code ...

    # Invitation associations
    has_many :project_invitations, -> { where(invitable_type: 'BetterTogether::Project') },
             class_name: 'BetterTogether::ProjectInvitation',
             foreign_key: :invitable_id,
             dependent: :destroy,
             inverse_of: :invitable

    # Convenience methods
    def invite_person(email:, inviter:, role: 'member', **options)
      project_invitations.create!(
        email: email,
        inviter: inviter,
        role: role,
        **options
      )
    end
  end
end
```

### 3. Create Database Migration

Generate the necessary database changes (usually just for any new columns):

```ruby
# db/migrate/xxx_add_project_invitation_support.rb
class AddProjectInvitationSupport < ActiveRecord::Migration[7.1]
  def change
    # Add any project-specific columns to invitations table if needed
    # The base invitations table already handles most common fields
    
    # Example: Add project-specific role options
    change_column :better_together_invitations, :role, :string, default: 'member'
    
    # Add indexes for project invitations
    add_index :better_together_invitations, 
              [:invitable_type, :invitable_id, :email], 
              where: "invitable_type = 'BetterTogether::Project'",
              name: 'idx_invitations_project_email'
  end
end
```

### 4. Create the Controller

Create a controller that uses the shared token authorization concern:

```ruby
# app/controllers/better_together/project_invitations_controller.rb
module BetterTogether
  class ProjectInvitationsController < ApplicationController
    include InvitationTokenAuthorization
    
    before_action :authenticate_person!
    before_action :set_project
    before_action :authorize_project_management, except: [:accept, :decline]

    def index
      @invitations = @project.project_invitations
                            .includes(:inviter, :invitee)
                            .page(params[:page])
    end

    def create
      @invitation = @project.project_invitations.build(invitation_params)
      @invitation.inviter = current_person

      if @invitation.save
        ProjectInvitationMailer.invite(@invitation).deliver_later
        redirect_to project_invitations_path(@project),
                   notice: t('flash.generic.created', resource: t('resources.invitation'))
      else
        render :new, status: :unprocessable_entity
      end
    end

    def accept
      @invitation = find_invitation_by_token
      if @invitation&.accept!(current_person)
        redirect_to @invitation.invitable,
                   notice: t('invitations.accepted_successfully')
      else
        redirect_to root_path,
                   alert: t('invitations.acceptance_failed')
      end
    end

    def decline
      @invitation = find_invitation_by_token
      if @invitation&.decline!(current_person)
        redirect_to root_path,
                   notice: t('invitations.declined_successfully')
      else
        redirect_to root_path,
                   alert: t('invitations.decline_failed')
      end
    end

    private

    def set_project
      @project = BetterTogether::Project.friendly.find(params[:project_id])
    end

    # Template method implementations for InvitationTokenAuthorization concern
    def invitation_resource_name
      'project'
    end

    def invitation_class_for_resource
      BetterTogether::ProjectInvitation
    end

    # Override privacy check if projects have custom privacy logic
    def check_resource_privacy_with_invitation(invitation)
      return true if @project.public?
      return true if invitation&.pending?
      
      authorize(@project, :show?)
    end

    def invitation_params
      params.require(:project_invitation).permit(:email, :role, :message)
    end

    def authorize_project_management
      authorize(@project, :manage_invitations?)
    end

    def find_invitation_by_token
      return nil unless params[:invitation_token].present?
      
      ProjectInvitation.find_by(
        token: params[:invitation_token],
        invitable: @project
      )
    end
  end
end
```

### 5. Update Routes

Add routes for the new invitation controller:

```ruby
# config/routes.rb
BetterTogether::Engine.routes.draw do
  # ... existing routes ...

  resources :projects, only: [:show, :index] do
    resources :project_invitations, only: [:index, :create, :new] do
      member do
        patch :accept
        patch :decline
        patch :resend
      end
    end
  end

  # Token-based invitation routes
  get '/projects/:project_id/invitation/:invitation_token',
      to: 'projects#show',
      as: :project_invitation_review
end
```

### 6. Create Policy Rules

Add authorization rules for the new invitation type:

```ruby
# app/policies/better_together/project_policy.rb
module BetterTogether
  class ProjectPolicy < ApplicationPolicy
    # ... existing policy methods ...

    def manage_invitations?
      user_is_project_admin? || user_is_project_owner?
    end

    def show?
      return true if record.public?
      return true if valid_invitation_token?
      
      user_is_project_member?
    end

    private

    def valid_invitation_token?
      return false unless invitation_token.present?

      invitation = ProjectInvitation.find_by(
        token: invitation_token,
        invitable: record
      )

      invitation.present? && invitation.pending?
    end

    def user_is_project_member?
      return false unless user

      record.project_memberships.exists?(person: user)
    end

    def user_is_project_admin?
      return false unless user

      record.project_memberships.exists?(person: user, role: ['admin', 'owner'])
    end
  end
end
```

### 7. Create Mailer

Create a mailer for sending invitation emails:

```ruby
# app/mailers/better_together/project_invitation_mailer.rb
module BetterTogether
  class ProjectInvitationMailer < ApplicationMailer
    def invite(invitation)
      @invitation = invitation
      @project = invitation.invitable
      @inviter = invitation.inviter

      I18n.with_locale(invitation.locale || I18n.default_locale) do
        mail(
          to: @invitation.email,
          subject: t('mailers.project_invitations.invite.subject',
                    project_name: @project.name,
                    inviter_name: @inviter.display_name)
        )
      end
    end
  end
end
```

### 8. Create Factories

Add FactoryBot factories for testing:

```ruby
# spec/factories/better_together/project_invitations.rb
FactoryBot.define do
  factory :better_together_project_invitation,
          class: 'BetterTogether::ProjectInvitation',
          aliases: [:project_invitation] do
    association :invitable, factory: :better_together_project
    association :inviter, factory: :better_together_person
    
    email { Faker::Internet.email }
    role { 'member' }
    status { 'pending' }
    
    trait :accepted do
      status { 'accepted' }
      association :invitee, factory: :better_together_person
      accepted_at { 1.day.ago }
    end

    trait :declined do
      status { 'declined' }
      declined_at { 1.day.ago }
    end

    trait :expired do
      expires_at { 1.day.ago }
    end
  end
end
```

### 9. Create Views

Create the necessary view templates:

```erb
<!-- app/views/better_together/project_invitations/index.html.erb -->
<div class="invitation-list">
  <h2><%= t('invitations.project_invitations') %></h2>
  
  <%= render 'shared/invitation_filters' %>
  
  <div class="invitations">
    <%= render partial: 'project_invitation', 
               collection: @invitations %>
  </div>
  
  <%= paginate @invitations if respond_to?(:paginate) %>
</div>

<!-- app/views/better_together/project_invitations/_project_invitation.html.erb -->
<div class="invitation-card" data-invitation-id="<%= project_invitation.id %>">
  <div class="invitation-info">
    <strong><%= project_invitation.email %></strong>
    <span class="badge badge-<%= project_invitation.status %>">
      <%= t("invitations.status.#{project_invitation.status}") %>
    </span>
  </div>
  
  <div class="invitation-actions">
    <%= link_to t('actions.resend'),
                resend_project_invitation_path(@project, project_invitation),
                method: :patch,
                class: 'btn btn-sm btn-outline-secondary',
                data: { confirm: t('confirmations.resend_invitation') } %>
  </div>
</div>
```

### 10. Add Translations

Add internationalization support:

```yml
# config/locales/en.yml
en:
  mailers:
    project_invitations:
      invite:
        subject: "Invitation to join %{project_name} on %{platform_name}"
        
  invitations:
    project_invitations: "Project Invitations"
    accepted_project_invitation: "Successfully joined the project!"
    
  resources:
    project_invitation: "Project Invitation"
```

### 11. Write Tests

Create comprehensive test coverage:

```ruby
# spec/models/better_together/project_invitation_spec.rb
RSpec.describe BetterTogether::ProjectInvitation, type: :model do
  it_behaves_like 'an invitation model'
  
  describe 'associations' do
    it { should belong_to(:invitable).class_name('BetterTogether::Project') }
  end

  describe '#after_accept!' do
    it 'creates project membership' do
      invitation = create(:project_invitation)
      person = create(:better_together_person)
      
      expect {
        invitation.accept!(person)
      }.to change { invitation.invitable.project_memberships.count }.by(1)
    end
  end
  
  describe '#url_for_review' do
    it 'returns project URL with token' do
      invitation = create(:project_invitation)
      
      expect(invitation.url_for_review).to include(invitation.invitable.friendly_id)
      expect(invitation.url_for_review).to include(invitation.token)
    end
  end
end

# spec/requests/better_together/project_invitations_spec.rb
RSpec.describe 'Project Invitations', type: :request do
  include DeviseSessionHelpers
  
  before do
    configure_host_platform
    login('user@example.com', 'password')
  end

  describe 'POST /projects/:project_id/project_invitations' do
    it 'creates invitation successfully' do
      project = create(:better_together_project)
      
      expect {
        post project_invitations_path(project),
             params: {
               project_invitation: {
                 email: 'invited@example.com',
                 role: 'member'
               }
             }
      }.to change { ProjectInvitation.count }.by(1)
      
      expect(response).to redirect_to(project_invitations_path(project))
    end
  end
end
```

## Key Integration Points

### Template Methods to Implement

Every new invitation type must implement these template methods:

1. **`after_accept!`** - Actions to take after invitation acceptance (create memberships, send notifications)
2. **`url_for_review`** - Generate invitation review URL with token

### Controller Concern Integration

Controllers must implement these methods for `InvitationTokenAuthorization`:

1. **`invitation_resource_name`** - Returns string name of the resource ('project')
2. **`invitation_class_for_resource`** - Returns the invitation class
3. **`check_resource_privacy_with_invitation`** (optional) - Custom privacy logic

### Policy Integration

Policies should implement `valid_invitation_token?` method that:
- Finds invitation by token and resource
- Checks invitation is present and pending
- Allows access based on valid invitation

## Best Practices

1. **Inherit from base Invitation model** - Never duplicate functionality
2. **Use template methods** - Override only specific behavior points
3. **Follow naming conventions** - `ResourceInvitation` pattern
4. **Include comprehensive tests** - Models, controllers, requests, features
5. **Add proper authorization** - Use Pundit policies consistently
6. **Internationalize everything** - All user-facing text in locale files
7. **Handle edge cases** - Expired tokens, invalid emails, duplicate invitations
8. **Use background jobs** - Send emails asynchronously
9. **Add proper indexes** - Optimize database queries
10. **Document new invitation flows** - Update system documentation

## Testing Checklist

- [ ] Model validations and associations
- [ ] Template method implementations
- [ ] Controller actions (CRUD operations)
- [ ] Policy authorization rules
- [ ] Email delivery and content
- [ ] Token-based access flows
- [ ] Edge cases and error handling
- [ ] Integration with existing features
- [ ] Performance and security

This implementation guide ensures new invitation types integrate seamlessly with the existing consolidated invitation system while maintaining consistency, security, and performance standards.