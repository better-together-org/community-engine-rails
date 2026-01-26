# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Content::BlockBuilder do
  describe '.build_from_segments' do
    let(:page) { create(:better_together_page) }

    context 'with markdown segments' do
      it 'creates Markdown blocks' do
        segments = [
          { type: :markdown, content: '# Hello\n\nWorld' }
        ]

        blocks = described_class.build_from_segments(segments, page)

        expect(blocks.length).to eq(1)
        expect(blocks[0]).to be_a(BetterTogether::Content::Markdown)
        expect(blocks[0].markdown_source).to eq('# Hello\n\nWorld')
      end
    end

    context 'with inline mermaid segments' do
      it 'creates MermaidDiagram blocks with diagram_source' do
        segments = [
          {
            type: :mermaid_inline,
            content: "graph TD\n  A --> B\n",
            attributes: { caption: 'Test Flow', theme: 'dark' }
          }
        ]

        blocks = described_class.build_from_segments(segments, page)

        expect(blocks.length).to eq(1)
        expect(blocks[0]).to be_a(BetterTogether::Content::MermaidDiagram)
        expect(blocks[0].diagram_source).to eq("graph TD\n  A --> B\n")
        expect(blocks[0].caption).to eq('Test Flow')
        expect(blocks[0].theme).to eq('dark')
      end

      it 'uses default theme when not specified' do
        segments = [
          { type: :mermaid_inline, content: "flowchart LR\n  X --> Y\n", attributes: {} }
        ]

        blocks = described_class.build_from_segments(segments, page)

        expect(blocks[0].theme).to eq('default')
      end
    end

    context 'with file-referenced mermaid segments' do
      it 'creates MermaidDiagram blocks with diagram_file_path' do
        segments = [
          {
            type: :mermaid_file,
            file_path: 'docs/diagrams/source/system_flow.mmd',
            attributes: { caption: 'System Architecture', theme: 'neutral' }
          }
        ]

        blocks = described_class.build_from_segments(segments, page)

        expect(blocks.length).to eq(1)
        expect(blocks[0]).to be_a(BetterTogether::Content::MermaidDiagram)
        expect(blocks[0].diagram_file_path).to eq('docs/diagrams/source/system_flow.mmd')
        expect(blocks[0].caption).to eq('System Architecture')
        expect(blocks[0].theme).to eq('neutral')
      end
    end

    context 'with mixed segment types' do
      it 'creates blocks in correct order' do
        segments = [
          { type: :markdown, content: '# Introduction\n\nSome text.' },
          { type: :mermaid_inline, content: "graph TD\n  A --> B\n", attributes: {} },
          { type: :markdown, content: 'Middle section.' },
          { type: :mermaid_file, file_path: 'docs/diagrams/source/flow.mmd', attributes: {} },
          { type: :markdown, content: '# Conclusion' }
        ]

        blocks = described_class.build_from_segments(segments, page)

        expect(blocks.length).to eq(5)
        expect(blocks[0]).to be_a(BetterTogether::Content::Markdown)
        expect(blocks[1]).to be_a(BetterTogether::Content::MermaidDiagram)
        expect(blocks[1].diagram_source).to be_present
        expect(blocks[2]).to be_a(BetterTogether::Content::Markdown)
        expect(blocks[3]).to be_a(BetterTogether::Content::MermaidDiagram)
        expect(blocks[3].diagram_file_path).to be_present
        expect(blocks[4]).to be_a(BetterTogether::Content::Markdown)
      end
    end

    context 'with page blocks creation' do
      it 'creates page_blocks with correct positions' do
        segments = [
          { type: :markdown, content: '# First' },
          { type: :mermaid_inline, content: "graph TD\n  A --> B\n", attributes: {} },
          { type: :markdown, content: '# Second' }
        ]

        blocks = described_class.build_from_segments(segments, page)

        # Create page blocks
        blocks.each_with_index do |block, index|
          page.page_blocks.create!(block: block, position: index + 1)
        end

        expect(page.page_blocks.count).to eq(3)
        expect(page.page_blocks.positioned.pluck(:position)).to eq([1, 2, 3])
        expect(page.page_blocks.positioned[0].block).to be_a(BetterTogether::Content::Markdown)
        expect(page.page_blocks.positioned[1].block).to be_a(BetterTogether::Content::MermaidDiagram)
        expect(page.page_blocks.positioned[2].block).to be_a(BetterTogether::Content::Markdown)
      end
    end

    context 'error handling' do
      it 'raises error for unknown segment type' do
        segments = [
          { type: :unknown_type, content: 'test' }
        ]

        expect do
          described_class.build_from_segments(segments, page)
        end.to raise_error(ArgumentError, /Unknown segment type/)
      end
    end
  end
end
