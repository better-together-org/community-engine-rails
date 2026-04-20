# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::AgreementsController do
  let!(:content_publishing_agreement) do
    BetterTogether::Agreement.find_or_initialize_by(identifier: BetterTogether::PublicVisibilityGate::AGREEMENT_IDENTIFIER).tap do |agreement|
      agreement.title = 'Content Publishing Agreement'
      agreement.active_for_consent = true
      agreement.required_for = :first_publish
      agreement.save!
    end
  end

  let!(:terms_of_service) do
    BetterTogether::Agreement.find_or_initialize_by(identifier: 'terms_of_service').tap do |agreement|
      agreement.title = 'Terms of Service'
      agreement.active_for_consent = true
      agreement.required_for = :registration
      agreement.save!
    end
  end

  before do
    configure_host_platform
  end

  describe 'GET /agreements/new', :as_platform_manager do
    it 'renders the new form with an agreement model' do
      get better_together.new_agreement_path(locale: I18n.locale)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('New Agreement')
      expect(response.body).to include('agreement[title_')
    end
  end

  describe 'GET /agreements/:id/edit', :as_platform_manager do
    let(:agreement) { create(:agreement, slug: "agreement-edit-#{SecureRandom.hex(4)}") }

    it 'renders the edit form with the existing agreement model' do
      get better_together.edit_agreement_path(agreement, locale: I18n.locale)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Edit Agreement')
      expect(response.body).to include(agreement.title.to_s)
    end

    it 'rerenders edit when update validation fails' do
      patch better_together.agreement_path(agreement, locale: I18n.locale),
            params: { agreement: { privacy: '' } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include('Edit Agreement')
    end
  end

  describe 'POST /agreements/:id/accept' do
    context 'when authenticated', :as_user do
      let(:person) { BetterTogether::User.find_by!(email: 'user@example.test').person }

      it 'records first publish agreement acceptance as JSON', :aggregate_failures do
        expect do
          post better_together.accept_agreement_path(content_publishing_agreement, locale: I18n.locale),
               headers: { 'ACCEPT' => 'application/json' }
        end.to change(BetterTogether::AgreementParticipant, :count).by(1)

        expect(response).to have_http_status(:ok)

        payload = JSON.parse(response.body)
        expect(payload['status']).to eq('accepted')
        expect(payload['agreement_identifier']).to eq('content_publishing_agreement')

        participant = BetterTogether::AgreementParticipant.find_by!(participant: person, agreement: content_publishing_agreement)
        expect(participant.acceptance_method).to eq('agreement_review')
        expect(participant.audit_context).to include(
          'flow' => 'publish_modal',
          'source_path' => better_together.accept_agreement_path(content_publishing_agreement, locale: I18n.locale)
        )
      end

      it 'is idempotent for repeat acceptance' do
        post better_together.accept_agreement_path(content_publishing_agreement, locale: I18n.locale),
             headers: { 'ACCEPT' => 'application/json' }

        expect do
          post better_together.accept_agreement_path(content_publishing_agreement, locale: I18n.locale),
               headers: { 'ACCEPT' => 'application/json' }
        end.not_to change(BetterTogether::AgreementParticipant, :count)

        expect(response).to have_http_status(:ok)
      end

      it 'rejects non publishing agreements' do
        expect do
          post better_together.accept_agreement_path(terms_of_service, locale: I18n.locale),
               headers: { 'ACCEPT' => 'application/json' }
        end.not_to change(BetterTogether::AgreementParticipant, :count)

        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end

  describe 'GET /agreements/:id' do
    it 'renders linked content contributor agreement page content inside the turbo frame', :aggregate_failures do
      BetterTogether::AgreementBuilder.seed_data

      seeded_agreement = BetterTogether::Agreement.find_by!(identifier: 'content_publishing_agreement')
      expect(seeded_agreement.page).to be_present

      get better_together.agreement_path(seeded_agreement.id, locale: I18n.locale),
          headers: { 'Turbo-Frame' => 'agreement_modal_frame' }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Content Contributor Agreement')
      expect(response.body).to include('This Content Contributor Agreement')
      expect(response.body).not_to include('<strong>Description:</strong>')
    end
  end
end
