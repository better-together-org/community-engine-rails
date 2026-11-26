# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Multi-hostname browser support', :js, :multi_host, :skip_host_setup do
  let!(:host_platform) { configure_host_platform }
  let!(:club) { create_platform_on_hostname('club.mds.localhost') }
  let!(:guild) { create_platform_on_hostname('guild.mds.localhost') }

  it 'reaches two hostnames through the one server port' do
    visit multi_host_url('club.mds.localhost', "/#{I18n.default_locale}")
    expect(page).to have_current_path(%r{\A/#{I18n.default_locale}}, wait: 10)
    club_port = URI(page.current_url).port

    visit multi_host_url('guild.mds.localhost', "/#{I18n.default_locale}")
    expect(URI(page.current_url).host).to eq('guild.mds.localhost')
    expect(URI(page.current_url).port).to eq(club_port)
  end
end
