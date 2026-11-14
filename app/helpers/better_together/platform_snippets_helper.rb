# frozen_string_literal: true

module BetterTogether
  # Renders the current platform's enabled code snippets at a layout injection point.
  # Fail-open: a broken snippet is logged and skipped, it never raises a 500.
  module PlatformSnippetsHelper
    SAFE_MODE_PARAM = 'safe_mode'

    def render_platform_snippets(location, platform = host_platform)
      return unless platform_snippets_active?(platform)

      fragments = platform_snippets_for(platform).select { |snippet| snippet.location == location.to_s }
                                                 .filter_map { |snippet| render_platform_snippet(snippet) }
      safe_join(fragments, "\n").presence
    rescue StandardError => e
      BetterTogether.report_error(e, context: { component: 'platform_snippets', location: location.to_s })
      nil
    end

    # Kill switch off, or safe mode requested by someone allowed to manage the code.
    def platform_snippets_active?(platform)
      return false unless platform.persisted? && platform.snippets_enabled?

      !(params[SAFE_MODE_PARAM] == '1' && platform_code_manager?(platform))
    end

    def platform_code_manager?(platform)
      current_user&.person&.permitted_to?('manage_platform_code', platform) || false
    end

    private

    # Consent-gated categories are not rendered here: they wait for the visitor's consent.
    def platform_snippets_for(platform)
      @platform_snippets_for ||= platform.platform_snippets.enabled.where(consent_category: 'none')
                                         .reorder(:position).to_a.select { |snippet| snippet_visible?(snippet) }
    end

    def snippet_visible?(snippet)
      snippet.applies_to == 'all' || current_user.blank?
    end

    def render_platform_snippet(snippet)
      markup = snippet_markup(snippet)
      markup.presence
    rescue StandardError => e
      BetterTogether.report_error(e, context: { component: 'platform_snippets', snippet_id: snippet.id })
      nil
    end

    def snippet_markup(snippet)
      data = { platform_snippet: snippet.id }
      case snippet.kind
      when 'script_inline' then javascript_tag(snippet.content, nonce: true, data:)
      when 'script_src' then script_src_snippet_tag(snippet)
      when 'style_inline' then content_tag(:style, snippet.content.html_safe, data:) # rubocop:disable Rails/OutputSafety
      when 'html_meta' then safe_join(snippet.meta_tags.map { |meta| tag(meta[:name], meta[:attributes].symbolize_keys) }, "\n")
      end
    end

    # Re-checked at render time: an origin removed from the allow-list stops loading at once.
    def script_src_snippet_tag(snippet)
      return unless snippet.origin_allowed?

      javascript_include_tag(snippet.src, nonce: true, defer: true, data: { platform_snippet: snippet.id })
    end
  end
end
