# frozen_string_literal: true

module BetterTogether
  class PersonDeletionManifest
    CONFIG_PATH = BetterTogether::Engine.root.join('config/person_deletion_inventory.yml')

    class << self
      def entries
        @entries ||= begin
          raw_config = YAML.safe_load_file(CONFIG_PATH)
          Array(raw_config.fetch('entries')).map(&:deep_stringify_keys)
        end
      end

      def reload!
        @entries = nil
        entries
      end
    end
  end
end
