# frozen_string_literal: true

require 'rails_helper'

module BetterTogether
  module Content # rubocop:disable Metrics/ModuleLength
    RSpec.describe MermaidDiagram do
      subject(:mermaid_block) { build(:better_together_content_mermaid_diagram) }

      describe 'Factory' do
        it 'has a valid factory' do
          expect(mermaid_block).to be_valid
        end

        it 'creates with diagram_source' do
          block = create(:better_together_content_mermaid_diagram, diagram_source: "graph TD\n  A-->B")
          expect(block.diagram_source).to eq("graph TD\n  A-->B")
        end

        it 'creates with theme' do
          block = create(:better_together_content_mermaid_diagram, theme: 'dark')
          expect(block.theme).to eq('dark')
        end
      end

      describe 'associations' do
        it { is_expected.to have_many(:page_blocks).dependent(:destroy) }
        it { is_expected.to have_many(:pages).through(:page_blocks) }

        # TODO: Future enhancement - PNG generation for non-JavaScript fallback
        it 'has one attached rendered_image' do
          skip 'PNG generation feature not yet implemented'
          expect(mermaid_block).to respond_to(:rendered_image)
        end
      end

      describe 'validations' do
        context 'when diagram_source is present' do
          it { is_expected.to be_valid }
          it { is_expected.not_to validate_presence_of(:diagram_file_path) }
        end

        context 'when diagram_file_path is present' do
          subject(:mermaid_block) { build(:better_together_content_mermaid_diagram, diagram_source: nil, diagram_file_path: test_file_path) }

          let(:test_file_path) { Rails.root.join('tmp', 'test_diagram.mmd').to_s }

          before do
            FileUtils.mkdir_p(File.dirname(test_file_path))
            File.write(test_file_path, "graph TD\n  A-->B")
          end

          after do
            FileUtils.rm_f(test_file_path)
          end

          it { is_expected.to be_valid }
        end

        context 'when neither source nor file_path is provided' do
          subject(:mermaid_block) { build(:better_together_content_mermaid_diagram, diagram_source: nil, diagram_file_path: nil) }

          it 'is invalid' do
            expect(mermaid_block).not_to be_valid
            expect(mermaid_block.errors[:base]).to include('Either diagram source or file path must be provided')
          end
        end

        describe 'file_path validation' do
          context 'when file exists' do
            let(:file_path) { 'docs/diagrams/source/test.mmd' }

            before do
              allow(File).to receive(:exist?).with(Rails.root.join(file_path)).and_return(true)
            end

            it 'is valid' do
              block = build(:better_together_content_mermaid_diagram, diagram_file_path: file_path)
              expect(block).to be_valid
            end
          end

          context 'when file does not exist' do
            subject(:mermaid_block) do
              build(:better_together_content_mermaid_diagram, diagram_source: nil, diagram_file_path: '/nonexistent/file.mmd')
            end

            it 'is invalid' do
              expect(mermaid_block).not_to be_valid
              expect(mermaid_block.errors[:diagram_file_path]).to include('file not found')
            end
          end

          context 'when file has wrong extension' do
            subject(:mermaid_block) { build(:better_together_content_mermaid_diagram, diagram_source: nil, diagram_file_path: 'test.txt') }

            it 'is invalid' do
              expect(mermaid_block).not_to be_valid
              expect(mermaid_block.errors[:diagram_file_path]).to include('must be a .mmd file')
            end
          end
        end

        describe 'theme validation' do
          it 'accepts default theme' do
            block = build(:better_together_content_mermaid_diagram, theme: 'default')
            expect(block).to be_valid
          end

          it 'accepts dark theme' do
            block = build(:better_together_content_mermaid_diagram, theme: 'dark')
            expect(block).to be_valid
          end

          it 'accepts forest theme' do
            block = build(:better_together_content_mermaid_diagram, theme: 'forest')
            expect(block).to be_valid
          end

          it 'accepts neutral theme' do
            block = build(:better_together_content_mermaid_diagram, theme: 'neutral')
            expect(block).to be_valid
          end

          it 'rejects invalid theme' do
            block = build(:better_together_content_mermaid_diagram, theme: 'invalid')
            expect(block).not_to be_valid
            expect(block.errors[:theme]).to include('is not included in the list')
          end
        end

        describe 'mermaid syntax validation' do
          it 'accepts valid flowchart syntax' do
            block = build(:better_together_content_mermaid_diagram,
                          diagram_source: "graph TD\n  A[Start] --> B[End]")
            expect(block).to be_valid
          end

          it 'accepts valid sequence diagram syntax' do
            block = build(:better_together_content_mermaid_diagram,
                          diagram_source: "sequenceDiagram\n  Alice->>Bob: Hello")
            expect(block).to be_valid
          end

          it 'rejects invalid syntax' do
            block = build(:better_together_content_mermaid_diagram,
                          diagram_source: 'invalid mermaid syntax')
            expect(block).not_to be_valid
            expect(block.errors[:base].first).to include('Invalid mermaid syntax')
          end

          it 'rejects empty diagram content' do
            block = build(:better_together_content_mermaid_diagram,
                          diagram_source: 'graph TD')
            expect(block).not_to be_valid
            expect(block.errors[:base].first).to include('Diagram appears to be empty')
          end

          it 'does not validate when content is blank' do
            block = build(:better_together_content_mermaid_diagram,
                          diagram_source: '',
                          diagram_file_path: nil)
            # Should fail on presence validation, not syntax validation
            expect(block).not_to be_valid
            expect(block.errors[:base]).to include('Either diagram source or file path must be provided')
          end
        end
      end

      describe 'translatable attributes' do
        it 'has diagram_source as a translatable attribute' do
          expect(described_class.mobility_attributes).to include('diagram_source')
        end

        it 'has caption as a translatable attribute' do
          expect(described_class.mobility_attributes).to include('caption')
        end

        it 'allows setting diagram_source in different locales' do
          block = create(:better_together_content_mermaid_diagram)
          I18n.with_locale(:es) do
            block.diagram_source = "graph TD\n  A-->B"
            block.save!
          end

          expect(block.diagram_source).not_to eq("graph TD\n  A-->B")
          I18n.with_locale(:es) do
            expect(block.diagram_source).to eq("graph TD\n  A-->B")
          end
        end
      end

      describe 'store_attributes' do
        it 'stores diagram_file_path in content_data' do
          block = build(:better_together_content_mermaid_diagram, diagram_file_path: 'test.mmd')
          expect(block.content_data).to include('diagram_file_path')
        end

        it 'stores theme in content_data' do
          block = build(:better_together_content_mermaid_diagram, theme: 'dark')
          expect(block.content_data).to include('theme')
          expect(block.theme).to eq('dark')
        end

        it 'stores auto_height in content_data' do
          block = build(:better_together_content_mermaid_diagram, auto_height: true)
          expect(block.content_data).to include('auto_height')
          expect(block.auto_height).to be true
        end

        it 'defaults auto_height to true' do
          block = build(:better_together_content_mermaid_diagram)
          expect(block.auto_height).to be true
        end

        it 'defaults theme to "default"' do
          block = build(:better_together_content_mermaid_diagram)
          expect(block.theme).to eq('default')
        end
      end

      describe '#content' do
        context 'when using diagram_source' do
          it 'returns the diagram_source' do
            block = build(:better_together_content_mermaid_diagram, diagram_source: "graph TD\n  A-->B")
            expect(block.content).to eq("graph TD\n  A-->B")
          end
        end

        context 'when using diagram_file_path' do
          let(:file_path) { 'docs/diagrams/source/test.mmd' }
          let(:file_content) { "graph TD\n  Start-->End" }

          before do
            allow(File).to receive(:exist?).with(Rails.root.join(file_path)).and_return(true)
            allow(File).to receive(:read).with(Rails.root.join(file_path)).and_return(file_content)
          end

          it 'returns the file content' do
            block = build(:better_together_content_mermaid_diagram, diagram_source: nil, diagram_file_path: file_path)
            expect(block.content).to eq(file_content)
          end
        end

        context 'when both source and file_path are provided' do
          let(:file_path) { 'docs/diagrams/source/test.mmd' }

          before do
            allow(File).to receive(:exist?).with(Rails.root.join(file_path)).and_return(true)
          end

          it 'prefers diagram_source' do
            block = build(:better_together_content_mermaid_diagram,
                          diagram_source: "graph TD\n  A-->B",
                          diagram_file_path: file_path)
            expect(block.content).to eq("graph TD\n  A-->B")
          end
        end

        context 'when file does not exist' do
          it 'returns empty string' do
            block = build(:better_together_content_mermaid_diagram, diagram_source: nil, diagram_file_path: '/nonexistent.mmd')
            expect(block.content).to eq('')
          end
        end
      end

      describe '.content_addable?' do
        it 'returns true' do
          expect(described_class.content_addable?).to be true
        end
      end

      describe '.permitted_attributes' do
        it 'includes diagram_source' do
          expect(described_class.permitted_attributes).to include(:diagram_source)
        end

        it 'includes diagram_file_path' do
          expect(described_class.permitted_attributes).to include(:diagram_file_path)
        end

        it 'includes caption' do
          expect(described_class.permitted_attributes).to include(:caption)
        end

        it 'includes theme' do
          expect(described_class.permitted_attributes).to include(:theme)
        end

        it 'includes auto_height' do
          expect(described_class.permitted_attributes).to include(:auto_height)
        end
      end

      describe 'caching' do
        it 'has a cache_key_with_version' do
          block = create(:better_together_content_mermaid_diagram)
          expect(block.cache_key_with_version).to be_present
        end

        it 'cache key changes when content updates' do
          block = create(:better_together_content_mermaid_diagram)
          original_key = block.cache_key_with_version
          block.update!(diagram_source: "graph LR\n  X-->Y")
          expect(block.cache_key_with_version).not_to eq(original_key)
        end
      end

      # TODO: Future enhancement - PNG generation for non-JavaScript fallback
      # These tests are pending until PNG generation is implemented
      describe 'PNG generation callbacks' do
        describe '#should_generate_png?' do
          it 'returns true when diagram_source changes' do
            skip 'PNG generation feature not yet implemented'
            block = create(:better_together_content_mermaid_diagram)
            block.diagram_source = "graph LR\n  X-->Y"
            block.save!
            expect(block.should_generate_png?).to be true
          end

          it 'returns true when theme changes' do
            skip 'PNG generation feature not yet implemented'
            block = create(:better_together_content_mermaid_diagram)
            block.theme = 'dark'
            block.save!
            expect(block.should_generate_png?).to be true
          end

          it 'returns true when diagram_file_path changes' do
            skip 'PNG generation feature not yet implemented'
            block = create(:better_together_content_mermaid_diagram)
            block.diagram_file_path = 'new/path.mmd'
            expect(block.should_generate_png?).to be false # not saved yet

            allow(File).to receive_messages(exist?: true, read: "graph TD\n  A-->B")
            block.save!
            expect(block.should_generate_png?).to be true
          end

          it 'returns false when unrelated attribute changes' do
            skip 'PNG generation feature not yet implemented'
            block = create(:better_together_content_mermaid_diagram)
            block.caption = 'New caption'
            block.save!
            expect(block.should_generate_png?).to be false
          end
        end

        describe 'after_save callback' do
          it 'enqueues PNG generation job when diagram_source changes' do
            skip 'PNG generation feature not yet implemented'
            block = create(:better_together_content_mermaid_diagram)
            expect do
              block.update!(diagram_source: "graph LR\n  X-->Y")
            end.to have_enqueued_job(BetterTogether::Content::GenerateMermaidPngJob).with(block.id)
          end

          it 'enqueues PNG generation job when theme changes' do
            skip 'PNG generation feature not yet implemented'
            block = create(:better_together_content_mermaid_diagram)
            expect do
              block.update!(theme: 'dark')
            end.to have_enqueued_job(BetterTogether::Content::GenerateMermaidPngJob).with(block.id)
          end

          it 'does not enqueue job when caption changes' do
            skip 'PNG generation feature not yet implemented'
            block = create(:better_together_content_mermaid_diagram)
            expect do
              block.update!(caption: 'New caption')
            end.not_to have_enqueued_job(BetterTogether::Content::GenerateMermaidPngJob)
          end

          it 'does not enqueue job when auto_height changes' do
            skip 'PNG generation feature not yet implemented'
            block = create(:better_together_content_mermaid_diagram)
            expect do
              block.update!(auto_height: false)
            end.not_to have_enqueued_job(BetterTogether::Content::GenerateMermaidPngJob)
          end
        end
      end

      describe 'Active Storage attachment' do
        it 'can attach a PNG image' do
          skip 'PNG generation feature not yet implemented'
          block = create(:better_together_content_mermaid_diagram)
          png_data = "\x89PNG\r\n\x1a\n".dup.force_encoding('ASCII-8BIT')

          block.rendered_image.attach(
            io: StringIO.new(png_data),
            filename: 'diagram.png',
            content_type: 'image/png'
          )

          expect(block.rendered_image).to be_attached
          expect(block.rendered_image.filename.to_s).to eq('diagram.png')
          expect(block.rendered_image.content_type).to eq('image/png')
        end
      end
    end
  end
end
