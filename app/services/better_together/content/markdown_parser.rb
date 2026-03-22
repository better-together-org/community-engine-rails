# frozen_string_literal: true

module BetterTogether
  module Content
    # Parses markdown content and extracts Mermaid diagrams into separate segments
    class MarkdownParser
      attr_reader :content, :segments

      def initialize(content)
        @content = content
        @segments = []
      end

      def parse
        return [{ type: :markdown, content: content }] if content.blank?

        parse_content
        segments
      end

      private

      def parse_content # rubocop:disable Metrics/MethodLength, Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
        current_markdown = []
        lines = content.lines
        i = 0

        while i < lines.length
          line = lines[i]

          # Check for mermaid file reference
          if (match = line.match(/<!--\s*mermaid-file:\s*(.+?)\s*-->/))
            # Save accumulated markdown before diagram
            save_markdown_segment(current_markdown) if current_markdown.any?
            current_markdown = []

            # Extract file reference and attributes
            file_info = match[1]
            segment = parse_mermaid_file_reference(file_info)
            segments << segment

            i += 1
            next
          end

          # Check for inline mermaid code block
          if line.strip == '```mermaid'
            # Save accumulated markdown before diagram
            save_markdown_segment(current_markdown) if current_markdown.any?
            current_markdown = []

            # Check for attributes in previous line
            attributes = extract_diagram_attributes(lines[i - 1]) if i.positive?

            # Extract mermaid content
            i += 1
            mermaid_content = []
            while i < lines.length && lines[i].strip != '```'
              mermaid_content << lines[i]
              i += 1
            end

            segments << {
              type: :mermaid_inline,
              content: mermaid_content.join,
              attributes: attributes || {}
            }

            i += 1 # Skip closing ```
            next
          end

          # Accumulate markdown lines
          current_markdown << line
          i += 1
        end

        # Save any remaining markdown
        save_markdown_segment(current_markdown) if current_markdown.any?
      end

      def save_markdown_segment(lines)
        return if lines.empty?

        content_text = lines.join
        segments << { type: :markdown, content: content_text } unless content_text.strip.empty?
      end

      def parse_mermaid_file_reference(file_info)
        parts = file_info.split(',').map(&:strip)
        file_path = parts[0]
        attributes = {}

        # Extract attributes from remaining parts
        parts[1..].each do |part|
          next unless (match = part.match(/(\w+)=["'](.+?)["']/))

          attributes[match[1].to_sym] = match[2]
        end

        {
          type: :mermaid_file,
          file_path: file_path,
          attributes: attributes
        }
      end

      def extract_diagram_attributes(line)
        return nil unless line

        match = line.match(/<!--\s*mermaid-diagram:\s*(.+?)\s*-->/)
        return nil unless match

        attributes = {}
        match[1].scan(/(\w+)=["'](.+?)["']/).each do |key, value|
          attributes[key.to_sym] = value
        end

        attributes.any? ? attributes : nil
      end
    end
  end
end
