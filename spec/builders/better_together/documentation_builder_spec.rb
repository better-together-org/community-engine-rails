# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::DocumentationBuilder, type: :model do
  describe '.build' do
    let(:tmp_docs_root) { Pathname.new(Dir.mktmpdir('docs-nav')) }

    before do
      File.write(tmp_docs_root.join('README.md'), '# Overview')

      developers_dir = tmp_docs_root.join('developers')
      FileUtils.mkdir_p(developers_dir)
      File.write(developers_dir.join('README.md'), '# Developers Guide')
      File.write(developers_dir.join('api.md'), '# API')

      systems_dir = developers_dir.join('systems')
      FileUtils.mkdir_p(systems_dir)
      File.write(systems_dir.join('caching.md'), '# Caching')

      allow(described_class).to receive_messages(documentation_root: tmp_docs_root, documentation_url_prefix: '/docs')
    end

    after do
      FileUtils.remove_entry(tmp_docs_root)
    end

    it 'creates a documentation navigation area with nested items' do
      described_class.build

      area = BetterTogether::NavigationArea.i18n.find_by(slug: 'documentation')
      expect(area).to be_present
      expect(area.navigation_items.top_level.count).to eq(2)

      root_file_item = area.navigation_items.find { |item| item.linkable&.slug == 'docs/readme' }
      expect(root_file_item).to be_present
      expect(root_file_item.title).to eq('Overview')
      expect(root_file_item.linkable).to be_a(BetterTogether::Page)
      markdown_block = root_file_item.linkable.page_blocks.first.block
      expect(markdown_block).to be_a(BetterTogether::Content::Markdown)
      expect(markdown_block.markdown_file_path).to eq(tmp_docs_root.join('README.md').to_s)

      developers_item = area.navigation_items.find do |item|
        item.linkable&.slug == 'docs/developers/readme' && item.item_type == 'dropdown'
      end
      expect(developers_item).to be_present
      expect(developers_item.item_type).to eq('dropdown')
      expect(developers_item.linkable&.slug).to eq('docs/developers/readme')
      expect(developers_item.children.count).to eq(3) # README, api, systems directory

      systems_dropdown = developers_item.children.find { |child| child.title == 'Systems' }
      expect(systems_dropdown.item_type).to eq('dropdown')
      expect(systems_dropdown.children.count).to eq(1)
      systems_page = systems_dropdown.children.first.linkable
      expect(systems_page.slug).to eq('docs/developers/systems/caching')
      systems_markdown = systems_page.page_blocks.first.block
      expect(systems_markdown.markdown_file_path).to eq(tmp_docs_root.join('developers/systems/caching.md').to_s)
    end

    it 'assigns the documentation navigation area as sidebar_nav for all documentation pages' do
      described_class.build

      area = BetterTogether::NavigationArea.i18n.find_by(slug: 'documentation')
      expect(area).to be_present

      # Check root file page
      root_page = BetterTogether::Page.i18n.find_by(slug: 'docs/readme')
      expect(root_page).to be_present
      expect(root_page.sidebar_nav).to eq(area)

      # Check developers guide page
      developers_page = BetterTogether::Page.i18n.find_by(slug: 'docs/developers/readme')
      expect(developers_page).to be_present
      expect(developers_page.sidebar_nav).to eq(area)

      # Check API page
      api_page = BetterTogether::Page.i18n.find_by(slug: 'docs/developers/api')
      expect(api_page).to be_present
      expect(api_page.sidebar_nav).to eq(area)

      # Check nested systems/caching page
      caching_page = BetterTogether::Page.i18n.find_by(slug: 'docs/developers/systems/caching')
      expect(caching_page).to be_present
      expect(caching_page.sidebar_nav).to eq(area)
    end

    it 'creates a protected navigation area' do
      described_class.build

      area = BetterTogether::NavigationArea.i18n.find_by(slug: 'documentation')
      expect(area).to be_present
      expect(area.protected).to be true
    end

    it 'creates a visible navigation area' do
      described_class.build

      area = BetterTogether::NavigationArea.i18n.find_by(slug: 'documentation')
      expect(area).to be_present
      expect(area.visible).to be true
    end

    it 'sets the area name to Documentation' do
      described_class.build

      area = BetterTogether::NavigationArea.i18n.find_by(slug: 'documentation')
      expect(area).to be_present
      expect(area.name).to eq('Documentation')
    end

    it 'creates pages with nested slug structure' do
      described_class.build

      expect(BetterTogether::Page.i18n.find_by(slug: 'docs/readme')).to be_present
      expect(BetterTogether::Page.i18n.find_by(slug: 'docs/developers/readme')).to be_present
      expect(BetterTogether::Page.i18n.find_by(slug: 'docs/developers/api')).to be_present
      expect(BetterTogether::Page.i18n.find_by(slug: 'docs/developers/systems/caching')).to be_present
    end

    it 'creates protected pages' do
      described_class.build

      readme_page = BetterTogether::Page.i18n.find_by(slug: 'docs/readme')
      api_page = BetterTogether::Page.i18n.find_by(slug: 'docs/developers/api')
      caching_page = BetterTogether::Page.i18n.find_by(slug: 'docs/developers/systems/caching')

      expect(readme_page.protected).to be true
      expect(api_page.protected).to be true
      expect(caching_page.protected).to be true
    end

    it 'creates public pages' do
      described_class.build

      readme_page = BetterTogether::Page.i18n.find_by(slug: 'docs/readme')
      api_page = BetterTogether::Page.i18n.find_by(slug: 'docs/developers/api')
      caching_page = BetterTogether::Page.i18n.find_by(slug: 'docs/developers/systems/caching')

      expect(readme_page.privacy).to eq('public')
      expect(api_page.privacy).to eq('public')
      expect(caching_page.privacy).to eq('public')
    end

    context 'when documentation area already exists' do
      before do
        # Delete any existing documentation navigation items first (FK constraint)
        doc_area = BetterTogether::NavigationArea.i18n.find_by(slug: 'documentation')
        if doc_area
          doc_area.navigation_items.where.not(parent_id: nil).delete_all
          doc_area.navigation_items.where(parent_id: nil).delete_all
          doc_area.delete
        end
      end

      let!(:existing_area) do
        BetterTogether::NavigationArea.create!(
          name: 'Old Documentation',
          slug: 'documentation',
          visible: false,
          protected: false
        )
      end

      let!(:existing_item) do
        existing_area.navigation_items.create!(
          title: 'Old Item',
          slug: 'old-item',
          item_type: 'link',
          position: 0,
          visible: true,
          protected: false
        )
      end

      it 'updates the existing area' do
        described_class.build

        area = BetterTogether::NavigationArea.i18n.find_by(slug: 'documentation')
        expect(area.id).to eq(existing_area.id)
        expect(area.name).to eq('Documentation')
        expect(area.visible).to be true
        expect(area.protected).to be true
      end

      it 'deletes old navigation items' do
        described_class.build

        expect(BetterTogether::NavigationItem.find_by(id: existing_item.id)).to be_nil
      end

      it 'creates new navigation items' do
        described_class.build

        area = BetterTogether::NavigationArea.i18n.find_by(slug: 'documentation')
        expect(area.navigation_items.count).to be > 0
        expect(area.navigation_items.i18n.where(title: 'Old Item').count).to eq(0)
      end
    end

    context 'when docs directory is empty' do
      let(:empty_docs_root) { Pathname.new(Dir.mktmpdir('empty-docs')) }

      before do
        allow(described_class).to receive(:documentation_root).and_return(empty_docs_root)
      end

      after do
        FileUtils.remove_entry(empty_docs_root)
      end

      it 'does not create a navigation area' do
        initial_count = BetterTogether::NavigationArea.count

        described_class.build

        expect(BetterTogether::NavigationArea.count).to eq(initial_count)
      end
    end

    context 'when docs directory does not exist' do
      before do
        allow(described_class).to receive(:documentation_root).and_return(Pathname.new('/nonexistent/path'))
      end

      it 'does not create a navigation area' do
        initial_count = BetterTogether::NavigationArea.count

        described_class.build

        expect(BetterTogether::NavigationArea.count).to eq(initial_count)
      end
    end
  end
end
