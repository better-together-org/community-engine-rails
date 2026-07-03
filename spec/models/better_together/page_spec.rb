# frozen_string_literal: true

# spec/models/better_together/page_spec.rb

require 'rails_helper'

module BetterTogether # :nodoc:
  RSpec.describe Page do
    subject(:page) { build(:better_together_page) }

    describe 'Factory' do
      it 'has a valid factory' do
        expect(page).to be_valid
      end
    end

    describe 'ActiveModel validations' do
      it { is_expected.to validate_presence_of(:title) }
      it { is_expected.to validate_presence_of(:privacy) }
    end

    describe 'Attributes' do
      it { is_expected.to respond_to(:title) }
      it { is_expected.to respond_to(:slug) }
      it { is_expected.to respond_to(:content) }
      it { is_expected.to respond_to(:meta_description) }
      it { is_expected.to respond_to(:keywords) }
      it { is_expected.to respond_to(:published_at) }
      it { is_expected.to respond_to(:privacy) }
      it { is_expected.to respond_to(:layout) }
      it { is_expected.to respond_to(:template) }
      it { is_expected.to respond_to(:protected) }
      it { is_expected.to respond_to(:platform_id) }
      it { is_expected.to respond_to(:source_id) }
      it { is_expected.to respond_to(:source_updated_at) }
      it { is_expected.to respond_to(:last_synced_at) }
    end

    describe 'Scopes' do
      describe '.published' do
        it 'returns only published pages' do
          published_page_count = described_class.published.count
          create(:better_together_page, published_at: nil)
          expect(described_class.published.count).to eq(published_page_count)
        end
      end

      describe '.by_publication_date' do
        it 'orders pages by published date descending' do # rubocop:todo RSpec/NoExpectationExample
          # Create pages and test the order
        end
      end

      describe '.privacy_public' do
        it 'returns only public pages' do
          public_pages_count = described_class.privacy_public.count
          create(:better_together_page, privacy: 'private')
          expect(described_class.privacy_public.count).to eq(public_pages_count)
        end
      end
    end

    describe 'Methods' do
      describe 'publishing agreement gate' do
        let!(:publishing_agreement) do
          BetterTogether::Agreement.find_or_create_by!(
            identifier: BetterTogether::PublicVisibilityGate::AGREEMENT_IDENTIFIER
          ) do |agreement|
            agreement.title = 'Content Publishing Agreement'
            agreement.privacy = 'public'
            agreement.protected = true
          end
        end

        let(:publisher) { create(:better_together_person) }

        after do
          Current.reset
        end

        it 'blocks publishing community-visible pages without agreement acceptance' do
          community_page = create(:better_together_page, privacy: 'community', published_at: nil)
          Current.governed_agent = publisher

          community_page.published_at = Time.current

          expect(community_page).not_to be_valid
          expect(community_page.errors[:base]).to include(
            BetterTogether::PublicVisibilityGate.error_message_for(:missing_publishing_agreement)
          )
        end

        it 'allows publishing community-visible pages after agreement acceptance' do
          create(:better_together_agreement_participant,
                 agreement: publishing_agreement,
                 participant: publisher,
                 accepted_at: Time.current)
          community_page = create(:better_together_page, privacy: 'community', published_at: nil)
          Current.governed_agent = publisher

          community_page.published_at = Time.current

          expect(community_page).to be_valid
        end
      end

      describe '#published?' do
        it 'returns true if the page is published' do
          page.published_at = Time.now - 2.days
          expect(page.published?).to be true
        end

        it 'returns false if the page is not published' do
          page.published_at = nil
          expect(page.published?).to be false
        end
      end

      describe '#to_s' do
        it 'returns the title' do
          expect(page.to_s).to eq(page.title)
        end
      end

      describe '#governed_authors' do
        it 'includes both person and robot authors in authorship order' do
          page = create(:better_together_page)
          person = create(:better_together_person)
          robot = create(:robot, platform: page.platform)

          page.authorships.create!(author: person, position: 1)
          page.authorships.create!(author: robot, position: 2)

          expect(page.governed_authors).to eq([person, robot])
          expect(page.authors).to eq([person])
          expect(page.robot_authors).to eq([robot])
        end
      end

      describe '#resolved_contributors_display_visibility' do
        it 'uses the community override before the platform default' do
          platform = create(:better_together_platform, :public)
          community = create(:better_together_community, privacy: 'public')
          page = create(:better_together_page, platform:, community:)

          platform.update!(contributors_display_visibility: 'on')
          community.update!(contributors_display_visibility: 'off')

          expect(page.resolved_contributors_display_visibility).to eq('off')
          expect(page).not_to be_contributors_display_visible
        end

        it 'uses the record override before the community setting' do
          platform = create(:better_together_platform, :public)
          community = create(:better_together_community, privacy: 'public')
          page = create(:better_together_page, platform:, community:, contributors_display_visibility: 'on')

          platform.update!(contributors_display_visibility: 'on')
          community.update!(contributors_display_visibility: 'off')

          expect(page.resolved_contributors_display_visibility).to eq('on')
          expect(page).to be_contributors_display_visible
        end
      end

      describe 'creator fallback authorship' do
        it 'adds the creator as author when no explicit authors were selected' do
          creator = create(:better_together_person)
          page = create(:better_together_page, creator:)

          expect(page.authors).to include(creator)
        end

        it 'does not add the creator when an explicit robot author was selected' do
          creator = create(:better_together_person)
          platform = BetterTogether::Platform.find_by(host: true) || create(:better_together_platform)
          robot = create(:robot, platform:)
          page = described_class.new(title: 'Robot Page', privacy: 'public', platform:, creator:)

          page.robot_authors << robot
          page.save!

          expect(page.robot_authors).to contain_exactly(robot)
          expect(page.authors).to be_empty
          expect(page.governed_authors).to contain_exactly(robot)
        end
      end

      describe '#url' do
        it 'returns the full URL of the page' do
          expect(page.url).to eq("#{::BetterTogether.base_url_with_locale}/#{page.slug}")
        end
      end

      describe 'federation provenance' do
        let(:local_platform) { Platform.find_by(host: true) || create(:better_together_platform, host: true) }
        let(:remote_platform) { create(:better_together_platform, :external) }

        around do |example|
          previous_platform = Current.platform
          Current.platform = local_platform
          example.run
          Current.platform = previous_platform
        end

        it 'assigns the current platform by default' do
          page.valid?

          expect(page.platform).to eq(local_platform)
        end

        it 'treats a current-platform page as local' do
          page.valid?

          expect(page).to be_local_to_platform(local_platform)
          expect(page).not_to be_remote_to_platform(local_platform)
        end

        it 'treats a sourced page from another platform as mirrored' do
          mirrored_page = build(
            :better_together_page,
            platform: remote_platform,
            source_id: 'remote-page-1'
          )

          expect(mirrored_page).to be_mirrored
          expect(mirrored_page).to be_remote_to_platform(local_platform)
          expect(mirrored_page.source_identifier).to eq('remote-page-1')
        end

        it 'treats a CE UUID-preserved page as mirrored without a source_id' do
          mirrored_page = build(
            :better_together_page,
            id: SecureRandom.uuid,
            platform: remote_platform,
            source_id: nil
          )

          expect(mirrored_page).to be_mirrored
          expect(mirrored_page).to be_preserved_remote_uuid
          expect(mirrored_page.source_identifier).to eq(mirrored_page.id)
        end
      end

      describe 'evidence selector options' do
        it 'includes media-specific selectors from page content blocks' do
          page = create(:better_together_page)
          image_block = create(:better_together_content_image, identifier: 'launch-image')
          video_block = create(:content_video_block, identifier: 'launch-video')
          page.page_blocks.create!(block: image_block, position: 0)
          page.page_blocks.create!(block: video_block, position: 1)

          expect(page.evidence_selector_options).to include(
            include(value: 'block:image:launch-image:media'),
            include(value: 'block:image:launch-image:region:*'),
            include(value: 'block:video_block:launch-video:timestamp:*')
          )
        end

        it 'includes linked contribution citations in grouped evidence source options' do
          page = create(:better_together_page)
          local_citation = create(:citation, citeable: page, reference_key: 'local_record', title: 'Local Record Citation')
          contributor = create(:person, name: 'Evidence Keeper')
          contribution = BetterTogether::Authorship.create!(
            authorable: page,
            author: contributor,
            role: 'reviewer'
          )
          linked_citation = create(:citation, citeable: contribution, reference_key: 'review_notes', title: 'Review Notes')

          groups = page.available_evidence_citation_option_groups

          expect(groups['Current record']).to include(["#{local_citation.reference_key}: #{local_citation.title}", local_citation.id])
          expect(groups['Evidence Keeper: Reviewer']).to include(["#{linked_citation.reference_key}: #{linked_citation.title}",
                                                                  linked_citation.id])
        end

        it 'builds evidence browser groups with preview metadata' do
          page = create(:better_together_page)
          create(:citation,
                 citeable: page,
                 reference_key: 'local_record',
                 title: 'Local Record Citation',
                 locator: 'p. 10',
                 excerpt: 'Shared reality requires traceable evidence.')

          browser_groups = page.available_evidence_citation_browser_groups

          expect(browser_groups.first[:label]).to eq('Current record')
          expect(browser_groups.first[:citations].first).to include(
            reference_key: 'local_record',
            title: 'Local Record Citation',
            locator: 'p. 10',
            excerpt: 'Shared reality requires traceable evidence.'
          )
          expect(browser_groups.first[:origin]).to eq('current_record')
          expect(browser_groups.first[:record_type]).to eq('Page')
        end

        it 'includes contribution metadata in linked evidence browser groups' do
          page = create(:better_together_page)
          contributor = create(:person, name: 'Doc Reviewer')
          contribution = BetterTogether::Authorship.create!(
            authorable: page,
            author: contributor,
            role: 'reviewer',
            contribution_type: 'documentation'
          )
          create(:citation, citeable: contribution, reference_key: 'review_notes', title: 'Review Notes')

          contribution_group = page.available_evidence_citation_browser_groups.find { |group| group[:origin] == 'contribution' }

          expect(contribution_group).to include(
            origin: 'contribution',
            record_type: 'Authorship',
            contribution_role: 'reviewer',
            contribution_type: 'documentation'
          )
        end
      end
    end

    describe 'privacy ceiling validation (PrivacyCeilingValidatable)' do
      let(:public_platform)    { create(:better_together_platform, privacy: 'public') }
      let(:community_platform) { create(:better_together_platform, privacy: 'community') }
      let(:private_platform)   { create(:better_together_platform, privacy: 'private') }
      let(:public_community)   { create(:better_together_community, privacy: 'public') }
      let(:community_community) { create(:better_together_community, privacy: 'community') }
      let(:private_community) { create(:better_together_community, privacy: 'private') }

      let(:page_for) do
        lambda { |platform:, community: nil, privacy: 'public'|
          build(:better_together_page, platform: platform, community: community, privacy: privacy)
        }
      end

      context 'public platform + public community' do
        it 'allows public privacy' do
          expect(page_for.call(platform: public_platform, community: public_community, privacy: 'public')).to be_valid
        end

        it 'allows community privacy' do
          expect(page_for.call(platform: public_platform, community: public_community, privacy: 'community')).to be_valid
        end

        it 'allows private privacy' do
          expect(page_for.call(platform: public_platform, community: public_community, privacy: 'private')).to be_valid
        end
      end

      context 'public platform + community-privacy community' do
        it 'rejects public privacy' do
          page = page_for.call(platform: public_platform, community: community_community, privacy: 'public')
          expect(page).not_to be_valid
          expect(page.errors[:privacy].join).to include('community')
        end

        it 'allows community privacy' do
          expect(page_for.call(platform: public_platform, community: community_community, privacy: 'community')).to be_valid
        end
      end

      context 'public platform + private community' do
        it 'rejects public privacy' do
          page = page_for.call(platform: public_platform, community: private_community, privacy: 'public')
          expect(page).not_to be_valid
          expect(page.errors[:privacy].join).to include('community')
        end

        it 'allows community privacy (members can still share within the community)' do
          expect(page_for.call(platform: public_platform, community: private_community, privacy: 'community')).to be_valid
        end

        it 'allows private privacy' do
          expect(page_for.call(platform: public_platform, community: private_community, privacy: 'private')).to be_valid
        end
      end

      context 'community-privacy platform' do
        it 'rejects public privacy' do
          page = page_for.call(platform: community_platform, privacy: 'public')
          expect(page).not_to be_valid
          expect(page.errors[:privacy].join).to include('community')
        end

        it 'allows community privacy' do
          expect(page_for.call(platform: community_platform, privacy: 'community')).to be_valid
        end

        it 'allows private privacy' do
          expect(page_for.call(platform: community_platform, privacy: 'private')).to be_valid
        end
      end

      context 'private platform' do
        it 'rejects public privacy' do
          page = page_for.call(platform: private_platform, privacy: 'public')
          expect(page).not_to be_valid
          expect(page.errors[:privacy].join).to include('community')
        end

        it 'allows community privacy' do
          # A private/non-public platform's ceiling floors at 'community', not
          # 'private' — members of a locked-down platform can still write
          # community-scoped content (see PrivacyCeilingValidatable).
          expect(page_for.call(platform: private_platform, privacy: 'community')).to be_valid
        end

        it 'allows private privacy' do
          expect(page_for.call(platform: private_platform, privacy: 'private')).to be_valid
        end
      end

      it 'only validates when privacy changes (skips on unrelated attribute updates)' do
        page = create(:better_together_page, platform: public_platform, community: public_community, privacy: 'public')
        page.title = 'Updated title'
        expect(page).to be_valid
      end
    end
  end
end
