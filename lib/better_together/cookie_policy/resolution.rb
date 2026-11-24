# frozen_string_literal: true

# Better Together engine namespace.
module BetterTogether
  module CookiePolicy
    # Turns a registered segment into what a visitor reads: conditions evaluated, cookies listed for
    # the platform, wording translated into the current locale.
    module Resolution
      private

      def resolve(segment, platform)
        return unless visible?(segment, platform)

        Resolved.new(key: segment.key, category: segment.category,
                     title: text(segment.title, platform), description: text(segment.description, platform),
                     cookies: resolve_cookies(segment, platform), privacy_url: segment.privacy_url,
                     updated_on: segment.updated_on)
      end

      # A failing condition keeps the segment visible: disclosing too much beats hiding a cookie.
      def visible?(segment, platform)
        segment.condition.nil? || segment.condition.call(platform) ? true : false
      rescue StandardError
        true
      end

      def resolve_cookies(segment, platform)
        list = segment.cookies.respond_to?(:call) ? segment.cookies.call(platform) : segment.cookies
        Array(list).map { |cookie| build_cookie(cookie.to_h.symbolize_keys, platform) }
      rescue StandardError
        []
      end

      def build_cookie(data, platform)
        Cookie.new(name: data[:name].to_s, purpose: text(data[:purpose], platform),
                   duration: text(data[:duration], platform), provider: text(data[:provider], platform),
                   party: (data[:party] || :first).to_sym)
      end

      # Literals pass through; a Symbol or a dotted i18n key is translated; a callable gets the platform.
      def text(value, platform)
        value = value.call(platform) if value.respond_to?(:call)
        case value
        when nil then nil
        when Symbol then I18n.t(value, default: value.to_s)
        when String then value.match?(KEY_PATTERN) ? I18n.t(value, default: value) : value
        else value.to_s
        end
      end
    end
  end
end
