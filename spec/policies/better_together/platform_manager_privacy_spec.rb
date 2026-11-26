# frozen_string_literal: true

require 'rails_helper'

# A platform manager operates the platform (settings, member status, hide and suspend)
# and edits the platform's own content. These specs pin the other half: being a
# manager does not open private content that belongs to a community or to a person.
RSpec.describe 'Platform manager privacy boundary', type: :policy do # rubocop:disable RSpec/DescribeClass
  let(:manager) { create(:better_together_user, :confirmed, :platform_manager) }
  let(:host_platform) { BetterTogether::Platform.find_by!(host: true) }
  let(:other_person) { create(:better_together_person) }
  let(:other_community) { create(:better_together_community, creator: other_person, privacy: 'private') }

  before { configure_host_platform }

  describe 'private and draft posts' do
    let!(:community_post) do
      create(:better_together_post, author: other_person, creator: other_person, community: other_community,
                                    privacy: 'private', published_at: nil)
    end
    let!(:editorial_post) do
      create(:better_together_post, author: other_person, creator: other_person,
                                    community: host_platform.community, privacy: 'private', published_at: nil)
    end

    it 'hides a private post that lives in another community from the manager scope' do
      scope = BetterTogether::PostPolicy::Scope.new(manager, BetterTogether::Post).resolve
      expect(scope).not_to include(community_post)
    end

    it 'denies show, edit and destroy of that post' do
      policy = BetterTogether::PostPolicy.new(manager, community_post)
      expect([policy.show?, policy.update?, policy.destroy?]).to all(be(false))
    end

    it 'keeps the platform editorial post manageable' do
      scope = BetterTogether::PostPolicy::Scope.new(manager, BetterTogether::Post).resolve
      policy = BetterTogether::PostPolicy.new(manager, editorial_post)

      expect(scope).to include(editorial_post)
      expect([policy.show?, policy.update?, policy.destroy?]).to all(be(true))
    end

    it 'lets a community content manager of that community still manage the post' do
      organizer = create(:better_together_user, :confirmed)
      organizer_role = BetterTogether::Role.find_default('community_organizer', platform: host_platform)
      BetterTogether::PersonCommunityMembership.create!(joinable: other_community, member: organizer.person,
                                                        role: organizer_role, status: 'active')

      expect(BetterTogether::PostPolicy.new(organizer, community_post).update?).to be true
    end
  end

  describe 'private events' do
    let!(:person_event) do
      create(:better_together_event, creator: other_person, privacy: 'private', status: 'draft')
    end
    let!(:community_event) do
      create(:better_together_event, creator: other_person, privacy: 'private').tap do |event|
        BetterTogether::EventHost.create!(event:, host: other_community)
        event.event_hosts.reset
      end
    end
    let!(:editorial_event) do
      create(:better_together_event, creator: other_person, privacy: 'private').tap do |event|
        BetterTogether::EventHost.create!(event:, host: host_platform.community)
        event.event_hosts.reset
      end
    end

    it 'hides private events hosted by people or other communities from the manager scope' do
      scope = BetterTogether::EventPolicy::Scope.new(manager, BetterTogether::Event).resolve
      expect(scope).not_to include(person_event, community_event)
    end

    it 'denies show, update and destroy of those events' do
      [person_event, community_event].each do |event|
        policy = BetterTogether::EventPolicy.new(manager, event)
        expect([policy.show?, policy.update?, policy.destroy?]).to all(be(false))
      end
    end

    it 'keeps the platform own event manageable' do
      scope = BetterTogether::EventPolicy::Scope.new(manager, BetterTogether::Event).resolve
      policy = BetterTogether::EventPolicy.new(manager, editorial_event)

      expect(scope).to include(editorial_event)
      expect([policy.show?, policy.update?, policy.destroy?]).to all(be(true))
    end
  end

  describe 'private addresses of other people' do
    let!(:private_address) do
      create(:better_together_address, contact_detail: other_person.contact_detail || other_person.create_contact_detail!,
                                       privacy: 'private')
    end

    it 'hides them from the manager scope' do
      scope = BetterTogether::AddressPolicy::Scope.new(manager, BetterTogether::Address).resolve
      expect(scope).not_to include(private_address)
    end

    it 'still lets the manager read a public address' do
      public_address = create(:better_together_address, privacy: 'public')
      scope = BetterTogether::AddressPolicy::Scope.new(manager, BetterTogether::Address).resolve
      expect(scope).to include(public_address)
    end
  end

  describe 'conversations and messages' do
    let(:conversation) { create(:better_together_conversation, creator: other_person) }
    let!(:message) { create(:better_together_message, conversation:, sender: other_person) }

    it 'excludes conversations the manager is not part of from the policy scope' do
      scope = BetterTogether::ConversationPolicy::Scope.new(manager, BetterTogether::Conversation).resolve
      expect(scope).not_to include(conversation)
    end

    it 'denies show and send to a non-participant manager' do
      policy = BetterTogether::ConversationPolicy.new(manager, conversation)
      expect([policy.show?, policy.send_message?]).to all(be(false))
    end

    it 'excludes the messages from the manager scope and denies show' do
      scope = BetterTogether::MessagePolicy::Scope.new(manager, BetterTogether::Message).resolve
      expect(scope).not_to include(message)
      expect(BetterTogether::MessagePolicy.new(manager, message).show?).to be false
    end
  end

  describe 'private uploads' do
    let!(:upload) { create(:better_together_upload, creator: other_person, privacy: 'private') }

    it 'excludes them from the manager scope and denies show, update and download' do
      scope = BetterTogether::UploadPolicy::Scope.new(manager, BetterTogether::Upload).resolve
      policy = BetterTogether::UploadPolicy.new(manager, upload)

      expect(scope).not_to include(upload)
      expect([policy.show?, policy.update?, policy.download?]).to all(be(false))
    end
  end

  describe 'private people' do
    let(:private_person) { create(:better_together_person, privacy: 'private') }

    it 'does not show a private profile outside the manager circle' do
      scope = BetterTogether::PersonPolicy::Scope.new(manager, BetterTogether::Person).resolve

      expect(scope).not_to include(private_person)
      expect(BetterTogether::PersonPolicy.new(manager, private_person).show?).to be false
    end
  end
end
