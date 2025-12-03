# frozen_string_literal: true

require 'rails_helper'

module BetterTogether
  RSpec.describe Metrics::Share do
    describe 'factory' do
      it 'creates a valid share' do
        community = create(:community)
        share = create(:metrics_share,
                       shareable: community,
                       platform: 'facebook',
                       url: 'https://facebook.com/share',
                       shared_at: Time.current,
                       locale: 'en')
        expect(share).to be_valid
        expect(share.platform).to eq('facebook')
      end
    end

    describe 'associations' do
      it { is_expected.to belong_to(:shareable).optional }
    end

    describe 'validations' do
      describe 'platform' do
        it 'requires platform to be present' do
          share = build(:metrics_share, platform: nil)
          expect(share).not_to be_valid
          expect(share.errors[:platform]).to include("can't be blank")
        end

        it 'validates platform is in allowed list' do
          share = build(:metrics_share, platform: 'invalid_platform')
          expect(share).not_to be_valid
          expect(share.errors[:platform]).to include('is not included in the list')
        end

        it 'accepts valid platforms' do
          valid_platforms = %w[facebook bluesky linkedin pinterest reddit whatsapp]

          valid_platforms.each do |platform|
            share = build(:metrics_share, platform: platform)
            expect(share).to be_valid, "Expected #{platform} to be valid"
          end
        end
      end

      describe 'url' do
        it 'requires url to be present' do
          share = build(:metrics_share, url: nil)
          expect(share).not_to be_valid
          expect(share.errors[:url]).to include("can't be blank")
        end

        it 'validates url format' do
          share = build(:metrics_share, url: 'not-a-url')
          expect(share).not_to be_valid
          expect(share.errors[:url]).to include('is invalid')
        end

        it 'accepts valid HTTP URLs' do
          share = build(:metrics_share, url: 'http://example.com/share')
          expect(share).to be_valid
        end

        it 'accepts valid HTTPS URLs' do
          share = build(:metrics_share, url: 'https://example.com/share')
          expect(share).to be_valid
        end
      end

      describe 'shared_at' do
        it 'requires shared_at to be present' do
          share = build(:metrics_share, shared_at: nil)
          expect(share).not_to be_valid
          expect(share.errors[:shared_at]).to include("can't be blank")
        end
      end

      describe 'locale' do
        it 'requires locale to be present' do
          share = build(:metrics_share, locale: nil)
          expect(share).not_to be_valid
          expect(share.errors[:locale]).to include("can't be blank")
        end

        it 'validates locale is in available locales' do
          share = build(:metrics_share, locale: 'invalid')
          expect(share).not_to be_valid
          expect(share.errors[:locale]).to include('is not included in the list')
        end

        it 'accepts valid locales' do
          I18n.available_locales.each do |locale|
            share = build(:metrics_share, locale: locale.to_s)
            expect(share).to be_valid, "Expected #{locale} to be valid"
          end
        end
      end
    end

    describe 'constants' do
      it 'defines SHAREABLE_PLATFORMS' do
        expect(described_class::SHAREABLE_PLATFORMS).to eq(%w[facebook bluesky linkedin pinterest reddit whatsapp])
      end
    end
  end
end
