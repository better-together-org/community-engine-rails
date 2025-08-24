# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'better_together/authorizations/edit' do
  let(:person_platform_integration) do
    create(:person_platform_integration)
  end

  before do
    assign(:person_platform_integration, person_platform_integration)
  end

  it 'renders the edit person_platform_integration form' do
    # render

    # assert_select 'form[action=?][method=?]', person_platform_integration_path(person_platform_integration), 'post' do
    #   assert_select 'input[name=?]', 'person_platform_integration[provider]'

    #   assert_select 'input[name=?]', 'person_platform_integration[uid]'

    #   assert_select 'input[name=?]', 'person_platform_integration[access_token]'

    #   assert_select 'input[name=?]', 'person_platform_integration[access_secret]'

    #   assert_select 'input[name=?]', 'person_platform_integration[profile_url]'

    #   assert_select 'input[name=?]', 'person_platform_integration[user_id]'
    #   assert_select 'input[name=?]', 'person_platform_integration[person_id]'
    # end
  end
end
