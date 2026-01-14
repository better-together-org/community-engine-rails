# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::NavigationItem do
  let(:navigation_area) { create(:navigation_area) }

  context 'title fallbacks' do
    it 'returns nav item translation when present' do
      nav = described_class.build(navigation_area:, title: 'Nav Title', slug: 'nav-title', visible: true)

      expect(nav.title).to eq('Nav Title')
    end

    it 'falls back to linkable title when nav item title blank and linkable present' do
      page = create(:page, title: 'Page Title')
      nav = described_class.build(navigation_area:, title: '', slug: 'nav-title', visible: true, linkable: page)

      expect(nav.title).to eq('Page Title')
    end

    it 'returns blank when nav item title blank and no linkable' do
      nav = described_class.build(navigation_area:, title: '', slug: 'nav-title', visible: true)

      expect(nav.title).to be_blank
    end

    it 'prefers linkable title when set' do
      page = create(:page, title: 'Page Title')
      nav = described_class.build(navigation_area:, title: 'Nav Title', slug: 'nav-title', visible: true,
                                  linkable: page)

      expect(nav.title).to eq('Page Title')
    end

    it 'returns translation for requested locale when available' do
      I18n.with_locale(:es) do
        nav = described_class.build(navigation_area:, title: 'Título Nav', slug: 'nav-title', visible: true)

        expect(nav.title(locale: :es)).to eq('Título Nav')
      end
    end

    it 'falls back to linkable translation for a missing nav translation' do
      page = create(:page)
      # set page spanish title
      page.public_send(:title=, 'Título Página', locale: :es)

      nav = described_class.build(navigation_area:, title: '', slug: 'nav-title', visible: true, linkable: page)

      I18n.with_locale(:es) do
        expect(nav.title(locale: :es)).to eq('Título Página')
      end
    end
  end
end
# frozen_string_literal: true

# spec/models/better_together/navigation_item_spec.rb

