# frozen_string_literal: true

# rubocop:disable-next Metrics/AbcSize, Metrics/MethodLength, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity, Metrics/ParameterLists, Naming/PredicateMethod, Layout/LineLength, Metrics/ClassLength
module BetterTogether
  module Seeds
    # Turns a validated Packet and a target platform into a Plan without writing anything:
    # checks fields and references, orders records by dependency, and classifies each as
    # create / update / unchanged / skipped_edited / delete against what is on the platform.
    class Planner
      def self.call(packet:, platform:)
        new(packet:, platform:).call
      end

      def initialize(packet:, platform:)
        @packet = packet
        @platform = platform
        @plan = Plan.new(packet:, platform:)
      end

      def call
        return invalid_packet unless packet.valid?
        return plan unless check_target && check_dependencies

        @history = PlantingHistory.for(platform:, packet_id: packet.identifier)
        @entries = apply_locale_policy(packet.entries)
        ordered = order(@entries)
        index = @entries.index_by(&:id)
        ordered.each { |entry| plan_entry(entry, index) }
        plan_deletes if packet.mode == 'managed'
        plan
      end

      private

      attr_reader :packet, :platform, :plan, :history

      def invalid_packet
        packet.report.errors.each do |e|
          plan.add_error(record: [e.file, e.record].compact.join(' '), field: e.field, message: e.message)
        end
        plan
      end

      def check_target
        declared = packet.declared_platform_identifier
        return true if declared.blank? || declared == platform.identifier

        plan.add_error(record: 'packet', field: '/packet/target/platform_identifier',
                       message: "packet targets #{declared} but the platform is #{platform.identifier}")
        false
      end

      def check_dependencies
        missing = packet.dependencies.reject { |dep| PlantingHistory.planted?(platform:, packet_id: dep) }
        missing.each { |dep| plan.add_error(record: 'packet', field: '/seed_pack/dependencies', message: "required pack #{dep} is not planted on this platform") }
        missing.empty?
      end

      def apply_locale_policy(entries)
        supported = I18n.available_locales.map(&:to_s)
        declared = Array(packet.packet_meta['locales'])
        entries.map do |entry|
          kept = entry.translations.select do |locale, _|
            reason = if declared.any? && declared.exclude?(locale) then 'is not listed in packet locales'
                     elsif supported.exclude?(locale) then 'is not enabled on this application'
                     end
            next true unless reason

            report_locale(entry, locale, reason)
            false
          end
          kept.size == entry.translations.size ? entry : entry.with(translations: kept)
        end
      end

      def report_locale(entry, locale, reason)
        message = "locale #{locale} #{reason}"
        if packet.locale_policy == 'fail'
          plan.add_error(record: entry.id, field: "/translations/#{locale}", message:)
        else
          plan.add_warning(record: entry.id, field: "/translations/#{locale}", message: "#{message}; skipped")
        end
      end

      # Kahn's algorithm over packet-local references; ties keep type order, position, file order.
      def order(entries)
        type_rank = Registry.ordered(entries.map { |e| e.type.to_sym }.uniq.select { |t| Registry.registered?(t) }).map(&:name).each_with_index.to_h
        by_id = entries.index_by(&:id)
        deps = entries.to_h { |e| [e.id, e.refs.values.map { |r| "#{r['type']}:#{r['key']}" }.select { |id| by_id.key?(id) && id != e.id }] }
        sorted = entries.sort_by { |e| [type_rank.fetch(e.type.to_sym, 999), e.position || 0, e.index] }
        result = []
        pending = sorted.dup
        until pending.empty?
          ready = pending.find { |e| (deps[e.id] - result.map(&:id)).empty? }
          unless ready
            plan.add_error(record: pending.first.id, message: "reference cycle among #{pending.map(&:id).first(5).join(', ')}")
            break
          end
          result << pending.delete(ready)
        end
        result
      end

      def plan_entry(entry, index)
        definition = Registry.fetch(entry.type)
        return unless validate_fields(entry, definition) & validate_refs(entry, definition, index)

        existing = locate(definition, entry, index)
        return add(entry, :create, 'new record') unless existing

        classify(entry, definition, existing)
      rescue Registry::UnknownType
        plan.add_error(record: entry.id, field: 'type', message: "unknown seed type #{entry.type}")
      end

      def validate_fields(entry, definition)
        ok = true
        entry.attributes.each_key do |name|
          next if definition.writable_attributes.include?(name.to_sym) || name == definition.sti_column.to_s

          ok = false
          plan.add_error(record: entry.id, field: "/attributes/#{name}", message: "#{name} is not writable on #{definition.name}")
        end
        entry.translations.each_value do |fields|
          fields.each_key do |name|
            next if definition.translated_attributes.include?(name.to_sym)

            ok = false
            plan.add_error(record: entry.id, field: "/translations/#{name}", message: "#{name} is not translatable on #{definition.name}")
          end
        end
        if entry.attributes['type'] && definition.sti_allowed&.call&.exclude?(entry.attributes['type'])
          ok = false
          plan.add_error(record: entry.id, field: '/attributes/type', message: "#{entry.attributes['type']} is not an allowed type")
        end
        ok
      end

      def validate_refs(entry, definition, index)
        ok = true
        definition.references.each do |slot, ref|
          ok = false if !ref.optional && !entry.refs.key?(slot.to_s) && report_ref(entry, slot, 'is required')
        end
        entry.refs.each do |slot, target|
          ref = definition.references[slot.to_sym]
          next (ok = false) if ref.nil? && report_ref(entry, slot, "is not a reference of #{definition.name}")
          next (ok = false) if ref.types.exclude?(target['type'].to_sym) && report_ref(entry, slot, "cannot point at #{target['type']}")
          next if target['scope'] != 'platform' && index.key?("#{target['type']}:#{target['key']}")

          ok = false if resolve_on_platform(target).nil? && report_ref(entry, slot, "#{target['type']}:#{target['key']} was not found in the packet or on the platform")
        end
        ok
      end

      def report_ref(entry, slot, message)
        plan.add_error(record: entry.id, field: "/refs/#{slot}", message:)
        true
      end

      def resolve_on_platform(target)
        definition = Registry.fetch(target['type'])
        return nil if definition.within || definition.by_refs.any?

        definition.find(platform:, key: target['key'])
      rescue Registry::UnknownType
        nil
      end

      def locate(definition, entry, _index)
        return nil if definition.by_refs.any? || definition.within

        definition.find(platform:, key: entry.key)
      end

      def classify(entry, definition, existing)
        planted = history[entry.id]&.dig('snapshot')
        proposed = Snapshot.proposed(definition.model.find(existing.id), definition, entry)
        keys = (proposed.keys + (planted&.keys || [])).uniq
        current = Snapshot.read(existing, definition, keys)
        if proposed.all? { |k, v| current[k] == v }
          add(entry, :unchanged, nil, existing)
        elsif packet.mode == 'add_only'
          add(entry, :skipped_edited, 'add_only keeps the existing record', existing)
        elsif planted.nil?
          add(entry, :skipped_edited, 'record exists but this packet did not plant it', existing)
        elsif planted.all? { |k, v| current[k] == v }
          add(entry, :update, 'packet changed, record not edited since', existing, planted)
        else
          add(entry, :skipped_edited, 'edited since this packet planted it', existing)
        end
      end

      def plan_deletes
        packet.deletes.each do |tomb|
          id = "#{tomb['type']}:#{tomb['key']}"
          planted = history[id]
          definition = Registry.registered?(tomb['type']) ? Registry.fetch(tomb['type']) : nil
          record = definition && !definition.within && definition.by_refs.empty? ? definition.find(platform:, key: tomb['key']) : nil
          plan.items << if record.nil?
                          Plan::Item.new(nil, tomb['type'], tomb['key'], :unchanged, 'already absent', nil, nil)
                        elsif planted.nil? || Snapshot.read(record, definition, planted['snapshot'].keys) != planted['snapshot']
                          Plan::Item.new(nil, tomb['type'], tomb['key'], :skipped_edited, 'not planted by this packet or edited since', record.id, nil)
                        else
                          Plan::Item.new(nil, tomb['type'], tomb['key'], :delete, nil, record.id, planted)
                        end
        end
      end

      def add(entry, action, detail, existing = nil, planted = nil)
        plan.items << Plan::Item.new(entry, entry.type, entry.key, action, detail, existing&.id, planted)
      end
    end
  end
end
