# frozen_string_literal: true

module BetterTogether
  # Helper methods for rendering markdown content
  module MarkdownHelper
    # Renders markdown source to HTML
    #
    # @param source [String] The markdown source text
    # @param options [Hash] Optional rendering options to pass to MarkdownRendererService
    # @return [ActiveSupport::SafeBuffer] HTML-safe rendered markdown
    #
    # @example
    #   <%= render_markdown("# Hello\n\nThis is **bold** text.") %>
    def render_markdown(source, options = {})
      return '' if source.blank?

      MarkdownRendererService.new(source, options).render_html
    end

    # Renders markdown from a file path to HTML
    #
    # @param file_path [String] Path to the markdown file (absolute or relative to Rails.root)
    # @param options [Hash] Optional rendering options to pass to MarkdownRendererService
    # @return [ActiveSupport::SafeBuffer] HTML-safe rendered markdown
    #
    # @example
    #   <%= render_markdown_file('docs/README.md') %>
    def render_markdown_file(file_path, options = {})
      return '' if file_path.blank?

      # Resolve relative paths to Rails.root
      full_path = if Pathname.new(file_path).absolute?
                    file_path
                  else
                    Rails.root.join(file_path).to_s
                  end

      return '' unless File.exist?(full_path)

      markdown_source = File.read(full_path)
      render_markdown(markdown_source, options)
    rescue Errno::ENOENT => e
      Rails.logger.error("Failed to read markdown file: #{e.message}")
      ''
    end

    # Renders markdown to plain text (strips HTML)
    #
    # @param source [String] The markdown source text
    # @param options [Hash] Optional rendering options to pass to MarkdownRendererService
    # @return [String] Plain text without HTML tags
    #
    # @example
    #   <%= render_markdown_plain("# Hello\n\nThis is **bold** text.") %>
    def render_markdown_plain(source, options = {})
      return '' if source.blank?

      MarkdownRendererService.new(source, options).render_plain_text
    end

    # Renders markdown with automatic locale detection for file paths
    #
    # @param file [String, nil] Path to markdown file (with automatic locale detection)
    # @param text [String, nil] Direct markdown text content
    # @param locale [Symbol] Locale to use (defaults to current locale)
    # @param options [Hash] Optional rendering options to pass to MarkdownRendererService
    # @return [ActiveSupport::SafeBuffer] HTML-safe rendered markdown
    #
    # @example
    #   <%= render_markdown_block(file: 'policies/privacy') %>
    #   <%= render_markdown_block(text: t('content.welcome')) %>
    def render_markdown_block(file: nil, text: nil, locale: I18n.locale, options: {})
      I18n.with_locale(locale) do
        content = if file.present?
                    read_localized_file(file)
                  else
                    text
                  end

        render_markdown(content, options)
      end
    end

    private

    # Read a localized markdown file with automatic locale detection
    #
    # @param base_path [String] Base path to the markdown file (without locale extension)
    # @return [String] File content or empty string if not found
    def read_localized_file(base_path)
      # Remove .md extension if present
      base = base_path.sub(/\.(md|markdown)$/i, '')

      # Try current locale, then fallback to English, then original
      [
        "#{base}.#{I18n.locale}.md",
        "#{base}.en.md",
        "#{base}.md"
      ].each do |filename|
        path = Rails.root.join('app', 'views', filename)
        return File.read(path) if File.exist?(path)
      end

      Rails.logger.warn("Markdown file not found: #{base_path}")
      ''
    rescue Errno::ENOENT => e
      Rails.logger.error("Failed to read localized markdown file: #{e.message}")
      ''
    end
  end
end
