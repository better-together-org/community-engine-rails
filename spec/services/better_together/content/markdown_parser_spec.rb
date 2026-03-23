# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Content::MarkdownParser do
  describe '#parse' do
    context 'with plain markdown (no diagrams)' do
      it 'returns a single markdown segment' do
        content = <<~MARKDOWN
          # Hello World

          This is some content.
        MARKDOWN

        parser = described_class.new(content)
        segments = parser.parse

        expect(segments.length).to eq(1)
        expect(segments[0][:type]).to eq(:markdown)
        expect(segments[0][:content]).to eq(content)
      end
    end

    context 'with inline mermaid diagram' do
      it 'splits into markdown, diagram, markdown segments' do
        content = <<~MARKDOWN
          # Before Diagram

          Some text before.

          ```mermaid
          graph TD
            A --> B
          ```

          Some text after.
        MARKDOWN

        parser = described_class.new(content)
        segments = parser.parse

        expect(segments.length).to eq(3)

        expect(segments[0][:type]).to eq(:markdown)
        expect(segments[0][:content]).to include('# Before Diagram')
        expect(segments[0][:content]).to include('Some text before.')

        expect(segments[1][:type]).to eq(:mermaid_inline)
        expect(segments[1][:content]).to include('graph TD')
        expect(segments[1][:content]).to include('A --> B')
        expect(segments[1][:content]).not_to include('```')

        expect(segments[2][:type]).to eq(:markdown)
        expect(segments[2][:content]).to include('Some text after.')
      end

      it 'extracts diagram attributes from comment metadata' do
        content = <<~MARKDOWN
          # Diagram Example

          <!-- mermaid-diagram: caption="User Flow", theme="dark" -->
          ```mermaid
          flowchart LR
            User --> System
          ```
        MARKDOWN

        parser = described_class.new(content)
        segments = parser.parse

        expect(segments.length).to eq(2)
        expect(segments[1][:type]).to eq(:mermaid_inline)
        expect(segments[1][:attributes]).to eq({
                                                 caption: 'User Flow',
                                                 theme: 'dark'
                                               })
      end

      it 'handles multiple diagrams in one file' do
        content = <<~MARKDOWN
          # Introduction

          ```mermaid
          graph TD
            A --> B
          ```

          Middle section.

          ```mermaid
          sequenceDiagram
            Alice->>Bob: Hello
          ```

          Conclusion.
        MARKDOWN

        parser = described_class.new(content)
        segments = parser.parse

        expect(segments.length).to eq(5)
        expect(segments[0][:type]).to eq(:markdown)
        expect(segments[1][:type]).to eq(:mermaid_inline)
        expect(segments[2][:type]).to eq(:markdown)
        expect(segments[3][:type]).to eq(:mermaid_inline)
        expect(segments[4][:type]).to eq(:markdown)
      end
    end

    context 'with file-referenced mermaid diagram' do
      it 'detects mermaid file reference syntax' do
        content = <<~MARKDOWN
          # System Architecture

          The following diagram shows our architecture:

          <!-- mermaid-file: docs/diagrams/source/system_flow.mmd -->

          As you can see above...
        MARKDOWN

        parser = described_class.new(content)
        segments = parser.parse

        expect(segments.length).to eq(3)

        expect(segments[0][:type]).to eq(:markdown)
        expect(segments[0][:content]).to include('# System Architecture')

        expect(segments[1][:type]).to eq(:mermaid_file)
        expect(segments[1][:file_path]).to eq('docs/diagrams/source/system_flow.mmd')

        expect(segments[2][:type]).to eq(:markdown)
        expect(segments[2][:content]).to include('As you can see above...')
      end

      it 'extracts attributes from file reference' do
        content = <<~MARKDOWN
          # Flow Diagram

          <!-- mermaid-file: docs/diagrams/source/user_flow.mmd, caption="User Registration Flow", theme="neutral" -->
        MARKDOWN

        parser = described_class.new(content)
        segments = parser.parse

        expect(segments.length).to eq(2)
        expect(segments[1][:type]).to eq(:mermaid_file)
        expect(segments[1][:file_path]).to eq('docs/diagrams/source/user_flow.mmd')
        expect(segments[1][:attributes]).to eq({
                                                 caption: 'User Registration Flow',
                                                 theme: 'neutral'
                                               })
      end
    end

    context 'with consecutive diagrams' do
      it 'handles diagrams with no markdown between them' do
        content = <<~MARKDOWN
          # Diagrams

          ```mermaid
          graph TD
            A --> B
          ```
          ```mermaid
          graph LR
            C --> D
          ```
        MARKDOWN

        parser = described_class.new(content)
        segments = parser.parse

        expect(segments.length).to eq(3)
        expect(segments[0][:type]).to eq(:markdown)
        expect(segments[1][:type]).to eq(:mermaid_inline)
        expect(segments[2][:type]).to eq(:mermaid_inline)
      end
    end

    context 'with only diagrams (no markdown)' do
      it 'returns only diagram segments' do
        content = <<~MARKDOWN
          ```mermaid
          graph TD
            A --> B
          ```
        MARKDOWN

        parser = described_class.new(content)
        segments = parser.parse

        expect(segments.length).to eq(1)
        expect(segments[0][:type]).to eq(:mermaid_inline)
      end
    end

    context 'edge cases' do
      it 'preserves whitespace in markdown segments' do
        content = <<~MARKDOWN
          # Title



          Paragraph with blank lines above.
        MARKDOWN

        parser = described_class.new(content)
        segments = parser.parse

        expect(segments[0][:content]).to eq(content)
      end
    end
  end
end
