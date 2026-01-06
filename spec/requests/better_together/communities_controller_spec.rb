# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'BetterTogether::CommunitiesController' do
  let(:locale) { I18n.default_locale }
  let(:platform_manager) { BetterTogether::User.find_by(email: 'manager@example.test') }
  let(:regular_user) { BetterTogether::User.find_by(email: 'user@example.test') }

  describe 'GET /:locale/c (index)' do
    let!(:public_community) do
      create(:better_together_community,
             name: 'Public Community',
             privacy: 'public',
             creator: platform_manager.person)
    end

    let!(:private_community) do
      create(:better_together_community,
             name: 'Private Community',
             privacy: 'private',
             creator: platform_manager.person)
    end

    before do
      puts "\n=== BEFORE BLOCK ==="
      puts "Platform manager: #{platform_manager.inspect}"
      puts "Metadata: #{RSpec.current_example.metadata[:as_platform_manager]}"
      puts "Already authenticated: #{RSpec.current_example.metadata[:already_authenticated]}"
    end

    it 'renders the index page successfully', :as_platform_manager do
      puts "\n=== IN TEST ==="
      puts "Communities path: #{better_together.communities_path(locale:)}"
      puts "Request env warden user: #{request.env['warden']&.user&.inspect}" if defined?(request)
      puts "Request env warden authenticated?: #{request.env['warden']&.authenticated?(:user)}" if defined?(request)

      get better_together.communities_path(locale:)

      puts "Response status: #{response.status}"
      puts "Response location: #{response.location}" if response.redirect?
      puts "Response body (first 1000 chars):\n#{response.body[0..1000]}" if response.status == 404

      expect(response).to have_http_status(:ok)
    end

    it 'displays communities in the list', :as_platform_manager do
      get better_together.communities_path(locale:)
      expect_html_contents('Public Community', 'Private Community')
    end

    it 'generates slug-based URLs for community links', :as_platform_manager do
      get better_together.communities_path(locale:)
      # URLs should use slugs, not UUIDs (check href attributes, not id attributes)
      expect(response.body).to include("/#{locale}/c/#{public_community.slug}")
      # Check that UUID doesn't appear in href links (it's okay in id attributes for dom_id)
      expect(response.body).not_to match(/href="[^"]*#{Regexp.escape(public_community.id)}/)
    end

    it 'includes a link to create new community for platform managers', :as_platform_manager do
      get better_together.communities_path(locale:)
      expect(response.body).to include(better_together.new_community_path(locale:))
    end

    context 'when user is not authenticated', :unauthenticated do
      it 'allows access to index' do
        get better_together.communities_path(locale:)
        expect(response).to have_http_status(:ok)
      end

      it 'shows only public communities' do
        get better_together.communities_path(locale:)
        expect_html_content('Public Community')
        expect_no_html_content('Private Community')
      end
    end

    context 'as regular user', :as_user do
      it 'renders index for authenticated users' do
        get better_together.communities_path(locale:)
        expect(response).to have_http_status(:ok)
      end

      it 'shows only public communities and member communities' do
        # Create a private community where user is a member
        member_community = create(:better_together_community,
                                  name: 'Member Community',
                                  privacy: 'private',
                                  creator: platform_manager.person)
        create(:better_together_person_community_membership,
               member: regular_user.person,
               joinable: member_community)

        # Create a private community where user is the creator
        create(:better_together_community,
               name: 'Creator Community',
               privacy: 'private',
               creator: regular_user.person)

        # Create a private community where user has no access
        create(:better_together_community,
               name: 'Inaccessible Community',
               privacy: 'private',
               creator: platform_manager.person)

        get better_together.communities_path(locale:)

        # Should see public community
        expect_html_content('Public Community')
        # Should see member community
        expect_html_content('Member Community')
        # Should see creator community
        expect_html_content('Creator Community')
        # Should NOT see inaccessible community
        expect_no_html_content('Inaccessible Community')
      end
    end
  end

  describe 'GET /:locale/c/:slug (show)', :as_platform_manager do
    let(:community) do
      create(:better_together_community,
             name: 'Test Community',
             privacy: 'public',
             creator: platform_manager.person)
    end

    it 'renders show page using slug' do
      get better_together.community_path(locale:, id: community.slug)
      expect(response).to have_http_status(:ok)
    end

    it 'displays community name' do
      get better_together.community_path(locale:, id: community.slug)
      expect_html_content('Test Community')
    end

    it 'finds community by slug across locales' do
      # The FriendlyResourceController should find by slug
      get better_together.community_path(locale:, id: community.slug)
      expect(response).to have_http_status(:ok)
      expect(assigns(:community)).to eq(community)
    end
  end

  describe 'GET /:locale/c/:slug (show) - access control' do
    let(:community) do
      create(:better_together_community,
             name: 'Test Community',
             privacy: 'public',
             creator: platform_manager.person)
    end

    context 'with public community', :unauthenticated do
      it 'allows unauthenticated access to public communities' do
        get better_together.community_path(locale:, id: community.slug)
        expect(response).to have_http_status(:ok)
      end
    end

    context 'with private community', :unauthenticated do
      let(:private_community) do
        create(:better_together_community,
               name: 'Private Community',
               privacy: 'private',
               creator: platform_manager.person)
      end

      it 'redirects to sign in for private communities' do
        get better_together.community_path(locale:, id: private_community.slug)
        expect(response).to redirect_to(better_together.new_user_session_path(locale:))
      end
    end

    context 'with private community as member', :as_user do
      let(:private_community) do
        create(:better_together_community,
               name: 'Members Only Community',
               privacy: 'private',
               creator: platform_manager.person)
      end

      it 'allows access when user is a member' do
        # Add regular_user as a member
        member_role = BetterTogether::Role.find_by(identifier: 'community_member')
        create(:better_together_person_community_membership,
               member: regular_user.person,
               joinable: private_community,
               role: member_role)

        get better_together.community_path(locale:, id: private_community.slug)
        expect(response).to have_http_status(:ok)
      end

      it 'denies access when user is not a member' do
        get better_together.community_path(locale:, id: private_community.slug)
        # Authenticated users without permission are redirected (not shown 403)
        expect(response).to have_http_status(:found)
        expect(flash[:error]).to be_present
      end
    end

    context 'with private community as creator', :as_user do
      let(:private_community) do
        create(:better_together_community,
               name: 'Creator Community',
               privacy: 'private',
               creator: regular_user.person)
      end

      it 'allows access when user is the creator' do
        get better_together.community_path(locale:, id: private_community.slug)
        expect(response).to have_http_status(:ok)
      end
    end
  end

  describe 'GET /:locale/c/new', :as_platform_manager do
    it 'renders new community form' do
      get better_together.new_community_path(locale:)
      expect(response).to have_http_status(:ok)
    end

    it 'authorizes community creation' do
      get better_together.new_community_path(locale:)
      expect(assigns(:community)).to be_a_new(BetterTogether::Community)
    end
  end

  describe 'POST /:locale/c', :as_platform_manager do
    let(:valid_params) do
      {
        community: {
          name_en: 'New Community',
          description_en: 'A new test community',
          privacy: 'public'
        }
      }
    end

    it 'creates a new community' do
      expect do
        post better_together.communities_path(locale:), params: valid_params
      end.to change(BetterTogether::Community, :count).by(1)
    end

    it 'redirects to the new community' do
      post better_together.communities_path(locale:), params: valid_params
      expect(response).to have_http_status(:found)
      community = BetterTogether::Community.last
      expect(response).to redirect_to(better_together.community_path(locale:, id: community.slug))
    end

    it 'generates a slug from the name' do
      post better_together.communities_path(locale:), params: valid_params
      community = BetterTogether::Community.last
      expect(community.slug).to eq('new-community')
    end
  end

  describe 'GET /:locale/c/:slug/edit', :as_platform_manager do
    let(:community) do
      create(:better_together_community,
             name: 'Edit Test',
             creator: platform_manager.person)
    end

    it 'renders edit form using slug' do
      get better_together.edit_community_path(locale:, id: community.slug)
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'PATCH /:locale/c/:slug', :as_platform_manager do
    let(:community) do
      create(:better_together_community,
             name: 'Original Name',
             privacy: 'private',
             creator: platform_manager.person)
    end

    let(:update_params) do
      {
        community: {
          name_en: 'Updated Name',
          privacy: 'public'
        }
      }
    end

    it 'updates the community using slug' do
      patch better_together.community_path(locale:, id: community.slug), params: update_params
      community.reload
      expect(community.name).to eq('Updated Name')
      expect(community.privacy).to eq('public')
    end

    it 'redirects to edit page' do
      patch better_together.community_path(locale:, id: community.slug), params: update_params
      expect(response).to have_http_status(:found)
    end

    it 'does not update slug when only name changes' do
      original_slug = community.slug
      patch better_together.community_path(locale:, id: community.slug), params: update_params
      community.reload
      expect(community.slug).to eq(original_slug)
      expect(community.name).to eq('Updated Name')
    end

    it 'updates slug when explicitly set' do
      params_with_slug = {
        community: {
          name_en: 'Updated Name',
          identifier: 'custom-slug'
        }
      }
      patch better_together.community_path(locale:, id: community.slug), params: params_with_slug
      community.reload
      expect(community.slug).to eq('custom-slug')
    end
  end

  describe 'DELETE /:locale/c/:slug', :as_platform_manager do
    let!(:community) do
      create(:better_together_community,
             name: 'Delete Test',
             creator: platform_manager.person)
    end

    it 'deletes the community using slug' do
      expect do
        delete better_together.community_path(locale:, id: community.slug)
      end.to change(BetterTogether::Community, :count).by(-1)
    end

    it 'redirects to communities index' do
      delete better_together.community_path(locale:, id: community.slug)
      expect(response).to redirect_to(better_together.communities_path(locale:))
    end
  end

  describe 'GET /:locale/c/:slug (show) - member visibility' do
    let(:community) do
      create(:better_together_community,
             name: 'Test Community',
             privacy: 'public',
             creator: platform_manager.person)
    end

    let(:member_role) { BetterTogether::Role.find_by(identifier: 'community_member') }

    let!(:first_member) do
      person = create(:better_together_person, name: "First O'Brien")
      create(:better_together_person_community_membership,
             member: person,
             joinable: community,
             role: member_role)
      person
    end

    let!(:second_member) do
      person = create(:better_together_person, name: "Second O'Malley")
      create(:better_together_person_community_membership,
             member: person,
             joinable: community,
             role: member_role)
      person
    end

    context 'when user is not authenticated', :unauthenticated do
      it 'does not show members tab' do
        get better_together.community_path(locale:, id: community.slug)
        expect(response).to have_http_status(:ok)
        expect(response.body).not_to include('members-tab')
      end

      it 'does not show members list' do
        get better_together.community_path(locale:, id: community.slug)
        expect(response.body).not_to include('members_list')
      end

      it 'does not display member names' do
        get better_together.community_path(locale:, id: community.slug)
        expect_no_html_contents(first_member.name, second_member.name) # Use HTML assertion helper
      end
    end

    context 'when user is authenticated but not a member', :as_user do
      it 'does not show members tab' do
        get better_together.community_path(locale:, id: community.slug)
        expect(response).to have_http_status(:ok)
        expect(response.body).not_to include('members-tab')
      end

      it 'does not show members list' do
        get better_together.community_path(locale:, id: community.slug)
        expect(response.body).not_to include('members_list')
      end
    end

    context 'when user is a community member', :as_user do
      before do
        create(:better_together_person_community_membership,
               member: regular_user.person,
               joinable: community,
               role: member_role)
      end

      it 'shows members tab' do
        get better_together.community_path(locale:, id: community.slug)
        expect(response).to have_http_status(:ok)
        expect(response.body).to include('members-tab')
      end

      it 'shows members list' do
        get better_together.community_path(locale:, id: community.slug)
        expect(response.body).to include('members_list')
      end

      it 'displays member names' do
        get better_together.community_path(locale:, id: community.slug)
        expect_html_contents(first_member.name, second_member.name) # Use HTML assertion helper
      end
    end

    context 'when user is the community creator', :as_user do
      let(:community) do
        create(:better_together_community,
               name: 'Creator Community',
               privacy: 'public',
               creator: regular_user.person)
      end

      it 'shows members tab' do
        get better_together.community_path(locale:, id: community.slug)
        expect(response).to have_http_status(:ok)
        expect(response.body).to include('members-tab')
      end

      it 'shows members list' do
        get better_together.community_path(locale:, id: community.slug)
        expect(response.body).to include('members_list')
      end

      it 'displays member names' do
        get better_together.community_path(locale:, id: community.slug)
        expect_html_contents(first_member.name, second_member.name) # Use HTML assertion helper
      end
    end

    context 'when user is a platform manager', :as_platform_manager do
      it 'shows members tab' do
        get better_together.community_path(locale:, id: community.slug)
        expect(response).to have_http_status(:ok)
        expect(response.body).to include('members-tab')
      end

      it 'shows members list' do
        get better_together.community_path(locale:, id: community.slug)
        expect(response.body).to include('members_list')
      end

      it 'displays member names' do
        get better_together.community_path(locale:, id: community.slug)
        expect_html_contents(first_member.name, second_member.name) # Use HTML assertion helper
      end
    end
  end

  describe 'GET /:locale/c/:slug (show) - events tab' do
    let(:community) do
      create(:better_together_community,
             name: 'Event Test Community',
             privacy: 'public',
             creator: platform_manager.person)
    end

    let!(:draft_event) do
      create(:better_together_event,
             :draft,
             name: 'Draft Event',
             creator: platform_manager.person).tap do |event|
        create(:better_together_event_host,
               event: event,
               host: community)
      end
    end

    let!(:upcoming_event) do
      create(:better_together_event,
             name: 'Upcoming Event',
             starts_at: 2.days.from_now,
             ends_at: 2.days.from_now + 1.hour,
             duration_minutes: 60,
             creator: platform_manager.person).tap do |event|
        create(:better_together_event_host,
               event: event,
               host: community)
      end
    end

    let!(:ongoing_event) do
      create(:better_together_event,
             name: 'Ongoing Event',
             starts_at: 15.minutes.ago,
             ends_at: 15.minutes.from_now, # 30 minutes total: started 15 ago, ends 15 from now
             duration_minutes: 30,
             creator: platform_manager.person).tap do |event|
        create(:better_together_event_host,
               event: event,
               host: community)
      end
    end

    let!(:past_event) do
      create(:better_together_event,
             name: 'Past Event',
             starts_at: 2.days.ago,
             ends_at: 2.days.ago + 1.hour,
             duration_minutes: 60,
             creator: platform_manager.person).tap do |event|
        create(:better_together_event_host,
               event: event,
               host: community)
      end
    end

    context 'when user is not authenticated', :unauthenticated do
      it 'shows events tab' do
        get better_together.community_path(locale:, id: community.slug)
        expect(response).to have_http_status(:ok)
        expect(response.body).to include('events-tab')
      end

      it 'does not show draft events' do
        get better_together.community_path(locale:, id: community.slug)
        expect_no_html_content('Draft Event')
        expect_no_html_content('draft_events_list')
      end

      it 'shows upcoming events section' do
        get better_together.community_path(locale:, id: community.slug)
        expect_html_content('Upcoming Event')
        expect(response.body).to include('upcoming_events_list')
      end

      it 'shows ongoing events section' do
        get better_together.community_path(locale:, id: community.slug)
        expect_html_content('Ongoing Event')
        expect(response.body).to include('ongoing_events_list')
      end

      it 'shows past events section' do
        get better_together.community_path(locale:, id: community.slug)
        expect_html_content('Past Event')
        expect(response.body).to include('past_events_list')
      end

      it 'does not show create event button' do
        get better_together.community_path(locale:, id: community.slug)
        expect(response.body).not_to include('Create an Event')
      end
    end

    context 'when user is authenticated but cannot create events', :as_user do
      it 'shows events tab' do
        get better_together.community_path(locale:, id: community.slug)
        expect(response).to have_http_status(:ok)
        expect(response.body).to include('events-tab')
      end

      it 'does not show draft events' do
        get better_together.community_path(locale:, id: community.slug)
        expect_no_html_content('Draft Event')
        expect_no_html_content('draft_events_list')
      end

      it 'shows upcoming events' do
        get better_together.community_path(locale:, id: community.slug)
        expect_html_content('Upcoming Event')
      end

      it 'shows ongoing events' do
        get better_together.community_path(locale:, id: community.slug)
        expect_html_content('Ongoing Event')
      end

      it 'shows past events' do
        get better_together.community_path(locale:, id: community.slug)
        expect_html_content('Past Event')
      end

      it 'does not show create event button' do
        get better_together.community_path(locale:, id: community.slug)
        expect(response.body).not_to include('Create an Event')
      end
    end

    context 'when user can create events (platform manager)', :as_platform_manager do
      it 'shows events tab' do
        get better_together.community_path(locale:, id: community.slug)
        expect(response).to have_http_status(:ok)
        expect(response.body).to include('events-tab')
      end

      it 'shows draft events section' do
        get better_together.community_path(locale:, id: community.slug)
        expect_html_content('Draft Event')
        expect(response.body).to include('draft_events_list')
      end

      it 'shows draft section header' do
        get better_together.community_path(locale:, id: community.slug)
        expect(response.body).to include('Draft')
      end

      it 'shows upcoming events section with translated header' do
        get better_together.community_path(locale:, id: community.slug)
        expect(response.body).to include('upcoming_events_list')
        expect_html_contents(
          'Upcoming Event',
          I18n.t('better_together.people.calendar.upcoming_events')
        )
      end

      it 'shows ongoing events section with translated header' do
        get better_together.community_path(locale:, id: community.slug)
        expect(response.body).to include('ongoing_events_list')
        expect_html_contents(
          'Ongoing Event',
          I18n.t('better_together.people.calendar.ongoing_events')
        )
      end

      it 'shows past events section with translated header' do
        get better_together.community_path(locale:, id: community.slug)
        expect(response.body).to include('past_events_list')
        expect_html_contents(
          'Past Event',
          I18n.t('better_together.people.calendar.recent_events')
        )
      end

      it 'shows create event button' do
        get better_together.community_path(locale:, id: community.slug)
        expect(response.body).to include('Create an Event')
      end

      it 'assigns all event categories to instance variables' do
        get better_together.community_path(locale:, id: community.slug)
        expect(assigns(:draft_events)).to include(draft_event)
        expect(assigns(:upcoming_events)).to include(upcoming_event)
        expect(assigns(:ongoing_events)).to include(ongoing_event)
        expect(assigns(:past_events)).to include(past_event)
      end
    end

    context 'when community has no events', :as_platform_manager do
      let(:empty_community) do
        create(:better_together_community,
               name: 'Empty Community',
               privacy: 'public',
               creator: platform_manager.person)
      end

      it 'shows events tab' do
        get better_together.community_path(locale:, id: empty_community.slug)
        expect(response).to have_http_status(:ok)
        expect(response.body).to include('events-tab')
      end

      it 'does not show draft events section when no draft events' do
        get better_together.community_path(locale:, id: empty_community.slug)
        expect(response.body).not_to include('draft_events_list')
      end

      it 'does not show upcoming events section when no upcoming events' do
        get better_together.community_path(locale:, id: empty_community.slug)
        expect(response.body).not_to include('upcoming_events_list')
      end

      it 'does not show ongoing events section when no ongoing events' do
        get better_together.community_path(locale:, id: empty_community.slug)
        expect(response.body).not_to include('ongoing_events_list')
      end

      it 'does not show past events section when no past events' do
        get better_together.community_path(locale:, id: empty_community.slug)
        expect(response.body).not_to include('past_events_list')
      end

      it 'shows create event button for authorized users' do
        get better_together.community_path(locale:, id: empty_community.slug)
        expect(response.body).to include('Create an Event')
      end
    end

    context 'event time categorization' do
      it 'correctly categorizes a 30-minute event that started 15 minutes ago as ongoing', :as_platform_manager do
        get better_together.community_path(locale:, id: community.slug)

        # Should be in ongoing, not past
        expect(assigns(:ongoing_events)).to include(ongoing_event)
        expect(assigns(:past_events)).not_to include(ongoing_event)

        # Verify it appears in the ongoing section in the HTML
        expect(response.body).to match(/ongoing_events_list.*Ongoing Event/m)
      end

      it 'categorizes events with only starts_at as past after start time', :as_platform_manager do
        event_without_end = create(:better_together_event,
                                   name: 'No End Time Event',
                                   starts_at: 1.hour.ago,
                                   ends_at: nil,
                                   creator: platform_manager.person)
        create(:better_together_event_host,
               event: event_without_end,
               host: community)

        get better_together.community_path(locale:, id: community.slug)

        expect(assigns(:past_events)).to include(event_without_end)
        expect(assigns(:ongoing_events)).not_to include(event_without_end)
      end

      it 'only shows events that have fully ended in past section', :as_platform_manager do
        get better_together.community_path(locale:, id: community.slug)

        # Past event should have ended
        expect(past_event.ends_at).to be < Time.current
        expect(assigns(:past_events)).to include(past_event)

        # Ongoing event should not have ended
        expect(ongoing_event.ends_at).to be > Time.current
        expect(assigns(:past_events)).not_to include(ongoing_event)
      end
    end
  end
end