module BetterTogether # rubocop:todo Metrics/ModuleLength
  RSpec.describe NavigationItem do
    subject(:navigation_item) { build(:better_together_navigation_item) }
    let!(:existing_navigation_item) { create(:better_together_navigation_item) }

    describe 'Factory' do
      it 'has a valid factory' do
        expect(navigation_item).to be_valid
      end
    end

    describe 'ActiveRecord associations' do
      it { is_expected.to belong_to(:navigation_area) }
      it { is_expected.to belong_to(:parent).class_name('NavigationItem').optional }
      it { is_expected.to have_many(:children).class_name('NavigationItem').dependent(:destroy) }
    end

    describe 'ActiveModel validations' do
      it { is_expected.to validate_presence_of(:title) }
      it { is_expected.to validate_length_of(:title).is_at_most(255) }
      # it { is_expected.to validate_inclusion_of(:visible).in_array([true, false]) }
      it { is_expected.to validate_numericality_of(:position).only_integer.is_greater_than_or_equal_to(0) }
      it { is_expected.to validate_inclusion_of(:item_type).in_array(%w[link dropdown separator]) }
      it { is_expected.to allow_value('http://example.com').for(:url) }
      it { is_expected.to allow_value('#').for(:url) }
      it { is_expected.to allow_value('').for(:url) }

      describe 'visibility_strategy validation' do
        it { is_expected.to validate_inclusion_of(:visibility_strategy).in_array(%w[authenticated permission]) }
      end

      describe 'permission_identifier validation' do
        context 'when visibility_strategy is permission' do
          before { navigation_item.visibility_strategy = 'permission' }

          it { is_expected.to validate_presence_of(:permission_identifier) }
        end

        context 'when visibility_strategy is authenticated' do
          before { navigation_item.visibility_strategy = 'authenticated' }

          it { is_expected.not_to validate_presence_of(:permission_identifier) }
        end
      end

      describe 'permission_identifier_requires_non_public_privacy validation' do
        context 'when permission_identifier is set and privacy is public' do
          before do
            navigation_item.permission_identifier = 'view_metrics_dashboard'
            navigation_item.privacy = 'public'
          end

          it 'is invalid' do
            expect(navigation_item).not_to be_valid
            expect(navigation_item.errors[:permission_identifier])
              .to include('cannot be used with public privacy')
          end
        end

        context 'when permission_identifier is set and privacy is private' do
          before do
            navigation_item.permission_identifier = 'view_metrics_dashboard'
            navigation_item.privacy = 'private'
          end

          it 'is valid' do
            expect(navigation_item).to be_valid
          end
        end

        context 'when permission_identifier is blank and privacy is public' do
          before do
            navigation_item.permission_identifier = nil
            navigation_item.privacy = 'public'
          end

          it 'is valid' do
            expect(navigation_item).to be_valid
          end
        end
      end
    end

    describe 'Attributes' do
      it { is_expected.to respond_to(:title) }
      it { is_expected.to respond_to(:slug) }
      it { is_expected.to respond_to(:url) }
      it { is_expected.to respond_to(:icon) }
      it { is_expected.to respond_to(:position) }
      it { is_expected.to respond_to(:visible) }
      it { is_expected.to respond_to(:item_type) }
      it { is_expected.to respond_to(:protected) }
      it { is_expected.to respond_to(:linkable_type) }
      it { is_expected.to respond_to(:linkable_id) }
      it { is_expected.to respond_to(:privacy) }
      it { is_expected.to respond_to(:visibility_strategy) }
      it { is_expected.to respond_to(:permission_identifier) }
    end

    describe 'Scopes' do
      describe '.top_level' do
        it 'returns only top-level navigation items' do
          top_level_nav_item_count = described_class.top_level.size
          create(:better_together_navigation_item, parent: existing_navigation_item)
          expect(described_class.top_level.size).to eq(top_level_nav_item_count)
        end
      end

      describe '.visible' do
        it 'returns only visible navigation items' do
          visible_nav_item_count = described_class.visible.count
          create(:better_together_navigation_item, visible: false)
          expect(described_class.visible.count).to eq(visible_nav_item_count)
        end
      end
    end

    describe 'Methods' do
      describe '#child?' do
        context 'when navigation item has a parent' do
          before { navigation_item.parent = create(:better_together_navigation_item) }

          it 'returns true' do
            expect(navigation_item.child?).to be true
          end
        end

        context 'when navigation item has no parent' do
          it 'returns false' do
            expect(navigation_item.child?).to be false
          end
        end
      end

      describe '#dropdown?' do
        context 'when item type is dropdown' do
          before { navigation_item.item_type = 'dropdown' }

          it 'returns true' do
            expect(navigation_item.dropdown?).to be true
          end
        end

        context 'when item type is not dropdown' do
          before { navigation_item.item_type = 'link' }

          it 'returns false' do
            expect(navigation_item.dropdown?).to be false
          end
        end
      end

      describe '#url' do
        context 'when linkable is present' do
          let(:linkable_page) { create(:better_together_page) }

          before { navigation_item.linkable = linkable_page }

          it 'returns the url of the linkable object' do
            expect(navigation_item.url).to eq(linkable_page.url)
          end
        end

        context 'when linkable is not present' do
          context 'and url is set' do
            before { navigation_item.url = 'http://example.com' }

            it 'returns the set url' do
              expect(navigation_item.url).to eq('http://example.com')
            end
          end

          context 'and url is not set' do
            before { navigation_item.url = nil }

            it 'returns default url (#)' do
              expect(navigation_item.url).to eq('#')
            end
          end
        end
      end

      describe '#visible_to?' do
        let(:platform) { create(:better_together_platform) }
        let(:user) { create(:better_together_person) }
        let(:context) { { platform: } }

        before do
          navigation_item.visible = true # Ensure item passes visible? check
        end

        context 'when privacy is public' do
          before { navigation_item.privacy = 'public' }

          it 'returns true for any user' do
            expect(navigation_item.visible_to?(user, context)).to be true
          end

          it 'returns true for nil user' do
            expect(navigation_item.visible_to?(nil, context)).to be true
          end
        end

        context 'when privacy is private' do
          before { navigation_item.privacy = 'private' }

          it 'returns false for nil user' do
            expect(navigation_item.visible_to?(nil, context)).to be false
          end

          it 'returns true for authenticated user with authenticated strategy' do
            expect(navigation_item.visible_to?(user, context)).to be true
          end

          context 'with visibility_strategy permission' do
            before do
              navigation_item.visibility_strategy = 'permission'
              navigation_item.permission_identifier = 'view_metrics_dashboard'
              navigation_item.save!
            end

            it 'returns true when user has permission' do
              allow(user).to receive(:permitted_to?)
                .with('view_metrics_dashboard', platform)
                .and_return(true)

              expect(navigation_item.visible_to?(user, context)).to be true
            end

            it 'returns false when user lacks permission' do
              allow(user).to receive(:permitted_to?)
                .with('view_metrics_dashboard', platform)
                .and_return(false)

              expect(navigation_item.visible_to?(user, context)).to be false
            end

            it 'returns false when platform is missing from context' do
              expect(navigation_item.visible_to?(user, {})).to be false
            end
          end
        end
      end

      describe '#permission_visible?' do
        let(:platform) { create(:better_together_platform) }
        let(:user) { create(:better_together_person) }
        let(:context) { { platform: } }

        before do
          navigation_item.permission_identifier = 'view_metrics_dashboard'
        end

        it 'returns false when platform is missing from context' do
          expect(navigation_item.send(:permission_visible?, user, {})).to be false
        end

        it 'returns false when permission_identifier is blank' do
          navigation_item.permission_identifier = nil
          expect(navigation_item.send(:permission_visible?, user, context)).to be false
        end

        it 'returns true when user has the required permission' do
          allow(user).to receive(:permitted_to?)
            .with('view_metrics_dashboard', platform)
            .and_return(true)

          expect(navigation_item.send(:permission_visible?, user, context)).to be true
        end

        it 'returns false when user lacks the required permission' do
          allow(user).to receive(:permitted_to?)
            .with('view_metrics_dashboard', platform)
            .and_return(false)

          expect(navigation_item.send(:permission_visible?, user, context)).to be false
        end
      end
    end
  end
end
