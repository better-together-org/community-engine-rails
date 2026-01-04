# frozen_string_literal: true

require 'rails_helper'

module BetterTogether # rubocop:disable Metrics/ModuleLength
  RSpec.describe ActivityPolicy, type: :policy do
    before { configure_host_platform }

    # Helper to create an activity with a trackable
    def create_activity_for(trackable, privacy: 'public', owner: nil)
      PublicActivity::Activity.create!(
        trackable: trackable,
        owner: owner || trackable.creator,
        key: "#{trackable.class.name.demodulize.underscore}.create",
        privacy: privacy,
        parameters: {}
      )
    end

    let(:activity) { create(:activity) }

    describe '#index?' do
      subject { described_class.new(user, activity).index? }

      context 'when user is present' do
        let(:user) { create(:better_together_user) }

        it { is_expected.to be true }
      end

      context 'when user is nil' do
        let(:user) { nil }

        it { is_expected.to be false }
      end
    end

    describe '#show?' do
      subject { described_class.new(user, activity).show? }

      context 'when user is present' do
        let(:user) { create(:better_together_user) }

        it { is_expected.to be true }
      end

      context 'when user is nil' do
        let(:user) { nil }

        it { is_expected.to be false }
      end
    end

    describe 'Scope' do
      subject(:scope) { described_class::Scope.new(user, PublicActivity::Activity).resolve }

      describe 'filtering by trackable visibility' do
        context 'with Pages' do
          let(:user) { create(:better_together_user) }
          let(:creator_person) { create(:better_together_person) }
          let(:creator) { create(:better_together_user, person: creator_person) }

          context 'when page is published and public' do
            let!(:published_page) do
              create(:better_together_page, privacy: 'public', published_at: 1.day.ago, creator_id: creator_person.id)
            end
            let!(:activity) { create_activity_for(published_page) }

            it 'includes the activity' do
              expect(scope).to include(activity)
            end
          end

          context 'when page is unpublished (nil published_at) and public' do
            let!(:unpublished_page) do
              create(:better_together_page, privacy: 'public', published_at: nil, creator_id: creator_person.id)
            end
            let!(:activity) { create_activity_for(unpublished_page) }

            it 'excludes the activity' do
              expect(scope).not_to include(activity)
            end
          end

          context 'when page is scheduled (future published_at) and public' do
            let!(:scheduled_page) do
              create(:better_together_page, privacy: 'public', published_at: 1.day.from_now, creator: creator_person)
            end
            let!(:activity) { create_activity_for(scheduled_page) }

            it 'excludes the activity' do
              expect(scope).not_to include(activity)
            end
          end

          context 'when page is published but private' do
            let!(:private_page) do
              create(:better_together_page, privacy: 'private', published_at: 1.day.ago, creator: creator_person)
            end
            let!(:activity) { create_activity_for(private_page, privacy: 'private') }

            it 'excludes the activity (filtered by activity privacy)' do
              expect(scope).not_to include(activity)
            end
          end

          context 'when user is the page creator and page is unpublished' do
            let(:user) { creator }
            let!(:unpublished_page) do
              create(:better_together_page, privacy: 'public', published_at: nil, creator: creator_person)
            end
            let!(:activity) { create_activity_for(unpublished_page, owner: creator_person) }

            it 'includes the activity (creators can see their own unpublished content)' do
              expect(scope).to include(activity)
            end
          end
        end

        context 'with Posts' do
          let(:user) { create(:better_together_user) }
          let(:creator_person) { create(:better_together_person) }
          let(:creator) { create(:better_together_user, person: creator_person) }

          context 'when post is published and public' do
            let!(:published_post) do
              create(:better_together_post, privacy: 'public', published_at: 1.day.ago, creator: creator_person)
            end
            let!(:activity) { create_activity_for(published_post) }

            it 'includes the activity' do
              expect(scope).to include(activity)
            end
          end

          context 'when post is unpublished and public' do
            let!(:unpublished_post) do
              create(:better_together_post, privacy: 'public', published_at: nil, creator: creator_person)
            end
            let!(:activity) { create_activity_for(unpublished_post) }

            it 'excludes the activity' do
              expect(scope).not_to include(activity)
            end
          end

          context 'when post is scheduled (future published_at) and public' do
            let!(:scheduled_post) do
              create(:better_together_post, privacy: 'public', published_at: 1.day.from_now, creator: creator_person)
            end
            let!(:activity) { create_activity_for(scheduled_post) }

            it 'excludes the activity' do
              expect(scope).not_to include(activity)
            end
          end

          context 'when post author is blocked by the viewing user' do
            let(:blocked_author) { create(:better_together_person) }
            let!(:post_by_blocked) do
              # Disable auto-tracking for this test
              BetterTogether::Post.public_activity_off
              post = create(:better_together_post, privacy: 'public', published_at: 1.day.ago, author: blocked_author)
              BetterTogether::Post.public_activity_on
              post
            end
            let!(:activity) { create_activity_for(post_by_blocked, owner: blocked_author) }

            before do
              create(:person_block, blocker: user.person, blocked: blocked_author)
            end

            it 'excludes the activity' do
              expect(scope).not_to include(activity)
            end
          end

          context 'when user is the post creator and post is unpublished' do
            let(:user) { creator }
            let!(:unpublished_post) do
              create(:better_together_post, privacy: 'public', published_at: nil, creator: creator_person)
            end
            let!(:activity) { create_activity_for(unpublished_post, owner: creator_person) }

            it 'includes the activity (creators can see their own unpublished content)' do
              expect(scope).to include(activity)
            end
          end
        end

        context 'with Events' do
          let(:user) { create(:better_together_user) }
          let(:creator_person) { create(:better_together_person) }
          let(:creator) { create(:better_together_user, person: creator_person) }

          context 'when event is scheduled (has starts_at) and public' do
            let!(:scheduled_event) do
              create(:better_together_event, privacy: 'public', starts_at: 1.day.from_now,
                                             duration_minutes: 60, creator: creator_person)
            end
            let!(:activity) { create_activity_for(scheduled_event) }

            it 'includes the activity' do
              expect(scope).to include(activity)
            end
          end

          context 'when event is draft (nil starts_at) and public' do
            let!(:draft_event) do
              create(:better_together_event, privacy: 'public', starts_at: nil, creator: creator_person)
            end
            let!(:activity) { create_activity_for(draft_event) }

            it 'excludes the activity' do
              expect(scope).not_to include(activity)
            end
          end

          context 'when event is private' do
            let!(:private_event) do
              create(:better_together_event, privacy: 'private', starts_at: 1.day.from_now,
                                             duration_minutes: 60, creator: creator_person)
            end
            let!(:activity) { create_activity_for(private_event, privacy: 'private') }

            it 'excludes the activity (filtered by activity privacy)' do
              expect(scope).not_to include(activity)
            end
          end

          context 'when user is the event creator and event is draft' do
            let(:user) { creator }
            let!(:draft_event) do
              create(:better_together_event, privacy: 'public', starts_at: nil, creator: creator_person)
            end
            let!(:activity) { create_activity_for(draft_event, owner: creator_person) }

            it 'includes the activity (creators can see their own draft events)' do
              expect(scope).to include(activity)
            end
          end
        end

        context 'when user is a platform manager' do
          let(:manager_user) { create(:better_together_user, :platform_manager) }
          let(:user) { manager_user }
          let(:creator_person) { create(:better_together_person) }

          context 'with unpublished pages' do
            let!(:unpublished_page) do
              create(:better_together_page, privacy: 'public', published_at: nil, creator: creator_person)
            end
            let!(:activity) { create_activity_for(unpublished_page) }

            it 'includes the activity (platform managers see all public activities)' do
              expect(scope).to include(activity)
            end
          end

          context 'with unpublished posts' do
            let!(:unpublished_post) do
              create(:better_together_post, privacy: 'public', published_at: nil, creator: creator_person)
            end
            let!(:activity) { create_activity_for(unpublished_post) }

            it 'includes the activity (platform managers see all public activities)' do
              expect(scope).to include(activity)
            end
          end

          context 'with draft events' do
            let!(:draft_event) do
              create(:better_together_event, privacy: 'public', starts_at: nil, creator: creator_person)
            end
            let!(:activity) { create_activity_for(draft_event) }

            it 'includes the activity (platform managers see all public activities)' do
              expect(scope).to include(activity)
            end
          end
        end

        context 'with nil trackable (deleted content)' do
          let(:user) { create(:better_together_user) }
          let!(:orphaned_activity) do
            PublicActivity::Activity.create!(
              trackable_type: 'BetterTogether::Page',
              trackable_id: SecureRandom.uuid,
              owner: user.person,
              key: 'page.create',
              privacy: 'public',
              parameters: {}
            )
          end

          it 'excludes the activity' do
            expect(scope).not_to include(orphaned_activity)
          end
        end

        context 'with private activity privacy' do
          let(:user) { create(:better_together_user) }
          let(:creator_person) { create(:better_together_person) }
          let!(:published_page) do
            create(:better_together_page, privacy: 'private', published_at: 1.day.ago, creator: creator_person)
          end
          let!(:activity) { create_activity_for(published_page, privacy: 'private') }

          it 'excludes the activity (filtered at database level by activity.privacy)' do
            expect(scope).not_to include(activity)
          end
        end
      end

      describe 'ordering' do
        let(:user) { create(:better_together_user) }
        let(:creator_person) { create(:better_together_person) }
        let!(:old_page) do
          create(:better_together_page, privacy: 'public', published_at: 3.days.ago, creator: creator_person)
        end
        let!(:recent_page) do
          create(:better_together_page, privacy: 'public', published_at: 1.day.ago, creator: creator_person)
        end
        let!(:old_activity) { create_activity_for(old_page) }
        let!(:recent_activity) { create_activity_for(recent_page) }

        before do
          old_activity.update!(updated_at: 3.days.ago)
          recent_activity.update!(updated_at: 1.day.ago)
        end

        it 'orders activities by updated_at descending' do
          # Only compare the two activities we explicitly created
          result = scope.to_a
          expect(result).to include(recent_activity, old_activity)
          # Verify ordering of our activities
          our_activities = [recent_activity, old_activity]
          result_order = result.select { |a| our_activities.include?(a) }
          expect(result_order).to eq([recent_activity, old_activity])
        end
      end

      describe 'eager loading' do
        let(:user) { create(:better_together_user) }
        let(:creator_person) { create(:better_together_person) }
        let!(:page) do
          create(:better_together_page, privacy: 'public', published_at: 1.day.ago, creator: creator_person)
        end
        let!(:activity) { create_activity_for(page, owner: creator_person) }

        it 'eager loads trackable' do
          scope_result = scope.to_a
          # Verify trackable is loaded (association won't trigger query if already loaded)
          expect(scope_result.first.association(:trackable).loaded?).to be true
        end

        it 'eager loads owner' do
          scope_result = scope.to_a
          # Verify owner is loaded (association won't trigger query if already loaded)
          expect(scope_result.first.association(:owner).loaded?).to be true
        end
      end
    end
  end
end
