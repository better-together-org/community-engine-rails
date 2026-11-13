# frozen_string_literal: true

module BetterTogether
  # Removes HTML comments (view annotations such as "<!-- Navbar -->" and
  # partial path markers) from HTML responses so they do not leak to visitors.
  # Comments inside script, style, pre and textarea are left alone, as are
  # IE conditional comments.
  class HtmlCommentStripper
    COMMENT = /<!--(?!\[if|<!\[endif).*?-->/m
    PROTECTED = %r{(<(script|style|pre|textarea)\b.*?</\2\s*>)}mi

    def initialize(app)
      @app = app
    end

    def call(env)
      status, headers, body = @app.call(env)
      return [status, headers, body] unless strippable?(status, headers)

      stripped = strip(read_body(body))
      %w[content-length Content-Length].each { |key| headers[key] = stripped.bytesize.to_s if headers.key?(key) }
      [status, headers, [stripped]]
    end

    def strip(html)
      html.split(PROTECTED).each_slice(3).map do |segment, protected_block, _tag|
        "#{segment.gsub(COMMENT, '')}#{protected_block}"
      end.join
    end

    private

    def read_body(body)
      html = +''
      body.each { |chunk| html << chunk }
      body.close if body.respond_to?(:close)
      html
    end

    def strippable?(status, headers)
      return false unless status == 200

      content_type = (headers['content-type'] || headers['Content-Type']).to_s
      encoding = (headers['content-encoding'] || headers['Content-Encoding']).to_s
      content_type.start_with?('text/html') && encoding.empty?
    end
  end
end
