# frozen_string_literal: true

module BetterTogether
  module Content
    # Renders markdown content from source or file
    class Markdown < Block
      store_attributes :content_data do
        markdown_source String
        markdown_file_path String
      end

      validate :markdown_source_or_file_path_present
      validate :file_must_exist, if: :markdown_file_path?
      validate :file_must_be_markdown, if: :markdown_file_path?

      # Define permitted attributes for controller strong parameters
      def self.permitted_attributes
        %i[markdown_source markdown_file_path]
      end

      # Get markdown content from either source or file
      def content
        if markdown_source.present?
          markdown_source
        elsif markdown_file_path.present?
          load_markdown_file
        else
          ''
        end
      end

      # Render markdown content as HTML
      def rendered_html
        return '' if content.blank?

        BetterTogether::MarkdownRendererService.new(content, {}).render_html
      end

      # Render markdown content as plain text for indexing
      def rendered_plain_text
        return '' if content.blank?

        BetterTogether::MarkdownRendererService.new(content, {}).render_plain_text
      end

      # Provide indexed JSON representation for search
      def as_indexed_json(_options = {})
        {
          id:,
          localized_content: I18n.available_locales.index_with do |_locale|
            rendered_plain_text
          end
        }
      end

      private

      def markdown_source_or_file_path_present
        return if markdown_source.present? || markdown_file_path.present?

        errors.add(:base, 'Either markdown source or file path must be provided')
      end

      def load_markdown_file
        file_path = resolve_file_path
        return '' unless File.exist?(file_path)

        File.read(file_path)
      end

      def resolve_file_path
        return Pathname.new(markdown_file_path) if Pathname.new(markdown_file_path).absolute?

        Rails.root.join(markdown_file_path)
      end

      def file_must_exist
        file_path = resolve_file_path
        return if File.exist?(file_path)

        errors.add(:markdown_file_path, :file_not_found, path: markdown_file_path)
      end

      def file_must_be_markdown
        return if markdown_file_path.match?(/\.(md|markdown)$/i)

        errors.add(:markdown_file_path, :invalid_file_type)
      end
    end
  end
end
