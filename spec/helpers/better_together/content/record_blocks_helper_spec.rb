# frozen_string_literal: true

require 'rails_helper'

module BetterTogether
  module Content
    # The cache stamp queries a block's collection with plucks and preloads. The collection comes from a policy scope
    # that may carry eager-load includes, including a polymorphic one (EventPolicy::Scope includes
    # categorizations: :category) that ActiveRecord refuses to join.
    RSpec.describe RecordBlocksHelper do
      let(:viewer_scope) do
        Module.new do
          def policy_scope(scope)
            "#{scope.name}Policy::Scope".constantize.new(nil, scope).resolve
          end
        end
      end

      before do
        helper.extend(BetterTogether::PagesHelper)
        helper.extend(viewer_scope)
        allow(helper).to receive_messages(page_visibility_cache_context: 'guest', media_url_cache_context: 'https://a.example')
      end

      describe '#dynamic_block_cache_stamp for an events block whose scope eager loads a polymorphic category' do
        let(:block) { create(:content_events_block, event_scope: 'all') }
        let(:category) { create(:event_category) }
        let!(:event) do
          create(:better_together_event, privacy: 'public').tap { |e| e.categories << category }
        end

        it 'builds the stamp instead of raising on the polymorphic association' do
          expect { helper.dynamic_block_cache_stamp(block) }.not_to raise_error
        end

        it 'still follows the listed events' do
          before_stamp = helper.dynamic_block_cache_stamp(block)

          travel_to(1.minute.from_now) { event.update!(name: 'Renamed event') }

          expect(helper.dynamic_block_cache_stamp(block)).not_to eq(before_stamp)
        end
      end

      describe '#collection_fingerprint' do
        it 'does not eager load includes the collection carries, and keeps its filters and limit' do
          kept = create(:better_together_post, :published, privacy: 'public')
          create(:better_together_post, :published, privacy: 'public')
          collection = BetterTogether::Post.where(id: kept.id).includes(categorizations: :category).limit(1)

          expect(helper.collection_fingerprint(collection))
            .to eq(helper.collection_fingerprint(BetterTogether::Post.where(id: kept.id)))
        end
      end

      describe '#post_card_fingerprint' do
        it 'loads categories without joining them, even when the collection includes them' do
          post = create(:better_together_post, :published, privacy: 'public')
          post.categories << create(:category)
          collection = BetterTogether::Post.where(id: post.id).includes(categorizations: :category).limit(1)

          expect { helper.post_card_fingerprint(collection) }.not_to raise_error
        end
      end
    end
  end
end
