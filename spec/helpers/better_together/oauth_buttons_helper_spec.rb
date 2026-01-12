# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::OauthButtonsHelper do
  describe '#oauth_provider_button_class' do
    it 'returns btn-dark for GitHub' do
      expect(helper.oauth_provider_button_class('github')).to eq('btn btn-dark')
    end

    it 'returns btn-outline-danger for Google' do
      expect(helper.oauth_provider_button_class('google')).to eq('btn btn-outline-danger')
      expect(helper.oauth_provider_button_class('google_oauth2')).to eq('btn btn-outline-danger')
    end

    it 'returns btn-primary for Facebook' do
      expect(helper.oauth_provider_button_class('facebook')).to eq('btn btn-primary')
    end

    it 'returns btn-dark for Twitter/X' do
      expect(helper.oauth_provider_button_class('twitter')).to eq('btn btn-dark')
      expect(helper.oauth_provider_button_class('x')).to eq('btn btn-dark')
    end

    it 'returns btn-primary for LinkedIn' do
      expect(helper.oauth_provider_button_class('linkedin')).to eq('btn btn-primary')
    end

    it 'returns btn-info for Microsoft' do
      expect(helper.oauth_provider_button_class('microsoft')).to eq('btn btn-info')
      expect(helper.oauth_provider_button_class('microsoft_office365')).to eq('btn btn-info')
    end

    it 'returns btn-secondary for unknown providers' do
      expect(helper.oauth_provider_button_class('unknown')).to eq('btn btn-secondary')
    end

    it 'handles symbol input' do
      expect(helper.oauth_provider_button_class(:github)).to eq('btn btn-dark')
    end
  end

  describe '#oauth_provider_icon_class' do
    it 'returns fa-brands fa-github for GitHub' do
      expect(helper.oauth_provider_icon_class('github')).to eq('fa-brands fa-github')
    end

    it 'returns fa-brands fa-google for Google' do
      expect(helper.oauth_provider_icon_class('google')).to eq('fa-brands fa-google')
      expect(helper.oauth_provider_icon_class('google_oauth2')).to eq('fa-brands fa-google')
    end

    it 'returns fa-brands fa-facebook for Facebook' do
      expect(helper.oauth_provider_icon_class('facebook')).to eq('fa-brands fa-facebook')
    end

    it 'returns fa-brands fa-x-twitter for Twitter/X' do
      expect(helper.oauth_provider_icon_class('twitter')).to eq('fa-brands fa-x-twitter')
      expect(helper.oauth_provider_icon_class('x')).to eq('fa-brands fa-x-twitter')
    end

    it 'returns fa-brands fa-linkedin for LinkedIn' do
      expect(helper.oauth_provider_icon_class('linkedin')).to eq('fa-brands fa-linkedin')
    end

    it 'returns fa-brands fa-microsoft for Microsoft' do
      expect(helper.oauth_provider_icon_class('microsoft')).to eq('fa-brands fa-microsoft')
      expect(helper.oauth_provider_icon_class('microsoft_office365')).to eq('fa-brands fa-microsoft')
    end

    it 'returns fa-solid fa-plug for unknown providers' do
      expect(helper.oauth_provider_icon_class('unknown')).to eq('fa-solid fa-plug')
    end

    it 'handles symbol input' do
      expect(helper.oauth_provider_icon_class(:github)).to eq('fa-brands fa-github')
    end
  end
end
