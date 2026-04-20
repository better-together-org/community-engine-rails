# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::ImageHelper do
  include described_class

  describe '#cover_image_tag' do
    let(:entity) { instance_double(BetterTogether::Person) }
    let(:cover_image) { double('cover_image', attached?: true) } # rubocop:todo RSpec/VerifiedDoubles
    let(:attachment) { double('attachment') } # rubocop:todo RSpec/VerifiedDoubles

    before do
      allow(entity).to receive_messages(
        cover_image: cover_image,
        optimized_cover_image: attachment,
        to_s: 'Test Person',
        name: 'Test Person'
      )
      allow(self).to receive(:rails_storage_proxy_url).with(attachment).and_return('/rails/active_storage/representations/proxy/cover')
    end

    it 'renders the optimized cover image proxy path without inline processing' do
      result = cover_image_tag(entity)

      expect(result).to include('src="/rails/active_storage/representations/proxy/cover"')
      expect(result).to include('class="cover-image ')
    end
  end

  describe '#profile_image_tag' do
    let(:person) { create(:better_together_person) }

    context 'when person has no profile image' do
      it 'returns a default image tag' do
        result = profile_image_tag(person)
        expect(result).to include('class="profile-image rounded-circle')
        expect(result).to include('alt="Profile Image"')
      end
    end

    context 'when person has profile_image_url method' do
      before do
        # Mock profile_image.attached? to return true
        profile_image_double = double('profile_image', attached?: true) # rubocop:todo RSpec/VerifiedDoubles

        # Stub the profile_image_url method to return our test proxy path
        allow(person).to receive_messages(profile_image: profile_image_double,
                                          profile_image_url: '/rails/active_storage/representations/proxy/test')
      end

      it 'uses the optimized profile_image_url method' do
        allow(person).to receive(:profile_image_url).with(size: 300).and_return('/rails/active_storage/representations/proxy/test')
        result = profile_image_tag(person)
        expect(result).to include('src="http://test.host/rails/active_storage/representations/proxy/test"')
        expect(result).to include('class="profile-image rounded-circle')
      end

      xit 'respects custom size parameter' do # rubocop:disable RSpec/PendingWithoutReason
        allow(person).to receive(:profile_image_url).with(size: 150).and_return('/rails/active_storage/representations/proxy/test')
        result = profile_image_tag(person, size: 150)

        expect(result).to include('150')
      end
    end
  end
end
