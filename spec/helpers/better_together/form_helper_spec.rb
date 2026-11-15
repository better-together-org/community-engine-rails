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

      it 'caps at community when the platform itself is private (matches the model ceiling)' do
        expect(helper.max_allowed_privacy(platform: private_platform, community: nil)).to eq('community')
      end

      it 'defaults to public when no platform is given' do
        expect(helper.max_allowed_privacy(platform: nil, community: nil)).to eq('public')
      end
    end

    describe '#build_privacy_select_options (private)' do
      it 'keeps every option selectable so content can be prepared ahead of release' do
        rendered = helper.send(:build_privacy_select_options, BetterTogether::Post, nil)

        %w[public community private].each { |level| expect(rendered).to include(%(value="#{level}")) }
        expect(rendered).not_to include('disabled')
      end
    end

    describe '#privacy_ceiling_notice' do
      let(:page) { build(:better_together_page, platform: private_platform) }

      it 'returns nil when both platform and community are public' do
        expect(helper.privacy_ceiling_notice(page, platform: public_platform, community: public_community)).to be_nil
      end

      it 'renders an accessible, non-blocking note when the platform is not public' do
        html = helper.privacy_ceiling_notice(page, platform: private_platform, community: nil)

        expect(html).to include('role="note"')
        expect(html).to include(%(id="#{helper.dom_id(page, :privacy_ceiling_notice)}"))
        expect(html).to include('data-privacy-ceiling-source="platform"')
        expect(html).to include('aria-hidden="true"')
      end

      it 'names the community as the source when only the community is not public' do
        html = helper.privacy_ceiling_notice(page, platform: public_platform, community: private_community)

        expect(html).to include('data-privacy-ceiling-source="community"')
      end
    end

    describe '#comment_permission_field / #comment_visibility_field' do
      let(:post) { create(:better_together_post) }
      let(:comment_config) { post.build_comment_config }
      let(:cc_form) { ActionView::Helpers::FormBuilder.new(:comment_config, comment_config, helper, {}) }

      it 'renders a labelled select for permission with the current value selected' do
        comment_config.permission = 'community'
        rendered = helper.comment_permission_field(form: cc_form, commentable: post)

        expect(rendered).to include('<select')
        expect(rendered).to include('name="comment_config[permission]"')
        selected_option = rendered[/<option[^>]*value="community"[^>]*>/]
        expect(selected_option).to include('selected')
      end

      it 'renders a labelled select for visibility with the current value selected' do
        comment_config.visibility = 'community'
        rendered = helper.comment_visibility_field(form: cc_form, commentable: post)

        expect(rendered).to include('name="comment_config[visibility]"')
        selected_option = rendered[/<option[^>]*value="community"[^>]*>/]
        expect(selected_option).to include('selected')
      end

      it 'gives each field a stable, unique id (this app does not auto-generate form ids)' do
        permission_field = helper.comment_permission_field(form: cc_form, commentable: post)
        visibility_field = helper.comment_visibility_field(form: cc_form, commentable: post)

        expect(permission_field).to include("id=\"#{helper.dom_id(post)}_comment_permission\"")
        expect(visibility_field).to include("id=\"#{helper.dom_id(post)}_comment_visibility\"")
      end
    end
  end
end
