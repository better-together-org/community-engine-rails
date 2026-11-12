# frozen_string_literal: true

require 'rails_helper'

# End to end account deletion for a normal member and for the last steward of a platform.
RSpec.describe 'Account deletion flow', :no_auth do # rubocop:disable RSpec/DescribeClass
  let(:password) { 'SecureTest123!@#' }
  let!(:platform) { configure_host_platform }
  let(:steward_role) { BetterTogether::Role.find_by!(identifier: 'platform_steward') }
  let(:settings_path) { better_together.edit_user_registration_path(locale: I18n.default_locale) }
  let(:platform_form_path) { better_together.new_platform_deletion_request_path(locale: I18n.default_locale) }

  def page_html
    Nokogiri::HTML(response.body)
  end

  def member(email: 'member@example.test')
    create(:better_together_user, :confirmed, email:, password:, password_confirmation: password, platform:)
  end

  def make_steward(user)
    BetterTogether::PersonPlatformMembership.create!(member: user.person, joinable: platform,
                                                     role: steward_role, status: 'active')
    user
  end

  def sole_steward
    BetterTogether::PersonPlatformMembership.where(joinable: platform, role: steward_role).destroy_all
    make_steward(member(email: 'steward@example.test'))
  end

  describe 'a normal member' do
    let!(:user) { member }

    before { login(user.email, password) }

    it 'requests deletion, can cancel, and is deleted when the request is approved', :aggregate_failures do
      get settings_path
      expect(page_html.css('#person-deletion-request-form').size).to eq(1)

      post better_together.person_deletion_requests_path(locale: I18n.default_locale),
           params: { person_deletion_request: { requested_reason: 'Leaving' } }
      request = user.person.person_deletion_requests.active.first
      expect(request).to be_present

      delete better_together.person_deletion_request_path(request, locale: I18n.default_locale)
      expect(request.reload).to be_cancelled

      post better_together.person_deletion_requests_path(locale: I18n.default_locale),
           params: { person_deletion_request: { requested_reason: 'Leaving for good' } }
      pending = user.person.person_deletion_requests.active.first
      BetterTogether::PersonDeletionExecutor.call(person_deletion_request: pending,
                                                  reviewed_by: sole_steward.person)

      expect(pending.reload).to be_approved
      expect(BetterTogether::User.find_by(id: user.id)).to be_nil
      expect(BetterTogether::Platform.find_by(id: platform.id)).to be_present
    end

    it 'cannot open the platform removal form', :aggregate_failures do
      get platform_form_path

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'the last steward' do
    let!(:steward) { sole_steward }

    before { login(steward.email, password) }

    it 'sees a pointer to the platform removal form instead of the deletion form', :aggregate_failures do
      get settings_path

      expect(page_html.css('#person-deletion-request-form').size).to eq(0)
      expect(page_html.css('#last-steward-deletion-notice').size).to eq(1)
      expect(page_html.css('#platform-deletion-request-link').size).to eq(1)
    end

    it 'is redirected from both deletion entry points and no request is created', :aggregate_failures do
      expect do
        post better_together.person_deletion_requests_path(locale: I18n.default_locale),
             params: { person_deletion_request: { requested_reason: 'x' } }
      end.not_to change(BetterTogether::PersonDeletionRequest, :count)
      expect(response).to redirect_to(platform_form_path)

      expect do
        delete better_together.user_registration_path(locale: I18n.default_locale)
      end.not_to change(BetterTogether::PersonDeletionRequest, :count)
      expect(response).to redirect_to(platform_form_path)
    end

    it 'sends, shows and cancels a platform removal request', :aggregate_failures do
      events = []
      subscriber = ActiveSupport::Notifications.subscribe(BetterTogether::PlatformDeletionRequest::EVENT) do |*args|
        events << args.last
      end

      get platform_form_path
      expect(page_html.css('#platform-deletion-request-form').size).to eq(1)

      post better_together.platform_deletion_requests_path(locale: I18n.default_locale),
           params: { platform_deletion_request: { requested_reason: 'Closing down' } }
      request = BetterTogether::PlatformDeletionRequest.find_by!(platform:)
      expect(events.map { |e| e[:request_id] }).to eq([request.id])

      get platform_form_path
      expect(page_html.css("##{ActionView::RecordIdentifier.dom_id(request)}").size).to eq(1)
      expect(page_html.css('#platform-deletion-request-form').size).to eq(0)

      delete better_together.platform_deletion_request_path(request, locale: I18n.default_locale)
      expect(request.reload).to be_cancelled
    ensure
      ActiveSupport::Notifications.unsubscribe(subscriber)
    end

    it 'cannot be deleted by the executor either' do
      request = steward.person.person_deletion_requests.build(requested_at: Time.current, platform:)
      request.save!(validate: false)

      expect { BetterTogether::PersonDeletionExecutor.call(person_deletion_request: request) }
        .to raise_error(BetterTogether::PersonDeletionExecutor::LastStewardError)
    end
  end

  describe 'a steward when another steward exists' do
    it 'can request deletion normally', :aggregate_failures do
      steward = sole_steward
      make_steward(member(email: 'second@example.test'))
      login(steward.email, password)

      post better_together.person_deletion_requests_path(locale: I18n.default_locale),
           params: { person_deletion_request: { requested_reason: 'Moving on' } }

      expect(steward.person.person_deletion_requests.active.count).to eq(1)
      expect(response).to redirect_to(settings_path)
    end
  end
end
