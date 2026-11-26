# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Multi-hostname test support', :skip_host_setup do
  let!(:host_platform) { configure_host_platform }
  let!(:club) { create_platform_on_hostname('club.mds.localhost') }
  let!(:guild) { create_platform_on_hostname('guild.mds.localhost') }

  it 'serves each hostname as its own platform in a request spec' do
    on_hostname('club.mds.localhost') do |platform|
      expect(platform).to eq(club)
      get better_together.home_page_path(locale: I18n.default_locale)
      expect(response).to have_http_status(:ok)
    end

    on_hostname('guild.mds.localhost') do |platform|
      expect(platform).to eq(guild)
      get better_together.home_page_path(locale: I18n.default_locale)
      expect(controller.helpers.host_platform).to eq(guild)
    end
  end

  it 'gives mailer and engine URL code the platform, with no port in its URL' do
    on_hostname('club.mds.localhost') do
      expect(BetterTogether.platform_base_url).to eq('http://club.mds.localhost')
      expect(BetterTogether.platform_base_url).not_to match(/:\d+\z/)
    end
  end

  it 'refuses a hostname with no active domain' do
    expect { on_hostname('nobody.mds.localhost') { nil } }.to raise_error(ArgumentError, /nobody\.mds\.localhost/)
  end

  it 'builds a browser URL on the one server port' do
    allow(Capybara.current_session).to receive(:server).and_return(instance_double(Capybara::Server, port: 4321))

    expect(multi_host_url('club.mds.localhost', '/en')).to eq('http://club.mds.localhost:4321/en')
  end

  describe HostDomainHealing do
    it 'puts back host domain rows a deletion cleanup removed' do
      ensure_host_platform_domain(host_platform)
      rows = described_class.snapshot
      expect(rows.pluck('hostname')).to include('www.example.com')

      BetterTogether::PlatformDomain.where(hostname: 'www.example.com').delete_all
      described_class.restore(rows)

      expect(BetterTogether::PlatformDomain.exists?(hostname: 'www.example.com')).to be(true)
    end
  end
end
