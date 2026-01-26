# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Platform membership management', :as_platform_manager do
  let(:platform_identifier) { "platform-#{SecureRandom.hex(6)}" }
  let(:platform) do
    create(:better_together_platform,
           identifier: platform_identifier,
           host_url: "http://#{platform_identifier}.test")
  end
  let(:member) { create(:better_together_person, name: "Sean O'Connor") } # Explicit apostrophe
  let(:role) { create(:better_together_role, resource_type: 'BetterTogether::Platform', name: "Community O'Malley") } # Explicit apostrophe
  let!(:membership) { create(:better_together_person_platform_membership, joinable: platform, member: member, role: role) }

  describe 'GET /platforms/:platform_id/person_platform_memberships/:id/edit' do
    it 'renders the edit form in a turbo frame' do
      get edit_platform_person_platform_membership_path(platform, membership, locale: I18n.locale)

      expect(response).to have_http_status(:success)
      expect(response.body).to include('turbo-frame')
      expect(response.body).to include('Editing membership')
      expect_html_content(membership.member.name) # Use HTML assertion helper
    end
  end

  describe 'DELETE /platforms/:platform_id/person_platform_memberships/:id' do
    it 'removes the membership and updates the view' do
      expect do
        delete platform_person_platform_membership_path(platform, membership, locale: I18n.locale),
               headers: { 'Accept' => 'text/vnd.turbo-stream.html' }
      end.to change(BetterTogether::PersonPlatformMembership, :count).by(-1)

      expect(response).to have_http_status(:success)
      expect(response.body).to include('turbo-stream')
    end

    it 'sends a removal email notification' do
      expect do
        delete platform_person_platform_membership_path(platform, membership, locale: I18n.locale),
               headers: { 'Accept' => 'text/vnd.turbo-stream.html' }
      end.to have_enqueued_mail(BetterTogether::MembershipMailer, :removed)

      # Verify the mailer was enqueued with expected parameters
      enqueued_job = enqueued_jobs.last
      expect(enqueued_job['job_class']).to eq('ActionMailer::MailDeliveryJob')

      job_params = enqueued_job['arguments'][3]['params']
      expect(job_params).to include('recipient', 'joinable', 'role', 'member_name')
      expect(job_params['recipient']).to include('email', 'locale', 'time_zone')
    end
  end

  describe 'PUT /platforms/:platform_id/person_platform_memberships/:id' do
    let(:new_role) { create(:better_together_role, resource_type: 'BetterTogether::Platform', name: 'Updated Role') }

    it 'updates the membership and returns the updated member card' do
      put platform_person_platform_membership_path(platform, membership, locale: I18n.locale),
          params: { person_platform_membership: { role_id: new_role.id } },
          headers: {
            'Accept' => 'text/vnd.turbo-stream.html',
            'Turbo-Frame' => "member_card_person_platform_membership_#{membership.id.tr('-', '_')}"
          }

      expect(response).to have_http_status(:success)
      expect(response.body).to include('turbo-stream')
      expect(membership.reload.role).to eq(new_role)
    end

    it 'sends an update email notification when role changes' do
      expect do
        put platform_person_platform_membership_path(platform, membership, locale: I18n.locale),
            params: { person_platform_membership: { role_id: new_role.id } },
            headers: {
              'Accept' => 'text/vnd.turbo-stream.html',
              'Turbo-Frame' => "member_card_person_platform_membership_#{membership.id.tr('-', '_')}"
            }
      end.to have_enqueued_mail(BetterTogether::MembershipMailer, :updated)

      # Verify the mailer was enqueued with expected parameters
      enqueued_job = enqueued_jobs.last
      expect(enqueued_job['job_class']).to eq('ActionMailer::MailDeliveryJob')

      job_params = enqueued_job['arguments'][3]['params']
      expect(job_params).to include('recipient', 'joinable', 'old_role', 'new_role', 'member_name')
      expect(job_params['recipient']).to include('email', 'locale', 'time_zone')
    end
  end
end
