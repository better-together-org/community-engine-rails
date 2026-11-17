# frozen_string_literal: true

# rubocop:disable-next Metrics/AbcSize, Metrics/MethodLength, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity, Layout/LineLength
module BetterTogether
  module Seeds
    # Executes a Plan inside the caller's transaction. Each record is written in a savepoint,
    # so a failing record is reported with its own errors while the rest are still attempted;
    # the caller rolls the whole packet back when any error was collected.
    class Applier
      Outcome = Data.define(:provenance, :errors)

      # attach_files: callable(record:, entry:) that attaches entry.files (blob transport).
      def initialize(plan:, platform:, attach_files: nil)
        @plan = plan
        @platform = platform
        @attach_files = attach_files
        @targets = {}
        @provenance = {}
        @errors = []
      end

      def call
        plan.items.each { |item| apply(item) }
        Outcome.new(@provenance, @errors)
      end

      private

      attr_reader :plan, :platform

      def apply(item)
        definition = Registry.fetch(item.type)
        case item.action
        when :create, :update then write(item, definition)
        when :delete then remove(item, definition)
        else remember(item, definition)
        end
      end

      def remember(item, definition)
        @targets[item.entry.id] = definition.model.find(item.record_id) if item.entry && item.record_id
      end

      def write(item, definition)
        entry = item.entry
        return if already_planted?(item, definition)

        ActiveRecord::Base.transaction(requires_new: true) do
          record = item.action == :create ? RecordWriter.build(definition, entry, platform) : definition.model.find(item.record_id)
          RecordWriter.assign_fields(record, definition, entry)
          RecordWriter.assign_refs(record, entry, resolve_refs(entry))
          definition.hook(:before_save)&.call(record, platform)
          save(record, entry)
          attach(record, entry)
          @targets[entry.id] = record
          @provenance[entry.id] = { 'id' => record.id, 'action' => item.action.to_s,
                                    'snapshot' => Snapshot.read(record.reload, definition, Snapshot.keys_for(entry)) }
        end
      rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotSaved, ArgumentError, KeyError => e
        fail_record(entry.id, e)
      end

      # The planner cannot locate records keyed by their parents (within / by_refs) before the parents exist,
      # so a rerun resolves them here, once the parents are known, and leaves an existing record alone.
      def already_planted?(item, definition)
        return false unless item.action == :create && (definition.within || definition.by_refs.any?)

        refs = resolve_refs(item.entry).transform_keys(&:to_sym)
        existing = definition.find(platform:, key: item.entry.key, parent_refs: refs, attributes: item.entry.attributes)
        return false unless existing

        @targets[item.entry.id] = existing
        mark_unchanged(item, existing)
        true
      rescue KeyError => e
        fail_record(item.entry.id, e)
        true
      end

      # The plan said create because the parents did not exist when it was made; report what really happened.
      def mark_unchanged(item, existing)
        index = plan.items.index(item)
        plan.items[index] = item.with(action: :unchanged, detail: 'already present', record_id: existing.id) if index
      end

      def save(record, entry)
        return if record.save

        record.errors.each { |error| @errors << { record: entry.id, field: "/#{error.attribute}", message: error.full_message } }
        raise ActiveRecord::Rollback
      end

      def attach(record, entry)
        return if entry.files.empty?
        raise ArgumentError, 'file attachments need blob transport, which is not enabled' unless @attach_files

        @attach_files.call(record:, entry:)
      end

      def resolve_refs(entry)
        entry.refs.to_h do |slot, ref|
          id = "#{ref['type']}:#{ref['key']}"
          target = ref['scope'] == 'platform' ? nil : @targets[id]
          target ||= find_on_platform(ref)
          raise KeyError, "#{id} could not be resolved" unless target

          [slot, target]
        end
      end

      # Types keyed by their parents are known only through the packet (planted or located earlier in this run).
      def find_on_platform(ref)
        definition = Registry.fetch(ref['type'])
        return nil if definition.within || definition.by_refs.any?

        definition.find(platform:, key: ref['key'])
      end

      def remove(item, definition)
        definition.model.find(item.record_id).destroy!
        @provenance["#{item.type}:#{item.key}"] = { 'deleted' => true }
      rescue ActiveRecord::RecordNotDestroyed, ActiveRecord::RecordNotFound => e
        fail_record("#{item.type}:#{item.key}", e)
      end

      def fail_record(record, error)
        @errors << { record:, field: nil, message: error.message }
      end
    end
  end
end
