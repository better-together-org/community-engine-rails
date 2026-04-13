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
  end
end
