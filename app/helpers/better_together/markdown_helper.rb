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
  end
end
