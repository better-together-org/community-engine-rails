# frozen_string_literal: true

module BetterTogether
  # API input and output for an event's hosts, as in the event form: any number of hosts of any type that hosts
  # events (HostsEvents: people, communities, ...), each `{host_type, host_id}`. Given as a list or, from the
  # JSON:API (which rejects nested objects), a JSON string. Setting it replaces all hosts, so the creator is not
  # added as a host (Event#set_host only fills in the creator when no host was given); on update the new list is
  # the full set. Works on create and update.
  module EventHosting
    extend ActiveSupport::Concern

    included do
      validate :host_specs_must_be_valid
    end

    def hosts
      event_hosts.reject(&:marked_for_destruction?).map { |host| { host_type: host.host_type, host_id: host.host_id } }
    end

    def hosts=(specs)
      @host_spec_error = nil
      found = Array(parse_host_specs(specs)).map { |spec| find_host(spec.to_h.with_indifferent_access) }
      if found.empty? || found.any?(&:nil?)
        @host_spec_error = 'needs at least one host, each a known host_type and host_id'
      else
        replace_hosts(found.uniq)
      end
    rescue JSON::ParserError
      @host_spec_error = 'is not valid JSON'
    end

    private

    def parse_host_specs(specs)
      specs.is_a?(String) ? JSON.parse(specs) : specs
    end

    def find_host(spec)
      klass = HostsEvents.included_in_models.find { |model| model.name == spec[:host_type].to_s }
      klass&.find_by(id: spec[:host_id])
    end

    def replace_hosts(hosts)
      current = event_hosts.reject(&:marked_for_destruction?)
      event_hosts.each { |event_host| event_host.mark_for_destruction unless hosts.include?(event_host.host) }
      hosts.each { |host| event_hosts.build(host:) unless current.any? { |event_host| event_host.host == host } }
    end

    def host_specs_must_be_valid
      errors.add(:hosts, @host_spec_error) if @host_spec_error
    end
  end
end
