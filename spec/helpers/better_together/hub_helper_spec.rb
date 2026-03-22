# frozen_string_literal: true

require 'rails_helper'

# rubocop:disable Metrics/ModuleLength
module BetterTogether
  RSpec.describe HubHelper do
    describe '#activities' do
      let(:user) { create(:user) }
      let(:page) { create(:page) }

      before do
        allow(helper).to receive(:current_user).and_return(user)
        # Skip - Activity factory not yet implemented
        # create_list(:activity, 3, owner: user.person, trackable: page)
      end

      it 'returns scoped activities based on policy' do
        skip 'Activity factory not yet implemented'
        activities = helper.activities
        expect(activities).to be_a(ActiveRecord::Relation)
      end

      it 'uses ActivityPolicy::Scope to filter activities' do
        skip 'Activity factory not yet implemented'
        expect(BetterTogether::ActivityPolicy::Scope).to receive(:new)
          .with(user, PublicActivity::Activity)
          .and_call_original

        helper.activities
      end
    end

    describe '#timeago' do
      let(:test_time) { Time.zone.parse('2025-11-24 12:00:00 UTC') }

      context 'with valid time' do
        it 'generates abbr tag with timeago class' do
          result = helper.timeago(test_time)
          expect(result).to have_css('abbr.timeago')
        end

        it 'includes ISO8601 formatted time in title attribute' do
          result = helper.timeago(test_time)
          expect(result).to have_css("abbr[title='#{test_time.getutc.iso8601}']")
        end

        it 'displays time string as content' do
          result = helper.timeago(test_time)
          expect(result).to include(test_time.to_s)
        end

        it 'accepts custom CSS class' do
          result = helper.timeago(test_time, class: 'custom-class')
          expect(result).to have_css('abbr.custom-class')
        end

        it 'merges custom options with defaults' do
          result = helper.timeago(test_time, class: 'custom', id: 'my-time')
          expect(result).to have_css('abbr#my-time.custom')
        end
      end

      context 'with nil time' do
        it 'returns nil' do
          expect(helper.timeago(nil)).to be_nil
        end
      end

      context 'with different time zones' do
        it 'converts to UTC for title' do
          tokyo_time = Time.zone.parse('2025-11-24 21:00:00 +0900')
          result = helper.timeago(tokyo_time)
          utc_time = tokyo_time.getutc.iso8601
          expect(result).to have_css("abbr[title='#{utc_time}']")
        end
      end
    end

    describe '#whose?' do
      let(:user) { create(:user) }
      let(:other_user) { create(:user) }
      let(:page) { create(:page, creator: user.person) }
      let(:other_page) { create(:page, creator: other_user.person) }

      context 'when user owns the object' do
        it 'returns "his"' do
          result = helper.whose?(user, page)
          expect(result).to eq('his')
        end
      end

      context 'when user does not own the object' do
        it 'returns owner name with possessive' do
          result = helper.whose?(user, other_page)
          expect(result).to eq("#{other_user.person.name}'s")
        end
      end

      context 'when user is nil' do
        it 'returns empty string' do
          result = helper.whose?(nil, page)
          expect(result).to eq('')
        end
      end

      context 'when object has no owner' do
        let(:orphaned_page) { build(:page, creator: nil) }

        it 'returns empty string' do
          result = helper.whose?(user, orphaned_page)
          expect(result).to eq('')
        end
      end

      context 'when both user and owner are nil' do
        it 'returns empty string' do
          result = helper.whose?(nil, build(:page, creator: nil))
          expect(result).to eq('')
        end
      end
    end

    describe '#link_to_trackable' do
      context 'when object exists' do
        let(:page) { create(:page, title: 'Test Page') }

        it 'returns link to the object' do
          result = helper.link_to_trackable(page, 'Page')
          expect(result).to include(page.title)
          expect(result).to have_link(page.title)
        end

        it 'includes model name as prefix' do
          result = helper.link_to_trackable(page, 'Page')
          expect(result).to include(page.class.model_name.human)
        end

        it 'uses object.url if available' do
          allow(page).to receive(:url).and_return('/custom-url')
          result = helper.link_to_trackable(page, 'Page')
          expect(result).to have_link(page.title, href: '/custom-url')
        end

        it 'falls back to object itself for URL' do
          skip 'Routing helper issues in engine context'
          # Remove url method to test fallback
          allow(page).to receive(:respond_to?).with(:url).and_return(false)
          result = helper.link_to_trackable(page, 'Page')
          expect(result).to be_present
        end

        it 'adds text-decoration-none class to link' do
          result = helper.link_to_trackable(page, 'Page')
          expect(result).to have_css('a.text-decoration-none')
        end
      end

      context 'when object is nil' do
        it 'returns message about deleted object' do
          result = helper.link_to_trackable(nil, 'Post')
          expect(result).to eq('a post which does not exist anymore')
        end

        it 'downcases object type' do
          result = helper.link_to_trackable(nil, 'ARTICLE')
          expect(result).to eq('a article which does not exist anymore')
        end
      end

      context 'with different object types' do
        it 'handles different model types' do
          skip 'Routing helper issues in engine context'
          community = create(:community, name: 'Test Community')
          result = helper.link_to_trackable(community, 'Community')
          expect(result).to include(community.class.model_name.human)
          expect(result).to have_link(community.name)
        end
      end
    end

    describe 'helper integration' do
      it 'includes all expected methods' do
        expect(helper).to respond_to(:activities)
        expect(helper).to respond_to(:timeago)
        expect(helper).to respond_to(:whose?)
        expect(helper).to respond_to(:link_to_trackable)
      end
    end

    describe 'edge cases' do
      describe '#timeago with edge times' do
        it 'handles very old dates' do
          old_time = 100.years.ago
          result = helper.timeago(old_time)
          expect(result).to be_present
          expect(result).to have_css('abbr.timeago')
        end

        it 'handles future dates' do
          future_time = 10.years.from_now
          result = helper.timeago(future_time)
          expect(result).to be_present
          expect(result).to have_css('abbr.timeago')
        end
      end

      describe '#whose? with complex ownership' do
        it 'handles users with special characters in nicknames' do
          user = create(:user)
          special_user = create(:user, person: create(:person, name: "O'Brien"))
          page = create(:page, creator: special_user.person)

          result = helper.whose?(user, page)
          expect(result).to include("O'Brien")
        end
      end
    end
  end
end
# rubocop:enable Metrics/ModuleLength
