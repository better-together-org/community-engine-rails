# frozen_string_literal: true

module BetterTogether
  module Storage
    # Replaces ActiveStorage::Blob.services. Services from storage.yml resolve as usual; a name of the
    # form storage_config_<uuid> is built from that StorageConfiguration row, so a blob stamped with a
    # platform's service keeps reading from that platform's bucket in every process.
    class TenantRegistry < ActiveStorage::Service::Registry
      PREFIX = 'storage_config_'
      REFRESH_INTERVAL = 30.seconds

      Entry = Struct.new(:service, :stamp, :checked_at)

      def self.tenant_key?(name)
        name.to_s.start_with?(PREFIX)
      end

      def initialize(configurations)
        super
        @tenant_lock = Mutex.new
        @tenant_entries = {}
      end

      def fetch(name, &)
        return super unless self.class.tenant_key?(name)

        tenant_service(name.to_s, &)
      end

      # Drops the cached service so the next fetch rebuilds it from the row (rotation, delete).
      def forget(name)
        @tenant_lock.synchronize { @tenant_entries.delete(name.to_s) }
      end

      private

      def tenant_service(name, &)
        @tenant_lock.synchronize do
          entry = @tenant_entries[name]
          return entry.service if entry && entry.checked_at > REFRESH_INTERVAL.ago

          refresh_entry(name, entry, &)
        end
      end

      def refresh_entry(name, entry, &)
        config = StorageConfiguration.find_by(id: name.delete_prefix(PREFIX))
        return missing(name, &) unless config

        stamp = [config.id, config.updated_at.to_f]
        if entry && entry.stamp == stamp
          entry.checked_at = Time.current
          return entry.service
        end

        service = build_service(name, config)
        @tenant_entries[name] = Entry.new(service, stamp, Time.current)
        service
      end

      def build_service(name, config)
        key = name.to_sym
        ActiveStorage::Service.configure(key, { key => config.to_active_storage_config })
      end

      def missing(name)
        @tenant_entries.delete(name)
        return yield(name.to_sym) if block_given?

        raise KeyError, "No storage configuration for the #{name} Active Storage service."
      end
    end
  end
end
