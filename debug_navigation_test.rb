# frozen_string_literal: true

# Debug script to investigate the navigation areas controller issue

require 'rails_helper'

# Simple test to debug the issue
RSpec.describe 'Debug NavigationAreas', type: :request do
  include RequestSpecHelper

  let(:locale) { I18n.default_locale }

  before do
    configure_host_platform
    login('manager@example.test', 'password12345')
  end

  it 'debug delete and follow redirect' do
    area = create(:better_together_navigation_area, protected: false)

    puts "Created area: #{area.inspect}"

    delete better_together.navigation_area_path(locale:, id: area.slug)
    puts "Delete response status: #{response.status}"
    puts "Delete response headers: #{response.headers['Location']}"

    if response.status == 302
      follow_redirect!
      puts "Redirect response status: #{response.status}"
      puts "Response body: #{response.body}" if response.status == 500
    end
  end
end
