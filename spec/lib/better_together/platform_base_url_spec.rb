# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Per-platform engine URLs' do # rubocop:disable RSpec/DescribeClass, RSpec/DescribedClass
  let(:hosted) do
    create(:better_together_platform, host: false, privacy: 'public', host_url: 'https://club.example.test')
  end

  before { configure_host_platform }

  after { Current.reset }

  describe 'BetterTogether.platform_base_url' do
    it "is the platform's own address, not the configured global one" do
      expect(BetterTogether.platform_base_url(hosted)).to eq(hosted.resolved_host_url)
      expect(BetterTogether.platform_base_url(hosted)).not_to eq(BetterTogether.base_url)
    end

    it 'follows Current.platform when none is passed' do
      Current.platform = hosted

      expect(BetterTogether.platform_base_url).to eq(hosted.resolved_host_url)
    end

    it 'falls back to the configured base_url with no platform' do
      Current.reset

      expect(BetterTogether.platform_base_url(nil)).to eq(BetterTogether.base_url)
    end

    it 'builds locale, password reset and confirmation URLs on the platform' do
      root = hosted.resolved_host_url

      expect(BetterTogether.base_url_with_locale(platform: hosted)).to eq("#{root}/#{I18n.locale}")
      expect(BetterTogether.new_user_password_url(platform: hosted)).to start_with(root)
      expect(BetterTogether.user_confirmation_url(platform: hosted)).to start_with(root)
    end
  end

  describe 'Platform#url_options' do
    it 'splits the platform address into host, protocol and port' do
      hosted.update_columns(host_url: 'http://club.example.test:3001')
      hosted.platform_domains.destroy_all

      expect(hosted.reload.url_options).to eq(host: 'club.example.test', protocol: 'http', port: 3001)
    end

    it 'omits the default port' do
      hosted.platform_domains.destroy_all
      hosted.update_columns(host_url: 'https://club.example.test')

      expect(hosted.reload.url_options).to eq(host: 'club.example.test', protocol: 'https')
    end

    it 'is empty when the platform has no usable address' do
      hosted.platform_domains.destroy_all
      hosted.update_columns(host_url: '')

      expect(hosted.reload.url_options).to eq({})
    end
  end

  describe 'Page#url' do
    it "is on the page's own platform" do
      page = create(:better_together_page, platform: hosted)

      expect(page.url).to start_with(hosted.resolved_host_url)
    end
  end

  describe 'confirmation instructions' do
    it "link to the user's own platform" do
      user = create(:better_together_user, platform: hosted)
      captured = nil
      allow(user).to receive(:send_devise_notification) { |_n, _t, opts| captured = opts }

      user.send_confirmation_instructions

      expect(captured[:confirmation_url]).to start_with(hosted.resolved_host_url)
    end
  end
end
