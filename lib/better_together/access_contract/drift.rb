# frozen_string_literal: true

# rubocop:disable Metrics/AbcSize, Metrics/ClassLength, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity, Layout/LineLength, Style/MultilineBlockChain, Metrics/MethodLength

module BetterTogether
  module AccessContract
    # Diffs the contract (EXPECTED) against the probe snapshot (ACTUAL).
    class Drift
      Diff = Struct.new(:key, :kind, :expected, :actual, :message, keyword_init: true) do
        def to_s
          "#{key}: #{message} (expected #{expected.inspect}, snapshot #{actual.inspect})"
        end
      end

      attr_reader :contract, :actual

      def initialize(contract, snapshot = Snapshot.load)
        @contract = contract
        @actual = Snapshot.flatten(snapshot)
      end

      def diffs
        @diffs ||= cell_diffs + stray_diffs
      end

      def known_deviations
        contract.cells.values.select { |c| c.deviation && actual[c.key] == c.deviation['actual'] }
      end

      def undecided
        contract.cells.values.select { |c| c.outcome == 'undecided' }
      end

      # The value the snapshot must hold for the cell to be in step with the contract.
      def self.expected_actual(cell)
        case cell.outcome
        when 'conditional' then cell.fixture
        when 'undecided' then cell.undecided['actual']
        else cell.deviation ? cell.deviation['actual'] : cell.outcome
        end
      end

      private

      def cell_diffs
        contract.cells.values.filter_map do |cell|
          seen = actual[cell.key]
          wanted = self.class.expected_actual(cell)
          next missing(cell) if seen.nil?
          next stale_deviation(cell, seen) if cell.deviation && seen == cell.outcome
          next if seen == wanted

          Diff.new(key: cell.key, kind: 'drift', expected: wanted, actual: seen, message: drift_message(cell))
        end
      end

      def drift_message(cell)
        return 'app behaviour changed from the pinned known deviation' if cell.deviation
        return 'app behaviour changed from the pinned undecided value' if cell.outcome == 'undecided'
        return 'conditional fixture result changed' if cell.outcome == 'conditional'

        "contract says #{cell.outcome} (#{cell.rule}: #{cell.reason})"
      end

      def missing(cell)
        Diff.new(key: cell.key, kind: 'missing', expected: self.class.expected_actual(cell), actual: nil,
                 message: 'contract cell has no snapshot value; the probe did not cover it')
      end

      def stale_deviation(cell, seen)
        Diff.new(key: cell.key, kind: 'stale_deviation', expected: cell.deviation['actual'], actual: seen,
                 message: "the app now matches the contract; remove the known_deviation (#{cell.deviation['decision']})")
      end

      def stray_diffs
        (actual.keys - contract.cells.keys).sort.map do |key|
          Diff.new(key:, kind: 'uncontracted', expected: nil, actual: actual[key],
                   message: 'snapshot has a value the contract does not declare')
        end
      end
    end
  end
end
# rubocop:enable Metrics/AbcSize, Metrics/ClassLength, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity, Layout/LineLength, Style/MultilineBlockChain, Metrics/MethodLength
