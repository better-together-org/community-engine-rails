# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'better_together/authorizations/index' do
  before do
    assign(:person_platform_integrations, create_list(:person_platform_integration, 3))
  end

  it 'renders a list of better_together/authorizations' do
    # render
    # cell_selector = Rails::VERSION::STRING >= '7' ? 'div>p' : 'tr>td'
    # assert_select cell_selector, text: Regexp.new('Provider'.to_s), count: 2
    # assert_select cell_selector, text: Regexp.new('Uid'.to_s), count: 2
    # assert_select cell_selector, text: Regexp.new('Token'.to_s), count: 2
    # assert_select cell_selector, text: Regexp.new('Secret'.to_s), count: 2
    # assert_select cell_selector, text: Regexp.new('Profile Url'.to_s), count: 2
    # assert_select cell_selector, text: Regexp.new(nil.to_s), count: 2
  end
end
