# frozen_string_literal: true

require 'rails_helper'

module BetterTogether # :nodoc:
  RSpec.describe FormHelper do
    let(:public_platform)    { create(:better_together_platform, privacy: 'public') }
    let(:community_platform) { create(:better_together_platform, privacy: 'community') }
    let(:private_platform)   { create(:better_together_platform, privacy: 'private') }
    let(:public_community)   { create(:better_together_community, privacy: 'public') }
    let(:community_community) { create(:better_together_community, privacy: 'community') }
    let(:private_community) { create(:better_together_community, privacy: 'private') }

    describe '#max_allowed_privacy' do
      it 'returns public when platform and community are both public' do
        expect(helper.max_allowed_privacy(platform: public_platform, community: public_community)).to eq('public')
      end

      it 'caps at community when the platform is public but the community is community-scoped' do
        expect(helper.max_allowed_privacy(platform: public_platform,
                                          community: community_community)).to eq('community')
      end

      it 'caps at community when the platform is public but the community is private ' \
         '(members can still share within the community)' do
        expect(helper.max_allowed_privacy(platform: public_platform, community: private_community)).to eq('community')
      end

      it 'caps at community when the platform itself is community-scoped, regardless of community' do
        expect(helper.max_allowed_privacy(platform: community_platform, community: nil)).to eq('community')
      end

      it 'caps at private when the platform itself is private' do
        expect(helper.max_allowed_privacy(platform: private_platform, community: nil)).to eq('private')
      end

      it 'defaults to public when no platform is given' do
        expect(helper.max_allowed_privacy(platform: nil, community: nil)).to eq('public')
      end
    end

    describe '#max_allowed_post_privacy (deprecated alias)' do
      it 'delegates to max_allowed_privacy' do
        expect(helper.max_allowed_post_privacy(platform: private_platform, community: nil)).to eq('private')
      end
    end

    describe '#build_privacy_select_options (private)' do
      it 'disables, but does not remove, options above the ceiling' do
        rendered = helper.send(:build_privacy_select_options, BetterTogether::Post, 'private', nil)

        expect(rendered).to include('value="public"')
        expect(rendered).to include('value="community"')
        expect(rendered).to include('value="private"')

        public_option = rendered[/<option[^>]*value="public"[^>]*>/]
        community_option = rendered[/<option[^>]*value="community"[^>]*>/]
        private_option = rendered[/<option[^>]*value="private"[^>]*>/]

        expect(public_option).to include('disabled')
        expect(community_option).to include('disabled')
        expect(private_option).not_to include('disabled')
      end

      it 'disables nothing when the ceiling is public' do
        rendered = helper.send(:build_privacy_select_options, BetterTogether::Post, 'public', nil)

        expect(rendered).not_to include('disabled')
      end
    end

    describe '#privacy_constraint_hint' do
      it 'returns nil when both platform and community are public (no restriction)' do
        expect(helper.privacy_constraint_hint(platform: public_platform, community: public_community)).to be_nil
      end

      it 'returns a hint when the platform is not public' do
        hint = helper.privacy_constraint_hint(platform: private_platform, community: nil)

        expect(hint).to be_present
      end

      it 'returns a hint when the platform is public but the community is not' do
        hint = helper.privacy_constraint_hint(platform: public_platform, community: private_community)

        expect(hint).to be_present
      end
    end
  end
end
