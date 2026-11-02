# frozen_string_literal: true

require 'rails_helper'

# DOM contract for the category colour field that the docs screenshot targets.
RSpec.describe 'Category colour field DOM contract', :as_platform_manager, type: :request do # rubocop:disable RSpec/DescribeClass
  it 'renders a hex colour input on the category form with a saved value' do
    category = create(:event_category, color: '#0072B2')

    get "/#{I18n.default_locale}/host/categories/#{category.slug}/edit"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('name="category[color]"')
    expect(response.body).to include('value="#0072B2"')
    expect(response.body).to include('pattern="#[0-9A-Fa-f]{6}"')
  end
end
