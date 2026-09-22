# frozen_string_literal: true

module BetterTogether
  # Reads the SPF/DKIM/DMARC verification results the mail-receiver's Postfix milters
  # (policyd-spf, OpenDKIM, OpenDMARC) already stamp onto every inbound message, and exposes
  # a simple hard_fail? check for InboundEmailResolutionService to use as an additional signal
  # alongside the existing From:-address string match.
  #
  # Deliberately NOT a general RFC 8601 Authentication-Results parser -- only extracts the
  # dkim=/dmarc= result tokens, and only from header instances whose authserv-id matches the
  # configured trusted value. That authserv-id check is load-bearing, not cosmetic: headers are
  # just text, so an attacker can put a fake "Authentication-Results: mail.example.com;
  # dkim=pass" line directly in the mail they send. The real milter-inserted headers land above
  # anything the sender supplied, but only if this parser actually filters on authserv-id
  # rather than pattern-matching any dkim=pass/dmarc=pass substring in the message.
  #
  # Fails safe by construction: no mail, no headers, or an authserv-id that doesn't match the
  # trusted value all resolve to :unknown -- hard_fail? is only ever true on an explicit "fail"
  # token from a trusted, milter-inserted header. Absent the do-3 infra change that sets a
  # predictable AuthservID (see docs/mail_ingress_mvp.md), this is silently inert.
  class InboundMailAuthentication
    SPF_RESULTS = %w[pass fail softfail neutral none temperror permerror].freeze
    AUTH_RESULT_TOKENS = %w[pass fail none].freeze

    TRUSTED_AUTHSERV_ID = ENV.fetch('INBOUND_MAIL_TRUSTED_AUTHSERV_ID', nil)

    def initialize(mail, trusted_authserv_id: TRUSTED_AUTHSERV_ID)
      @mail = mail
      @trusted_authserv_id = trusted_authserv_id.to_s.strip.downcase.presence
    end

    def spf_result
      @spf_result ||= extract_spf_result
    end

    def dkim_result
      @dkim_result ||= extract_auth_result('dkim')
    end

    def dmarc_result
      @dmarc_result ||= extract_auth_result('dmarc')
    end

    def hard_fail?
      [spf_result, dkim_result, dmarc_result].include?(:fail)
    end

    private

    attr_reader :mail, :trusted_authserv_id

    def extract_spf_result
      return :unknown if mail.blank?

      value = header_values('Received-SPF').first
      return :unknown if value.blank?

      token = value[/\A\s*(\w+)/, 1].to_s.downcase
      SPF_RESULTS.include?(token) ? token.to_sym : :unknown
    end

    def extract_auth_result(mechanism)
      return :unknown if mail.blank? || trusted_authserv_id.blank?

      trusted_authentication_results.each do |value|
        match = value.match(/\b#{mechanism}=(\w+)/)
        next unless match

        token = match[1].downcase
        return AUTH_RESULT_TOKENS.include?(token) ? token.to_sym : :unknown
      end

      :unknown
    end

    def trusted_authentication_results
      header_values('Authentication-Results').select do |value|
        authserv_id_for(value) == trusted_authserv_id
      end
    end

    def authserv_id_for(value)
      value.to_s.split(';', 2).first.to_s.strip.downcase
    end

    # Mail::Header#[] returns nil, a single Mail::Field, or an Array of Mail::Field when the
    # header repeats (Authentication-Results is inserted independently by both OpenDKIM and
    # OpenDMARC, so it commonly repeats). Deliberately not using Kernel#Array() here -- Mail::Field
    # may implement #to_a for its own internal purposes, which would silently misbehave.
    def header_values(name)
      raw = mail.header[name]
      fields = raw.is_a?(Array) ? raw : [raw].compact

      fields.map { |field| field.respond_to?(:value) ? field.value.to_s : field.to_s }
    end
  end
end
