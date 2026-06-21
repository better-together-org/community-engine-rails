# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'BetterTogether::CallsForInterestController', :as_user do
  let(:locale) { I18n.default_locale }

  def manager_calls_for_interest_path
    "/#{locale}/#{BetterTogether.route_scope_path}/calls_for_interest"
  end

  def manager_call_for_interest_path(call_for_interest)
    "#{manager_calls_for_interest_path}/#{call_for_interest.to_param}"
  end

  describe 'GET /calls_for_interest/:id' do
    let(:call_for_interest) do
      create(:call_for_interest, privacy: 'public', starts_at: 1.day.from_now)
    end

    before do
      citation = create(:citation, citeable: call_for_interest, title: 'Outreach brief', reference_key: 'brief-1')
      claim = create(:claim, claimable: call_for_interest, statement: 'The call is backed by community outreach.')
      create(:evidence_link, claim:, citation:, relation_type: 'documents')
    end

    it 'keeps claims and bibliography out of the public show page' do
      get better_together.call_for_interest_path(call_for_interest, locale:)

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include('Claims and Supporting Evidence')
      expect(response.body).not_to include('Evidence and Citations')
      expect(response.body).not_to include('The call is backed by community outreach.')
      expect(response.body).not_to include('Outreach brief')
    end
  end

  describe 'manager CRUD flows', :as_platform_manager do
    let(:call_for_interest) do
      create(:better_together_call_for_interest,
             privacy: 'private',
             name: 'Coverage Call',
             description: 'Initial interest description')
    end

    it 'creates a call for interest' do
      expect do
        post manager_calls_for_interest_path, params: {
          call_for_interest: {
            name_en: 'Coverage Created Call',
            description_en: 'New interest workflow',
            privacy: 'private',
            starts_at: 1.day.from_now.iso8601
          }
        }
      end.to change(BetterTogether::CallForInterest, :count).by(1)

      created_call = BetterTogether::CallForInterest.order(:created_at).last

      expect(response).to be_redirect
      expect(created_call.name).to eq('Coverage Created Call')
      expect(created_call.description.to_plain_text).to include('New interest workflow')
    end

    it 'updates an existing call for interest' do
      patch manager_call_for_interest_path(call_for_interest), params: {
        call_for_interest: {
          name_en: 'Updated Coverage Call',
          description_en: 'Updated interest description'
        }
      }

      expect(response).to be_redirect
      expect(call_for_interest.reload.name).to eq('Updated Coverage Call')
      expect(call_for_interest.description.to_plain_text).to include('Updated interest description')
    end

    it 'destroys an unprotected call for interest' do
      delete manager_call_for_interest_path(call_for_interest)

      expect(response).to be_redirect
      expect(BetterTogether::CallForInterest.exists?(call_for_interest.id)).to be(false)
    end
  end
end
