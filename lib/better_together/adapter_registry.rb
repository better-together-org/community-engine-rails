# frozen_string_literal: true

module BetterTogether
  # In-memory registry for subsystem adapters/providers.
  # Each subsystem can register multiple named adapters and dispatch to all of them.
  class AdapterRegistry
    def initialize
      @entries = Hash.new { |hash, key| hash[key] = [] }
    end

    def register(group, name = nil, adapter = nil, &block)
      callable = adapter || block
      raise ArgumentError, 'adapter must respond to #call' unless callable&.respond_to?(:call)

      key = normalize_group(group)
      @entries[key] = @entries[key].reject { |entry| entry[:name] == name } if name.present?
      @entries[key] << { name:, adapter: callable }
    end

    def adapters_for(group)
      @entries[normalize_group(group)].dup
    end

    def clear!(group = nil)
      return @entries.clear if group.nil?

      @entries.delete(normalize_group(group))
    end

    def dispatch(group, *args, **kwargs)
      adapters_for(group).map do |entry|
        entry.fetch(:adapter).call(*args, **kwargs)
      end
    end

    def groups
      @entries.keys
    end

    private

    def normalize_group(group)
      group.to_sym
    end
  end
end
