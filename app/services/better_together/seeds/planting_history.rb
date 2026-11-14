# frozen_string_literal: true

module BetterTogether
  module Seeds
    # What earlier completed plantings of a packet wrote on a platform, keyed "type:key",
    # with the field snapshot taken right after each write. This is the provenance used to
    # tell unedited planted records from steward edits until provenance columns exist.
    module PlantingHistory
      module_function

      def scope(platform:, packet_id:)
        SeedPlanting.where(platform:, planting_type: 'seed', status: 'completed')
                    .where("metadata ->> 'packet_id' = ?", packet_id).order(:completed_at) # rubocop:disable BetterTogether/NoRawSqlInQueries -- jsonb key match, bound parameter
      end

      def for(platform:, packet_id:)
        scope(platform:, packet_id:).each_with_object({}) do |planting, records|
          (planting.result['provenance'] || {}).each do |id, data|
            data['deleted'] ? records.delete(id) : records[id] = data
          end
        end
      end

      def planted?(platform:, packet_id:)
        scope(platform:, packet_id:).exists?
      end
    end
  end
end
