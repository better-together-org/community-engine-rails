# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::ImageHelper do
  include described_class

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
        allow(person).to receive(:profile_image).and_return(profile_image_double)

        # Stub the profile_image_url method to return our test URL
        allow(person).to receive(:profile_image_url).and_return('http://example.com/optimized.jpg')
      end

      it 'uses the optimized profile_image_url method' do
        expect(person).to receive(:profile_image_url).with(size: 300).and_return('http://example.com/optimized.jpg')
        result = profile_image_tag(person)
        expect(result).to include('src="http://example.com/optimized.jpg"')
        expect(result).to include('class="profile-image rounded-circle')
      end

      it 'respects custom size parameter' do
        expect(person).to receive(:profile_image_url).with(size: 150).and_return('http://example.com/optimized.jpg')
        profile_image_tag(person, size: 150)
      end
    end
  end
end
