# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'BetterTogether::PersonLinkedSeeds' do
  let(:locale) { I18n.default_locale }
  let(:recipient_person) { create(:better_together_person) }
  let(:recipient_user) { create(:better_together_user, :confirmed, person: recipient_person) }
  let(:visible_person_link) { create(:better_together_person_link, target_person: recipient_person) }
  let(:visible_grant) { create(:better_together_person_access_grant, person_link: visible_person_link) }
  let!(:visible_seed) do
    create(
      :better_together_person_linked_seed,
      recipient_person:,
      person_access_grant: visible_grant,
      payload: JSON.generate('title' => 'Private Shared Post', 'body' => 'Only the recipient should see this.')
    )
  end
  let!(:other_seed) { create(:better_together_person_linked_seed) }

  before do
    sign_in recipient_user
  end

  describe 'GET /linked-seeds' do
    it 'returns 404 for unauthenticated users' do
      logout

      get better_together.person_linked_seeds_path(locale:)

      expect(response).to have_http_status(:not_found)
    end

    it 'shows only linked seeds visible to the current recipient' do
      get better_together.person_linked_seeds_path(locale:)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Private Shared Post')
      expect(response.body).not_to include(other_seed.identifier)
    end
  end

  describe 'GET /linked-seeds/:id' do
    it 'returns 404 for unauthenticated users' do
      logout

      get better_together.person_linked_seed_path(locale:, id: visible_seed)

      expect(response).to have_http_status(:not_found)
    end

    it 'shows a recipient-visible linked seed' do
      get better_together.person_linked_seed_path(locale:, id: visible_seed)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Private Shared Post')
      expect(response.body).to include('Only the recipient should see this.')
    end

    it 'does not allow access to a linked seed belonging to another recipient' do
      get better_together.person_linked_seed_path(locale:, id: other_seed)

      expect(response).to have_http_status(:not_found)
    end
  end
end
