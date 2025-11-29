# frozen_string_literal: true

require 'rails_helper'

module BetterTogether # rubocop:disable Metrics/ModuleLength
  RSpec.describe SocialMediaAccount do
    describe 'factory' do
      it 'creates a valid social media account' do
        account = build(:social_media_account)
        expect(account).to be_valid
      end

      it 'creates valid accounts for different platforms' do
        %i[instagram linkedin youtube tiktok reddit].each do |platform_trait|
          account = build(:social_media_account, platform_trait)
          expect(account).to be_valid
        end
      end
    end

    describe 'associations' do
      it { is_expected.to belong_to(:contact_detail).class_name('BetterTogether::ContactDetail').touch(true) }
    end

    describe 'validations' do
      subject { build(:social_media_account) }

      it { is_expected.to validate_presence_of(:platform) }
      it { is_expected.to validate_inclusion_of(:platform).in_array(described_class::PLATFORMS) }

      it 'requires handle if url is not present' do
        account = build(:social_media_account, handle: nil, url: nil)
        expect(account).not_to be_valid
        expect(account.errors[:handle]).to be_present
      end

      it 'allows missing handle if url is present' do
        account = build(:social_media_account, handle: nil, url: 'https://example.com/profile')
        expect(account).to be_valid
      end

      it 'validates url format when present' do
        account = build(:social_media_account, url: 'not-a-valid-url')
        expect(account).not_to be_valid
        expect(account.errors[:url]).to be_present
      end

      it 'allows valid http url' do
        account = build(:social_media_account, url: 'http://example.com/profile')
        expect(account).to be_valid
      end

      it 'allows valid https url' do
        account = build(:social_media_account, url: 'https://example.com/profile')
        expect(account).to be_valid
      end

      it 'validates uniqueness of platform scoped to contact_detail' do
        contact_detail = create(:contact_detail)
        create(:social_media_account, contact_detail: contact_detail, platform: 'Facebook')
        duplicate = build(:social_media_account, contact_detail: contact_detail, platform: 'Facebook')

        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:platform]).to include('account already exists for this contact detail')
      end

      it 'allows same platform for different contact_details' do
        contact1 = create(:contact_detail)
        contact2 = create(:contact_detail)
        create(:social_media_account, contact_detail: contact1, platform: 'Facebook')
        account2 = build(:social_media_account, contact_detail: contact2, platform: 'Facebook')

        expect(account2).to be_valid
      end
    end

    describe 'url generation' do
      it 'generates url from handle for Facebook' do
        account = create(:social_media_account, platform: 'Facebook', handle: 'johndoe', url: nil)
        expect(account.url).to eq('https://www.facebook.com/johndoe')
      end

      it 'generates url from handle for Instagram' do
        account = create(:social_media_account, platform: 'Instagram', handle: 'johndoe', url: nil)
        expect(account.url).to eq('https://www.instagram.com/johndoe')
      end

      it 'generates url from handle for LinkedIn' do
        account = create(:social_media_account, platform: 'LinkedIn', handle: 'johndoe', url: nil)
        expect(account.url).to eq('https://www.linkedin.com/in/johndoe')
      end

      it 'generates url from handle for YouTube' do
        account = create(:social_media_account, platform: 'YouTube', handle: 'johndoe', url: nil)
        expect(account.url).to eq('https://www.youtube.com/johndoe')
      end

      it 'generates url from handle for TikTok' do
        account = create(:social_media_account, platform: 'TikTok', handle: 'johndoe', url: nil)
        expect(account.url).to eq('https://www.tiktok.com/@johndoe')
      end

      it 'generates url from handle for Reddit' do
        account = create(:social_media_account, platform: 'Reddit', handle: 'johndoe', url: nil)
        expect(account.url).to eq('https://www.reddit.com/user/johndoe')
      end

      it 'does not override existing url' do
        existing_url = 'https://custom.url/profile'
        account = create(:social_media_account, platform: 'Facebook', handle: 'johndoe', url: existing_url)
        expect(account.url).to eq(existing_url)
      end

      it 'regenerates url when handle changes and url is blank' do
        account = create(:social_media_account, platform: 'Facebook', handle: 'johndoe', url: nil)
        original_url = account.url

        account.update(handle: 'janedoe', url: nil)
        expect(account.url).to eq('https://www.facebook.com/janedoe')
        expect(account.url).not_to eq(original_url)
      end

      it 'regenerates url when platform changes with handle present and url blank' do
        account = create(:social_media_account, platform: 'Facebook', handle: 'johndoe', url: nil)
        account.update(platform: 'Instagram', url: nil)
        expect(account.url).to eq('https://www.instagram.com/johndoe')
      end
    end

    describe 'handle sanitization' do
      it 'removes leading @ from handle' do
        account = create(:social_media_account, platform: 'Instagram', handle: '@johndoe', url: nil)
        expect(account.url).to eq('https://www.instagram.com/johndoe')
      end

      it 'parameterizes handle' do
        account = create(:social_media_account, platform: 'Facebook', handle: 'John Doe', url: nil)
        expect(account.url).to eq('https://www.facebook.com/john-doe')
      end

      it 'strips whitespace from handle' do
        account = create(:social_media_account, platform: 'Facebook', handle: '  johndoe  ', url: nil)
        expect(account.url).to eq('https://www.facebook.com/johndoe')
      end
    end

    describe '#to_s' do
      it 'returns platform and handle' do
        account = build(:social_media_account, platform: 'Facebook', handle: 'johndoe')
        expect(account.to_s).to eq('Facebook: johndoe')
      end
    end

    describe 'privacy concern' do
      it 'includes Privacy concern' do
        expect(described_class.included_modules).to include(BetterTogether::Privacy)
      end

      it 'has default privacy level' do
        account = create(:social_media_account)
        expect(account.privacy).to eq('public')
      end

      it 'can be set to private' do
        account = create(:social_media_account, :private)
        expect(account.privacy).to eq('private')
      end
    end
  end
end
