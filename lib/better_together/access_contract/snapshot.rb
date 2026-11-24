# frozen_string_literal: true

module BetterTogether
  module AccessContract
    # The committed record of ACTUAL behaviour written by the probe spec.
    module Snapshot
      module_function

      def path
        AccessContract.root.join(SNAPSHOT_PATH)
      end

      def load(file = path)
        JSON.parse(File.read(file))
      end

      # Sorted keys at every level, no timestamps or ids, so the file is byte-stable.
      def dump(data)
        "#{JSON.pretty_generate(sort_keys(data))}\n"
      end

      # { "resource.action.persona.state" => "allow" }
      def flatten(data)
        data.fetch('resources').flat_map do |resource, actions|
          actions.flat_map do |action, personas|
            personas.flat_map do |persona, states|
              states.map { |state, value| ["#{resource}.#{action}.#{persona}.#{state}", value] }
            end
          end
        end.to_h
      end

      def sort_keys(value)
        case value
        when Hash then value.sort_by { |k, _| k.to_s }.to_h { |k, v| [k, sort_keys(v)] }
        when Array then value.map { |v| sort_keys(v) }
        else value
        end
      end
    end
  end
end
