# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'BetterTogether::PeopleController', :as_platform_manager do
  let(:locale) { I18n.default_locale }

  describe 'GET /:locale/.../host/p/:id' do
    let!(:person) { create(:better_together_person) }

    it 'renders show' do
      get better_together.person_path(locale:, id: person.slug)
      expect(response).to have_http_status(:ok)
    end

    it 'renders edit' do
      get better_together.edit_person_path(locale:, id: person.slug)
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'PATCH /:locale/.../host/p/:id' do
    let!(:person) { create(:better_together_person) }

    # rubocop:todo RSpec/MultipleExpectations
    it 'updates name and redirects' do # rubocop:todo RSpec/ExampleLength, RSpec/MultipleExpectations
      # rubocop:enable RSpec/MultipleExpectations
      patch better_together.person_path(locale:, id: person.slug), params: {
        person: { name: 'Updated Name' }
      }
      expect(response).to have_http_status(:see_other)
      follow_redirect!
      expect(response).to have_http_status(:ok)
    end
  end
end
