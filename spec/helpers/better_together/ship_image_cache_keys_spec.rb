# frozen_string_literal: true

require 'rails_helper'

# Ship posts and pages are CMS content: a posts block lists cards, a post page shows its cover. Their cached
# fragments must follow the images they draw and must never hold a different host's absolute media URL.
module BetterTogether
  RSpec.describe 'Cache keys for image-bearing fragments' do # rubocop:disable RSpec/DescribeClass
    include ActiveSupport::Testing::TimeHelpers

    let(:svg) { '<svg xmlns="http://www.w3.org/2000/svg" width="1" height="1"></svg>' }

    def attach_svg(record, name, filename)
      record.public_send(name).attach(io: StringIO.new(svg), filename:, content_type: 'image/svg+xml')
    end

    before do
      helper.extend(BetterTogether::PagesHelper)
      helper.extend(BetterTogether::ImageHelper)
      helper.extend(Module.new { def policy_scope(scope) = scope.all })
      allow(helper).to receive(:page_visibility_cache_context).and_return('viewer')
    end

    describe '#dynamic_block_cache_stamp for a posts block' do
      let(:community) { create(:better_together_community, privacy: 'public') }
      let(:category) { create(:category) }
      let!(:post) do
        create(:better_together_post, :published, privacy: 'public', community:).tap { |p| p.categories << category }
      end
      let(:block) { create(:content_posts_block) }

      it 'changes when a category cover image that stands in for the post cover is replaced' do
        attach_svg(category, :cover_image, 'one.svg')
        before_stamp = helper.dynamic_block_cache_stamp(block)

        travel(1.minute) { attach_svg(category, :cover_image, 'two.svg') }

        expect(helper.dynamic_block_cache_stamp(block)).not_to eq(before_stamp)
      end

      it 'changes when the community image shown in the card chip is replaced' do
        attach_svg(community, :profile_image, 'one.svg')
        before_stamp = helper.dynamic_block_cache_stamp(block)

        travel(1.minute) { attach_svg(community, :profile_image, 'two.svg') }

        expect(helper.dynamic_block_cache_stamp(block)).not_to eq(before_stamp)
      end

      it 'changes when a contributor avatar is replaced' do
        author = create(:better_together_person)
        post.add_contributor(author, role: 'author')
        attach_svg(author, :profile_image, 'one.svg')
        before_stamp = helper.dynamic_block_cache_stamp(block)

        travel(1.minute) { attach_svg(author, :profile_image, 'two.svg') }

        expect(helper.dynamic_block_cache_stamp(block)).not_to eq(before_stamp)
      end

      it 'differs between origins, so one host never serves another host its absolute media URLs' do
        allow(helper).to receive(:media_url_cache_context).and_return('https://a.example')
        a = helper.dynamic_block_cache_stamp(block)
        allow(helper).to receive(:media_url_cache_context).and_return('https://b.example')

        expect(helper.dynamic_block_cache_stamp(block)).not_to eq(a)
      end
    end

    describe '#cover_image_cache_key' do
      let(:post) { create(:better_together_post, :published, privacy: 'public') }
      let(:category) { create(:category) }

      before { post.categories << category }

      it 'changes when the category cover that fills in for a missing post cover is replaced' do
        attach_svg(category, :cover_image, 'one.svg')
        before_key = helper.cover_image_cache_key(post.reload)

        travel(1.minute) { attach_svg(category, :cover_image, 'two.svg') }

        expect(helper.cover_image_cache_key(post.reload)).not_to eq(before_key)
      end

      it 'carries the origin the media URL is built against' do
        allow(helper).to receive(:media_url_cache_context).and_return('https://a.example')

        expect(helper.cover_image_cache_key(post)).to include('https://a.example')
      end
    end
  end
end
