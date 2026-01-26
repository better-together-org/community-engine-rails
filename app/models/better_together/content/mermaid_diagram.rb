# frozen_string_literal: true

require 'storext'

module BetterTogether
  module Content
    # Renders Mermaid diagram content from source or file
    class MermaidDiagram < Block
      include Translatable

      VALID_THEMES = %w[default dark forest neutral].freeze

      # TODO: Future enhancement - Add PNG generation for non-JavaScript fallback
      # has_one_attached :rendered_image

      translates :diagram_source, type: :text
      translates :caption, type: :string

      store_attributes :content_data do
        diagram_file_path String
        theme String, default: 'default'
        auto_height Boolean, default: true
      end

      validate :diagram_source_or_file_path_present
      validate :file_must_exist, if: :diagram_file_path?
      validate :file_must_be_mermaid, if: :diagram_file_path?
      validate :mermaid_syntax_valid
      validates :theme, inclusion: { in: VALID_THEMES }

      # TODO: Future enhancement - Re-enable PNG generation callback
      # after_save :enqueue_png_generation, if: :should_generate_png?

      # Get diagram content from either source or file
      def content
        return diagram_source if diagram_source.present?
        return load_diagram_file if diagram_file_path.present?

        ''
      end

      def self.content_addable?
        true
      end

      def self.permitted_attributes
        %i[diagram_source diagram_file_path caption theme auto_height]
      end

      # TODO: Future enhancement - Re-enable PNG generation logic
      # Check if PNG generation should be triggered based on changes
      # def should_generate_png?
      #   diagram_source_changed = saved_changes.keys.any? { |key| key.to_s.start_with?('diagram_source') }
      #   diagram_source_changed || saved_change_to_diagram_file_path? || saved_change_to_theme?
      # end

      private

      def diagram_source_or_file_path_present
        return if diagram_source.present? || diagram_file_path.present?

        errors.add(:base, 'Either diagram source or file path must be provided')
      end

      def load_diagram_file
        file_path = resolve_file_path
        return '' unless File.exist?(file_path)

        File.read(file_path)
      end

      def resolve_file_path
        return Pathname.new(diagram_file_path) if Pathname.new(diagram_file_path).absolute?

        # Try Rails.root first (for host apps)
        rails_path = Rails.root.join(diagram_file_path)
        return rails_path if File.exist?(rails_path)

        # Fall back to engine root (for development/testing)
        BetterTogether::Engine.root.join(diagram_file_path)
      end

      def file_must_exist
        file_path = resolve_file_path
        return if File.exist?(file_path)

        errors.add(:diagram_file_path, 'file not found')
      end

      def file_must_be_mermaid
        return if diagram_file_path.match?(/\.mmd$/i)

        errors.add(:diagram_file_path, 'must be a .mmd file')
      end

      def mermaid_syntax_valid
        return if content.blank?

        validator = BetterTogether::Content::MermaidValidator.new(content)
        return if validator.valid?

        errors.add(:base, "Invalid mermaid syntax: #{validator.errors.join(', ')}")
      end

      # TODO: Future enhancement - Re-enable PNG generation job
      # def enqueue_png_generation
      #   BetterTogether::Content::GenerateMermaidPngJob.perform_later(id)
      # end
    end
  end
end
