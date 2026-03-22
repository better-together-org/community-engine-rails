# frozen_string_literal: true

module BetterTogether
  module Content
    # Renders markdown content from source or file
    class Markdown < Block # rubocop:disable Metrics/ClassLength
      include Translatable

      translates :markdown_source, type: :text

      store_attributes :content_data do
        markdown_file_path String
        auto_sync_from_file Boolean, default: false
      end

      validate :markdown_source_or_file_path_present
      validate :file_must_exist, if: :markdown_file_path?
      validate :file_must_be_markdown, if: :markdown_file_path?

      # Load file content before validation if file path changed
      before_validation :load_file_into_source,
                        if: -> { markdown_file_path_changed? && auto_sync_from_file? }

      # Define permitted attributes for controller strong parameters
      def self.permitted_attributes
        %i[markdown_source markdown_file_path auto_sync_from_file]
      end

      # Get markdown content from either source or file
      def content
        return markdown_source if markdown_source.present? && !auto_sync_from_file?
        return load_markdown_file_for_current_locale if markdown_file_path.present?

        ''
      end

      # Manually import file content into markdown_source for all locales
      def import_file_content!(sync_future_changes: false)
        return false unless markdown_file_path.present?

        load_localized_files
        self.auto_sync_from_file = sync_future_changes
        save!
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
          localized_content: I18n.available_locales.index_with do |locale|
            I18n.with_locale(locale) do
              rendered_plain_text
            end
          end
        }
      end

      # Check if content contains mermaid diagrams
      def contains_mermaid?
        return false if content.blank?

        # Check for mermaid code blocks or mermaid file references
        content.match?(/```mermaid|\.mmd['"]?\s*\)|\.mmd['"]?\s*\]/)
      end

      private

      def markdown_source_or_file_path_present
        return if markdown_source.present? || markdown_file_path.present?

        errors.add(:base, 'Either markdown source or file path must be provided')
      end

      def load_file_into_source
        load_localized_files
      end

      def load_localized_files # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
        base_path = markdown_file_path.sub(/\.(md|markdown)$/i, '')

        I18n.available_locales.each do |locale|
          load_locale_file(base_path, locale)
        end
      end

      def load_locale_file(base_path, locale)
        # Try locale-specific file first
        locale_file = "#{base_path}.#{locale}.md"
        resolved_path = resolve_file_path_for(locale_file)

        if File.exist?(resolved_path)
          set_markdown_for_locale(locale, resolved_path)
        elsif locale == I18n.default_locale
          load_default_file_for_locale(locale)
        end
      end

      def set_markdown_for_locale(locale, file_path)
        I18n.with_locale(locale) do
          self.markdown_source = File.read(file_path)
        end
      end

      def load_default_file_for_locale(locale)
        default_path = resolve_file_path
        return unless File.exist?(default_path)

        set_markdown_for_locale(locale, default_path)
      end

      def load_markdown_file_for_current_locale
        base_path = markdown_file_path.sub(/\.(md|markdown)$/i, '')
        locale_file = "#{base_path}.#{I18n.locale}.md"

        # Try locale-specific, fallback to default
        [locale_file, markdown_file_path].each do |file|
          path = resolve_file_path_for(file)
          return File.read(path) if File.exist?(path)
        end

        ''
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

      def resolve_file_path_for(path)
        return Pathname.new(path) if Pathname.new(path).absolute?

        Rails.root.join(path)
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
