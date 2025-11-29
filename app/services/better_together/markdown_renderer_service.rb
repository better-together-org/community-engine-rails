# frozen_string_literal: true

require 'redcarpet'

module BetterTogether
  # Service to render markdown content to HTML and plain text
  class MarkdownRendererService
    attr_reader :markdown_source, :options

    def initialize(markdown_source, options = {})
      @markdown_source = markdown_source
      @options = default_options.deep_merge(options)
    end

    # Render markdown to HTML
    def render_html
      return ''.html_safe if markdown_source.blank?

      renderer.render(markdown_source).html_safe
    end

    # Render markdown to plain text (for search indexing)
    def render_plain_text
      return '' if markdown_source.blank?

      # Strip HTML tags from rendered HTML
      ActionView::Base.full_sanitizer.sanitize(render_html)
    end

    private

    def renderer
      @renderer ||= Redcarpet::Markdown.new(
        html_renderer,
        options[:extensions]
      )
    end

    def html_renderer
      Redcarpet::Render::HTML.new(options[:render_options])
    end

    def default_options # rubocop:todo Metrics/MethodLength
      {
        extensions: {
          # Enable various markdown extensions
          autolink: true,
          tables: true,
          fenced_code_blocks: true,
          strikethrough: true,
          superscript: true,
          highlight: true,
          footnotes: true,
          no_intra_emphasis: true,
          space_after_headers: true,
          underline: true
        },
        render_options: {
          # Render options for HTML output
          filter_html: false, # Allow HTML in markdown (for trusted content like docs)
          hard_wrap: true,
          link_attributes: { target: '_blank', rel: 'noopener noreferrer' },
          prettify: true,
          with_toc_data: true # Add IDs to headers for table of contents
        }
      }
    end
  end
end
