# frozen_string_literal: true

module BetterTogether
  # Service to render ERB templates and extract plain text for search indexing
  class TemplateRendererService
    attr_reader :template_path

    def initialize(template_path)
      @template_path = template_path
    end

    # Render template for all locales and return hash of locale => plain text
    def render_for_all_locales
      I18n.available_locales.each_with_object({}) do |locale, content_hash|
        I18n.with_locale(locale) do
          rendered_html = render_template
          content_hash[locale] = extract_plain_text(rendered_html)
        end
      end
    end

    # Render template for current locale only
    def render_for_current_locale
      rendered_html = render_template
      extract_plain_text(rendered_html)
    end

    private

    def render_template
      view_context.render(template: full_template_path, layout: false)
    rescue StandardError => e
      Rails.logger.warn("Failed to render template #{template_path}: #{e.message}")
      template_path
    end

    def full_template_path
      # If template_path already starts with better_together/ or is a static page, use as-is
      return template_path if template_path.start_with?('better_together/')
      return "better_together/static_pages/#{template_path}" if static_page?

      template_path
    end

    def static_page?
      template_path.start_with?('better_together/static_pages/') ||
        !template_path.include?('/')
    end

    def view_context
      @view_context ||= begin
        controller = ApplicationController.new
        controller.request = ActionDispatch::TestRequest.create
        controller.response = ActionDispatch::TestResponse.new
        controller.view_context
      end
    end

    def extract_plain_text(html)
      return html unless html.is_a?(String)

      # Strip HTML tags
      plain_text = ActionView::Base.full_sanitizer.sanitize(html)
      # Clean up whitespace
      plain_text.gsub(/\s+/, ' ').strip
    end
  end
end
