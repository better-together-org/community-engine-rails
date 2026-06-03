# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'BetterTogether::AgreementsController', :as_user do
  let(:locale) { I18n.default_locale }

  describe 'GET /agreements/:id' do
    let(:agreement) { create(:agreement, privacy: 'public', protected: false) }

    before do
      citation = create(:citation, citeable: agreement, title: 'Governance memo', reference_key: 'governance-memo')
      claim = create(:claim, claimable: agreement, statement: 'This agreement reflects the current governance policy.')
      create(:evidence_link, claim:, citation:, relation_type: 'documents')
    end

    it 'renders claims and bibliography on the show page' do
      get better_together.agreement_path(agreement, locale:)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Claims and Supporting Evidence')
      expect(response.body).to include('Evidence and Citations')
      expect(response.body).to include('Governance memo')
    end
  end
end
