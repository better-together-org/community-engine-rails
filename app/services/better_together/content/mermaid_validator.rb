# frozen_string_literal: true

module BetterTogether
  module Content
    # Validates mermaid diagram syntax
    class MermaidValidator
      attr_reader :content, :errors

      def initialize(content)
        @content = content
        @errors = []
      end

      def valid?
        validate_basic_syntax
        errors.empty?
      end

      private

      # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
      def validate_basic_syntax
        return add_error('Content cannot be blank') if content.blank?

        # Skip comments and config directives to find the actual diagram type declaration
        diagram_type_line = find_diagram_type_line
        return add_error('Missing diagram type declaration') if diagram_type_line.blank?

        valid_types = %w[
          graph flowchart sequenceDiagram classDiagram stateDiagram-v2 erDiagram
          journey gantt pie gitGraph mindmap timeline sankey C4Context
        ]

        # Check if diagram type line starts with any valid diagram type
        has_valid_type = valid_types.any? { |type| diagram_type_line.start_with?(type) }
        return add_error("Invalid diagram type. Must start with one of: #{valid_types.join(', ')}") unless has_valid_type

        # Check for basic structure issues
        add_error('Diagram appears to be empty') if content.lines.count < 2

        # Validate that flowchart/graph has direction if specified
        return unless diagram_type_line.match?(/^(graph|flowchart)\s+/)

        direction = diagram_type_line.split(/\s+/)[1]
        valid_directions = %w[TB TD BT RL LR]
        return unless direction && !valid_directions.include?(direction)

        add_error("Invalid graph direction '#{direction}'. Must be one of: #{valid_directions.join(', ')}")
      end
      # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity

      # Find the first non-comment, non-config line (the actual diagram type)
      def find_diagram_type_line
        content.strip.lines.each do |line|
          stripped = line.strip
          # Skip blank lines
          next if stripped.empty?
          # Skip comment lines (start with %%)
          next if stripped.start_with?('%%')

          # This is the diagram type line
          return stripped
        end
        nil
      end

      def add_error(message)
        @errors << message
      end
    end
  end
end
