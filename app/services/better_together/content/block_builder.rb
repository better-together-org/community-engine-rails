# frozen_string_literal: true

module BetterTogether
  module Content
    # Builds content blocks from parsed markdown segments
    class BlockBuilder
      class << self
        def build_from_segments(segments, _page = nil)
          segments.map { |segment| build_block_from_segment(segment) }
        end

        private

        def build_block_from_segment(segment) # rubocop:disable Metrics/MethodLength
          case segment[:type]
          when :markdown
            BetterTogether::Content::Markdown.new(
              markdown_source: segment[:content]
            )
          when :mermaid_inline
            build_mermaid_diagram(
              diagram_source: segment[:content],
              attributes: segment[:attributes] || {}
            )
          when :mermaid_file
            build_mermaid_diagram(
              diagram_file_path: segment[:file_path],
              attributes: segment[:attributes] || {}
            )
          else
            raise ArgumentError, "Unknown segment type: #{segment[:type]}"
          end
        end

        def build_mermaid_diagram(diagram_source: nil, diagram_file_path: nil, attributes: {})
          BetterTogether::Content::MermaidDiagram.new(
            diagram_source: diagram_source,
            diagram_file_path: diagram_file_path,
            caption: attributes[:caption],
            theme: attributes[:theme] || 'default'
          )
        end
      end
    end
  end
end
