# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'BetterTogether::CallsForInterestController', :as_user do
  let(:locale) { I18n.default_locale }

  describe 'GET /calls_for_interest/:id' do
    let(:call_for_interest) do
      create(:call_for_interest, privacy: 'public', starts_at: 1.day.from_now)
    end

    before do
      citation = create(:citation, citeable: call_for_interest, title: 'Outreach brief', reference_key: 'brief-1')
      claim = create(:claim, claimable: call_for_interest, statement: 'The call is backed by community outreach.')
      create(:evidence_link, claim:, citation:, relation_type: 'documents')
    end

    it 'renders claims and bibliography on the show page' do
      get better_together.call_for_interest_path(call_for_interest, locale:)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Claims and Supporting Evidence')
      expect(response.body).to include('Evidence and Citations')
      expect(response.body).to include('The call is backed by community outreach.')
      expect(response.body).to include('Outreach brief')
    end
  end
end
