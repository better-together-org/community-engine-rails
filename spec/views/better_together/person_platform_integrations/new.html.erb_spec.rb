# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'better_together/authorizations/new' do
  before do
    assign(:person_platform_integration, create(:person_platform_integration))
  end

  it 'renders new person_platform_integration form' do # rubocop:todo RSpec/NoExpectationExample
    # render

    # assert_select 'form[action=?][method=?]', person_platform_integrations_path, 'post' do
    #   assert_select 'input[name=?]', 'person_platform_integration[provider]'

    #   assert_select 'input[name=?]', 'person_platform_integration[uid]'

    #   assert_select 'input[name=?]', 'person_platform_integration[token]'

    #   assert_select 'input[name=?]', 'person_platform_integration[secret]'

    #   assert_select 'input[name=?]', 'person_platform_integration[profile_url]'

    #   assert_select 'input[name=?]', 'person_platform_integration[user_id]'
    # end
  end
end
