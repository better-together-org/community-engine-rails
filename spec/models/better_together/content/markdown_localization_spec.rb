# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Content::Markdown do
  describe 'Mobility translations' do
    subject(:markdown) { build(:content_markdown) }

    it 'includes Translatable concern' do
      expect(described_class.ancestors).to include(BetterTogether::Translatable)
    end

    it 'translates markdown_source attribute' do
      expect(described_class.mobility_attributes).to include('markdown_source')
    end

    it 'supports per-locale content' do
      I18n.with_locale(:en) do
        markdown.markdown_source = 'English content'
      end
      I18n.with_locale(:es) do
        markdown.markdown_source = 'Contenido en español'
      end
      I18n.with_locale(:fr) do
        markdown.markdown_source = 'Contenu en français'
      end

      markdown.save!

      I18n.with_locale(:en) do
        expect(markdown.markdown_source).to eq('English content')
      end
      I18n.with_locale(:es) do
        expect(markdown.markdown_source).to eq('Contenido en español')
      end
      I18n.with_locale(:fr) do
        expect(markdown.markdown_source).to eq('Contenu en français')
      end
    end
  end

  describe '#content with localization' do
    context 'when using translated markdown_source' do
      let(:markdown) do
        m = nil
        I18n.with_locale(:en) do
          m = create(:content_markdown, markdown_source: 'English content')
        end
        I18n.with_locale(:es) do
          m.update!(markdown_source: 'Contenido en español')
        end
        m
      end

      it 'returns content for current locale' do
        I18n.with_locale(:en) do
          expect(markdown.content).to eq('English content')
        end

        I18n.with_locale(:es) do
          expect(markdown.content).to eq('Contenido en español')
        end
      end
    end

    context 'when using auto_sync_from_file with locale-specific files' do
      let(:base_path) { Rails.root.join('spec/fixtures/files/localized_content.md') }
      let(:markdown) do
        create(:content_markdown,
               markdown_source: 'Temp',
               markdown_file_path: base_path.to_s,
               auto_sync_from_file: true)
      end
      let(:en_file) { base_path.to_s.sub(/\.md$/i, '.en.md') }
      let(:es_file) { base_path.to_s.sub(/\.md$/i, '.es.md') }
      let(:fr_file) { base_path.to_s.sub(/\.md$/i, '.fr.md') }

      before do
        FileUtils.mkdir_p(File.dirname(base_path))
        File.write(base_path, '# Base')
        File.write(en_file, '# English Heading')
        File.write(es_file, '# Título en Español')
        File.write(fr_file, '# Titre en Français')
      end

      after do
        FileUtils.rm_f([base_path, en_file, es_file, fr_file])
      end

      it 'loads content for current locale from file' do
        expect(markdown.content).to eq('# English Heading')

        I18n.with_locale(:es) do
          expect(markdown.content).to eq('# Título en Español')
        end

        I18n.with_locale(:fr) do
          expect(markdown.content).to eq('# Titre en Français')
        end
      end
    end

    context 'when using auto_sync_from_file with fallback' do
      let(:base_path) { Rails.root.join("spec/fixtures/files/fallback_content_#{SecureRandom.hex(4)}") }
      let(:default_file) { "#{base_path}.md" }
      let(:en_file) { "#{base_path}.en.md" }

      let!(:markdown) do
        # Create files before creating the markdown record
        FileUtils.mkdir_p(File.dirname(default_file))
        File.write(en_file, '# English Content')
        File.write(default_file, '# Default Content')
        
        create(:content_markdown,
               markdown_source: nil,
               markdown_file_path: default_file,
               auto_sync_from_file: true)
      end

      after do
        FileUtils.rm_f([default_file, en_file])
      end

      it 'falls back to default file when locale-specific not found' do
        I18n.with_locale(:es) do
          # No es file, should fall back to default
          expect(markdown.content).to eq('# Default Content')
        end
      end

      it 'uses locale-specific file when available' do
        expect(markdown.content).to eq('# English Content')
      end
    end
  end

  describe '#import_file_content!' do
    let(:base_path) { Rails.root.join("spec/fixtures/files/import_test_#{SecureRandom.hex(4)}") }
    let(:base_file) { "#{base_path}.md" }
    let(:en_file) { "#{base_path}.en.md" }
    let(:es_file) { "#{base_path}.es.md" }
    let(:fr_file) { "#{base_path}.fr.md" }

    let(:markdown) do
      # Create files before creating the markdown record
      FileUtils.mkdir_p(File.dirname(base_file))
      File.write(base_file, '# Base')
      File.write(en_file, '# English Import')
      File.write(es_file, '# Importación Española')
      File.write(fr_file, '# Importation Française')
      
      create(:content_markdown,
             markdown_source: 'Temp',
             markdown_file_path: base_file)
    end

    # Ensure files exist for each test (let is memoized)
    before do
      FileUtils.mkdir_p(File.dirname(base_file))
      File.write(base_file, '# Base')
      File.write(en_file, '# English Import')
      File.write(es_file, '# Importación Española')
      File.write(fr_file, '# Importation Française')
    end

    after do
      FileUtils.rm_f([base_file, en_file, es_file, fr_file])
    end

    it 'imports content for all available locales' do
      expect(markdown.import_file_content!).to be true

      expect(markdown.markdown_source).to eq('# English Import')
      I18n.with_locale(:es) do
        expect(markdown.markdown_source).to eq('# Importación Española')
      end
      I18n.with_locale(:fr) do
        expect(markdown.markdown_source).to eq('# Importation Française')
      end
    end

    it 'sets auto_sync_from_file when requested' do
      markdown.import_file_content!(sync_future_changes: true)

      expect(markdown.auto_sync_from_file).to be true
    end

    it 'returns false when no file path' do
      markdown.update!(markdown_file_path: nil)

      expect(markdown.import_file_content!).to be false
    end
  end

  describe '#as_indexed_json with localization' do
    let(:markdown) do
      m = nil
      I18n.with_locale(:en) do
        m = create(:content_markdown, markdown_source: '# English **content**')
      end
      I18n.with_locale(:es) do
        m.update!(markdown_source: '# Contenido **español**')
      end
      I18n.with_locale(:fr) do
        m.update!(markdown_source: '# Contenu **français**')
      end
      m
    end

    it 'indexes content for all available locales' do
      result = markdown.as_indexed_json

      expect(result[:localized_content][:en]).to include('English')
      expect(result[:localized_content][:en]).to include('content')
      expect(result[:localized_content][:en]).not_to include('**')

      expect(result[:localized_content][:es]).to include('Contenido')
      expect(result[:localized_content][:es]).to include('español')

      expect(result[:localized_content][:fr]).to include('Contenu')
      expect(result[:localized_content][:fr]).to include('français')
    end

    it 'strips HTML from indexed content' do
      result = markdown.as_indexed_json

      I18n.available_locales.each do |locale|
        expect(result[:localized_content][locale]).not_to match(/<[^>]+>/)
      end
    end
  end

  describe '#rendered_html with localization' do
    let(:markdown) do
      m = nil
      I18n.with_locale(:en) do
        m = create(:content_markdown, markdown_source: '# English')
      end
      I18n.with_locale(:es) do
        m.update!(markdown_source: '# Español')
      end
      m
    end

    it 'renders content for current locale' do
      I18n.with_locale(:en) do
        html = markdown.rendered_html
        expect(html).to include('English')
      end

      I18n.with_locale(:es) do
        html = markdown.rendered_html
        expect(html).to include('Español')
      end
    end
  end

  describe '.permitted_attributes' do
    it 'includes auto_sync_from_file' do
      expect(described_class.permitted_attributes).to include(:auto_sync_from_file)
    end

    it 'includes markdown_source and markdown_file_path' do
      expect(described_class.permitted_attributes).to include(:markdown_source, :markdown_file_path)
    end
  end

  describe 'auto_sync_from_file behavior' do
    context 'when auto_sync is disabled' do
      let(:file_path) { Rails.root.join('spec/fixtures/files/no_sync.md') }
      let(:markdown) do
        create(:content_markdown,
               markdown_source: 'Database content',
               markdown_file_path: file_path.to_s,
               auto_sync_from_file: false)
      end

      before do
        FileUtils.mkdir_p(File.dirname(file_path))
        File.write(file_path, '# File content')
      end

      after do
        FileUtils.rm_f(file_path)
      end

      it 'uses database content instead of file' do
        expect(markdown.content).to eq('Database content')
      end
    end

    context 'when auto_sync is enabled' do
      let(:file_path) { Rails.root.join('spec/fixtures/files/with_sync.md') }
      let(:markdown) do
        create(:content_markdown,
               markdown_source: 'Database content',
               markdown_file_path: file_path.to_s,
               auto_sync_from_file: true)
      end

      before do
        FileUtils.mkdir_p(File.dirname(file_path))
        File.write(file_path, '# File content')
      end

      after do
        FileUtils.rm_f(file_path)
      end

      it 'loads content from file, ignoring database' do
        expect(markdown.content).to eq('# File content')
      end
    end
  end
end
