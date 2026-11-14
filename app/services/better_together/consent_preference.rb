# frozen_string_literal: true

module BetterTogether
  # A person's stored cookie consent decision. It lives in the existing `preferences` JSON on the
  # person (key `cookie_consent`), so there is no extra table. Shape:
  #   { 'analytics' => bool, 'marketing' => bool, 'decided_at' => iso8601, 'policy_version' => 'abc123' }
  # Only the two category booleans come from the person; the date and version are set by the server.
  class ConsentPreference
    KEY = 'cookie_consent'

    def initialize(person)
      @person = person
    end

    def stored?
      data.present?
    end

    # { 'analytics' => bool, 'marketing' => bool } or nil when the person has not decided.
    def decision
      return unless stored?

      Consent::CATEGORIES.index_with { |category| data[category] == true }
    end

    def policy_version
      data['policy_version']
    end

    def decided_at
      Time.zone.parse(data['decided_at'].to_s) if data['decided_at'].present?
    rescue ArgumentError
      nil
    end

    # True when the stored decision was made under the given policy version.
    def current?(version)
      stored? && policy_version == version
    end

    def record!(decision, policy_version:, at: Time.current)
      values = Consent::CATEGORIES.index_with { |category| decision.to_h.stringify_keys[category] == true }
      write(values.merge('decided_at' => at.utc.iso8601, 'policy_version' => policy_version))
    end

    def withdraw!(policy_version:)
      record!({}, policy_version:)
    end

    private

    def data
      stored = (@person.preferences || {})[KEY]
      stored.is_a?(Hash) ? stored : {}
    end

    # update_column keeps this to one write that skips validations and callbacks on the person.
    def write(value)
      @person.update_column(:preferences, (@person.preferences || {}).merge(KEY => value)) # rubocop:disable Rails/SkipsModelValidations
      self
    end
  end
end
