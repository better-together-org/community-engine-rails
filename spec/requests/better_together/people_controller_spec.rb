# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'BetterTogether::PeopleController', :as_platform_manager do
  let(:locale) { I18n.default_locale }
  let(:platform_manager) { BetterTogether::User.find_by(email: 'manager@example.test') }

  describe 'GET /:locale/.../host/p/:id' do
    let!(:person) { create(:better_together_person, privacy: 'public') }

    it 'renders show' do
      get better_together.person_path(locale:, id: person.slug)
      expect(response).to have_http_status(:ok)
    end

    it 'renders edit' do
      get better_together.edit_person_path(locale:, id: platform_manager.person.slug)
      expect(response).to have_http_status(:ok)
    end

    it 'uses proxied attachment URLs in the edit form' do
      platform_manager.person.profile_image.attach(
        io: StringIO.new('<svg xmlns="http://www.w3.org/2000/svg" width="1" height="1"></svg>'),
        filename: 'person-profile.svg',
        content_type: 'image/svg+xml'
      )
      platform_manager.person.cover_image.attach(
        io: StringIO.new('<svg xmlns="http://www.w3.org/2000/svg" width="1" height="1"></svg>'),
        filename: 'person-cover.svg',
        content_type: 'image/svg+xml'
      )

      get better_together.edit_person_path(locale:, id: platform_manager.person.slug)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(
        Rails.application.routes.url_helpers.rails_storage_proxy_path(platform_manager.person.profile_image, only_path: true)
      )
      expect(response.body).to include(
        Rails.application.routes.url_helpers.rails_storage_proxy_path(platform_manager.person.cover_image, only_path: true)
      )
    end

    it 'shows agreement acceptance audit details when present', :aggregate_failures do
      agreement = create(
        :better_together_agreement,
        title: 'Privacy Policy Audit Snapshot',
        identifier: "privacy-policy-audit-#{SecureRandom.hex(4)}"
      )
      participant = create(
        :better_together_agreement_participant,
        participant: person,
        agreement:,
        accepted_at: Time.zone.parse('2026-03-30 12:00:00'),
        acceptance_method: :agreement_review,
        agreement_title_snapshot: 'Privacy Policy (March 2026)',
        agreement_updated_at_snapshot: Time.zone.parse('2026-03-30 09:00:00')
      )

      get better_together.person_path(locale:, id: person.slug)

      expect(response).to have_http_status(:ok)
      expect(assigns(:agreement_participants).map(&:id)).to contain_exactly(participant.id)
      expect(assigns(:agreement_participants).first.association(:agreement)).to be_loaded
      expect(response.body).to include(participant.agreement_title_snapshot)
      expect(response.body).to include(
        I18n.t(
          'better_together.agreements.participant.accepted_via',
          method: I18n.t('better_together.agreements.participant.acceptance_methods.agreement_review')
        )
      )
      expect(response.body).to include(I18n.t('better_together.agreements.participant.agreement_revision', timestamp: '').strip)
      expect(response.body).to include(participant.agreement_updated_at_snapshot.in_time_zone.strftime('%B %d, %Y'))
    end

    it 'shows contribution history and linked github identities when present' do
      page = create(:better_together_page, privacy: 'public')
      post = create(:better_together_post, creator: person, author: person, privacy: 'public')
      page.add_governed_contributor(person, role: 'editor')
      post.add_governed_contributor(person, role: 'reviewer')
      page.contributions.first.update!(details: {
                                         'github_handle' => 'octo-person',
                                         'github_sources' => [{ 'reference_key' => 'pull_request_1494' }]
                                       })
      post.contributions.first.update!(details: {
                                         'github_handle' => 'octo-person',
                                         'github_sources' => [{ 'reference_key' => 'commit_abc123' }]
                                       })

      create(
        :better_together_person_platform_integration,
        :github,
        person:,
        user: person.user || create(:better_together_user, person:),
        platform: create(:better_together_platform, :external, identifier: "github-#{SecureRandom.hex(3)}"),
        handle: 'octo-person',
        profile_url: 'https://github.com/octo-person'
      )

      get better_together.person_path(locale:, id: person.slug)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Contributions')
      expect(response.body).to include(page.title)
      expect(response.body).to include(post.title)
      expect(response.body).to include('Linked GitHub Identities')
      expect(response.body).to include('octo-person')
    end
  end

  describe 'GET /:locale/.../host/p/:id (show) - calendar tab' do
    let!(:person) { platform_manager.person }
    let!(:community) { create(:better_together_community, creator: person) }

    let!(:draft_event) do
      create(:better_together_event,
             :draft,
             name: 'Draft Event',
             creator: person).tap do |event|
        create(:better_together_event_host, event: event, host: community)
      end
    end

    let!(:upcoming_event) do
      create(:better_together_event,
             name: 'Upcoming Event',
             starts_at: 2.days.from_now,
             ends_at: 2.days.from_now + 1.hour,
             creator: person).tap do |event|
        create(:better_together_event_host, event: event, host: community)
      end
    end

    let!(:ongoing_event) do
      create(:better_together_event,
             name: 'Ongoing Event',
             starts_at: 15.minutes.ago,
             ends_at: 15.minutes.from_now,
             duration_minutes: 30,
             creator: person).tap do |event|
        create(:better_together_event_host, event: event, host: community)
      end
    end

    let!(:past_event) do
      create(:better_together_event,
             name: 'Past Event',
             starts_at: 2.days.ago,
             ends_at: 2.days.ago + 1.hour,
             creator: person).tap do |event|
        create(:better_together_event_host, event: event, host: community)
      end
    end

    it 'categorizes events correctly' do
      get better_together.person_path(locale:, id: person.slug)
      expect(response).to have_http_status(:ok)

      expect(assigns(:all_calendar_events)).to include(draft_event, upcoming_event, ongoing_event, past_event)
      expect(assigns(:draft_events)).to include(draft_event)
      expect(assigns(:upcoming_events)).to include(upcoming_event)
      expect(assigns(:ongoing_events)).to include(ongoing_event)
      expect(assigns(:past_events)).to include(past_event)
    end

    it 'displays ongoing events section with translated header' do
      get better_together.person_path(locale:, id: person.slug)
      expect_html_contents(
        'Ongoing Event',
        I18n.t('better_together.people.calendar.ongoing_events')
      )
    end

    it 'displays in_progress badge for ongoing events' do
      get better_together.person_path(locale:, id: person.slug)
      expect_html_content(I18n.t('better_together.people.calendar.in_progress'))
    end

    it 'uses recent_events translation for past events section' do
      get better_together.person_path(locale:, id: person.slug)
      expect_html_content(I18n.t('better_together.people.calendar.recent_events'))
      expect_no_html_content('recent_past_events')
    end
  end

  describe 'PATCH /:locale/.../host/p/:id' do
    let!(:person) { platform_manager.person }

    it 'updates name and redirects' do
      patch better_together.person_path(locale:, id: person.slug), params: {
        person: { name: 'Updated Name' }
      }

      expect(response).to have_http_status(:see_other)

      follow_redirect!
      expect(response).to have_http_status(:ok)
      expect(person.reload.name).to eq('Updated Name')
    end

    it 'updates nested contact details and persists the changes', :aggregate_failures do
      existing_email = person.contact_detail.email_addresses.first ||
                       create(:better_together_email_address, contact_detail: person.contact_detail)

      patch better_together.person_path(locale:, id: person.slug), params: {
        person: {
          name: 'Updated Name',
          contact_detail_attributes: {
            id: person.contact_detail.id,
            email_addresses_attributes: {
              '0' => {
                id: existing_email.id,
                email: 'updated@example.test',
                label: 'primary',
                primary_flag: '1'
              }
            },
            phone_numbers_attributes: {
              '0' => {
                number: '7095551212',
                label: 'mobile',
                primary_flag: '1'
              }
            },
            addresses_attributes: {
              '0' => {
                name: 'Home',
                line1: '12 Main Street',
                city_name: 'Corner Brook',
                state_province_name: 'NL',
                country_name: 'Canada',
                postal_code: 'A2H 1C4',
                physical: '1',
                postal: '1'
              }
            }
          }
        }
      }

      expect(response).to have_http_status(:see_other)

      person.reload
      expect(person.name).to eq('Updated Name')
      expect(person.contact_detail.email_addresses.pluck(:email)).to include('updated@example.test')
      expect(person.contact_detail.phone_numbers.pluck(:number)).to include('7095551212')

      address = person.contact_detail.addresses.order(:created_at).last
      expect(address.line1).to eq('12 Main Street')
      expect(address.city_name).to eq('Corner Brook')
      expect(address.country_name).to eq('Canada')
    end

    it 'rerenders edit when the update is invalid' do
      original_name = person.name

      patch better_together.person_path(locale:, id: person.slug), params: {
        person: { name: '' }
      }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include('Please address the errors below.')
      expect(person.reload.name).to eq(original_name)
    end
  end
end
