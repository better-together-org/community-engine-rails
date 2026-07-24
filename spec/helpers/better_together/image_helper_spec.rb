# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::ImageHelper do
  include described_class
  include BetterTogether::ApplicationHelper

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
      allow(self).to receive(:storage_proxy_url_for).with(attachment).and_return('http://test.host/rails/active_storage/representations/proxy/cover')
    end

    it 'renders the optimized cover image proxy path without inline processing' do
      result = cover_image_tag(entity)

      expect(result).to include('src="http://test.host/rails/active_storage/representations/proxy/cover"')
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

      it 'always includes width/height attributes, which app CSS still overrides by specificity' do
        result = profile_image_tag(person, size: 42)
        expect(result).to include('width="42"')
        expect(result).to include('height="42"')
      end

      it 'does not add an inline size style outside a mailer view' do
        result = profile_image_tag(person)
        expect(result).not_to match(/style="[^"]*width:/)
      end

      it 'adds an inline size style only in a mailer view, where external CSS is stripped' do
        allow(self).to receive(:controller).and_return(ActionMailer::Base.new)
        result = profile_image_tag(person, size: 42)
        expect(result).to include('style="width: 42px; height: 42px;')
      end
    end

    context 'when person has a profile image variant' do
      let(:variant_double) { double('profile_image_variant') } # rubocop:todo RSpec/VerifiedDoubles

      before do
        # Mock profile_image.attached? to return true
        profile_image_double = double('profile_image', attached?: true) # rubocop:todo RSpec/VerifiedDoubles

        allow(person).to receive_messages(profile_image: profile_image_double,
                                          profile_image_variant: variant_double)
      end

      it 'uses the profile image variant through the shared proxy helper' do
        allow(person).to receive(:profile_image_variant).with(300).and_return(variant_double)
        allow(self).to receive(:storage_proxy_url_for).with(variant_double).and_return(
          'http://test.host/rails/active_storage/representations/proxy/test'
        )
        result = profile_image_tag(person)
        expect(result).to include('src="http://test.host/rails/active_storage/representations/proxy/test"')
        expect(result).to include('class="profile-image rounded-circle')
      end

      xit 'respects custom size parameter' do # rubocop:disable RSpec/PendingWithoutReason
        allow(person).to receive(:profile_image_variant).with(150).and_return(variant_double)
        allow(self).to receive(:storage_proxy_url_for).with(variant_double).and_return(
          'http://test.host/rails/active_storage/representations/proxy/test'
        )
        result = profile_image_tag(person, size: 150)

        expect(result).to include('150')
      end
    end

    context 'when a platform has a profile image but no custom image helpers' do
      let(:platform) { instance_double(BetterTogether::Platform, name: 'Test Platform', to_s: 'Test Platform') }
      let(:profile_image_double) { double('profile_image', attached?: true, content_type: 'image/png') } # rubocop:todo RSpec/VerifiedDoubles
      let(:variant_double) { double('variant') } # rubocop:todo RSpec/VerifiedDoubles

      before do
        allow(platform).to receive(:profile_image).and_return(profile_image_double)
        allow(profile_image_double).to receive(:variant).with(resize_to_fill: [300, 300]).and_return(variant_double)
        allow(self).to receive(:storage_proxy_url_for).with(variant_double).and_return(
          'http://test.host/rails/active_storage/representations/proxy/platform'
        )
      end

      it 'renders a proxied variant URL for the platform profile image' do
        result = profile_image_tag(platform, alt: platform.name)

        expect(result).to include('src="http://test.host/rails/active_storage/representations/proxy/platform"')
      end
    end

    context 'when a community has an optimized profile image helper' do
      let(:community) { instance_double(BetterTogether::Community, name: 'Test Community', to_s: 'Test Community') }
      let(:profile_image_double) { double('profile_image', attached?: true) } # rubocop:todo RSpec/VerifiedDoubles
      let(:optimized_profile_image) { double('optimized_profile_image') } # rubocop:todo RSpec/VerifiedDoubles

      before do
        allow(community).to receive_messages(
          profile_image: profile_image_double,
          optimized_profile_image:
        )
        allow(self).to receive(:storage_proxy_url_for).with(optimized_profile_image).and_return(
          'http://test.host/rails/active_storage/representations/proxy/community'
        )
      end

      it 'renders a proxied optimized community profile image URL' do
        result = profile_image_tag(community, alt: community.name)

        expect(result).to include('src="http://test.host/rails/active_storage/representations/proxy/community"')
      end
    end
  end
end
