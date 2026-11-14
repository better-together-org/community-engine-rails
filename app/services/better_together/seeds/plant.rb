# frozen_string_literal: true

# rubocop:disable Metrics/AbcSize, Metrics/MethodLength, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity, Metrics/ParameterLists, Naming/PredicateMethod, Layout/LineLength

module BetterTogether
  module Seeds
    # Entry point: load a packet directory, plan it against a platform and, only when apply
    # is true and the plan has no errors, write it in one transaction. Always returns the
    # structured report hash; a dry run (the default) writes nothing, not even a SeedPlanting.
    class Plant
      def self.call(...)
        new(...).call
      end

      def initialize(path:, platform:, apply: false, planted_by: nil, attach_files: nil, restrict_sources: false)
        @path = path
        @restrict_sources = restrict_sources
        @platform = platform
        @apply = apply
        @planted_by = planted_by
        @attach_files = attach_files
      end

      def call
        raise ArgumentError, 'a target platform is required' unless @platform

        source = @restrict_sources ? PacketSources.resolve!(@path) : Pathname.new(@path.to_s).expand_path
        with_root(source) { |root| run(root) }
      end

      private

      # A .tar.gz is unpacked into a throwaway directory; a directory is used in place.
      def with_root(source, &)
        return yield source unless source.file? && source.to_s.match?(/\.(tar\.gz|tgz)\z/)

        Dir.mktmpdir('seed-packet-') do |dir|
          PacketArchive.extract(source, dir, max_bytes: BlobPolicy.max_archive_bytes)
          yield Pathname.new(dir)
        end
      end

      def run(root)
        packet = Packet.load(root)
        transport_errors, attacher = check_transport(root, packet)
        plan = Planner.call(packet:, platform: @platform)
        transport_errors.each { |message| plan.add_error(record: 'packet', message:) }
        return plan.to_h(dry_run: !@apply) unless @apply && plan.ok?

        @attach_files ||= attacher
        apply(packet, plan)
      end

      # Verifies MANIFEST.json when present; record files need one (fail closed).
      def check_transport(root, packet)
        manifest_path = root.join('MANIFEST.json')
        has_files = packet.entries.any? { |e| e.files.any? }
        return [['records declare files but the packet has no MANIFEST.json'], nil] if has_files && !manifest_path.file?
        return [[], nil] unless manifest_path.file?

        manifest = Manifest.load(root)
        report = manifest.verify(root)
        return [report.errors.map { |e| [e.file, e.message].compact.join(': ') }, nil] unless report.valid?

        [[], BlobAttacher.new(root:, manifest:)]
      end

      def apply(packet, plan)
        planting = start_planting(packet)
        outcome = nil
        ActiveRecord::Base.transaction do
          raise ActiveRecord::Rollback unless acquire_lock(packet)

          Current.set(platform: @platform) do
            outcome = Applier.new(plan:, platform: @platform, attach_files: @attach_files).call
          end
          raise ActiveRecord::Rollback if outcome.errors.any?
        end
        finish(planting, plan, outcome)
      end

      def finish(planting, plan, outcome)
        if outcome.nil?
          report = plan.to_h(dry_run: false).merge(errors: [{ record: 'packet', message: 'another planting of this packet is in progress' }])
          planting.mark_failed!(StandardError.new('planting already in progress'))
        elsif outcome.errors.any?
          report = plan.to_h(dry_run: false).merge(created: 0, updated: 0, deleted: 0, rolled_back: true, errors: outcome.errors)
          planting.mark_failed!(StandardError.new("#{outcome.errors.size} record error(s); nothing was written"))
        else
          report = plan.to_h(dry_run: false)
          planting.mark_completed!(report.merge(provenance: outcome.provenance))
        end
        planting.update!(result: planting.result.merge(report.deep_stringify_keys)) unless planting.completed?
        report
      end

      def start_planting(packet)
        SeedPlanting.create!(
          status: 'pending', planting_type: 'seed', privacy: 'private', platform: @platform, planted_by: @planted_by,
          source: @path.to_s,
          metadata: { 'packet_id' => packet.identifier, 'packet_version' => packet.packet_meta['version'],
                      'mode' => packet.mode, 'platform_identifier' => @platform.identifier }
        ).tap(&:mark_started!)
      end

      def acquire_lock(packet)
        key = ActiveRecord::Base.connection.quote("seed-packet:#{@platform.id}:#{packet.identifier}")
        ActiveRecord::Base.connection.select_value("SELECT pg_try_advisory_xact_lock(hashtextextended(#{key}, 0))")
      end
    end
  end
end
# rubocop:enable Metrics/AbcSize, Metrics/MethodLength, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity, Metrics/ParameterLists, Naming/PredicateMethod, Layout/LineLength
