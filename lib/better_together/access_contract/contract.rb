# frozen_string_literal: true

# rubocop:disable Metrics/AbcSize, Metrics/ClassLength, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity, Layout/LineLength, Style/MultilineBlockChain, Metrics/MethodLength

module BetterTogether
  module AccessContract
    # Loads the YAML contract files and expands each action's ordered rows into cells.
    class Contract
      Cell = Struct.new(:resource, :action, :persona, :state, :outcome, :rule, :reason, :condition,
                        :fixture, :deviation, :undecided, :note, keyword_init: true) do
        def key
          [resource, action, persona, state].join('.')
        end
      end

      ROW_KEYS = %w[personas states outcome rule reason condition fixture deviation undecided note].freeze
      OUTCOMES = %w[allow deny conditional undecided na].freeze

      attr_reader :personas, :states, :classifications, :principles, :subsystems

      def self.load(dir: AccessContract.root.join(CONTRACT_DIR))
        new(Pathname(dir))
      end

      def initialize(dir)
        @dir = dir
        persona_file = read('personas.yml')
        @personas = persona_file.fetch('personas')
        @states = persona_file.fetch('states')
        class_file = read('classifications.yml')
        @classifications = class_file.fetch('classifications')
        @principles = class_file.fetch('principles')
        @subsystems = AccessContract::SUBSYSTEMS.to_h { |name| [name, read("#{name}.yml")] }
      end

      def active_personas
        personas.select { |_, v| v['status'] == 'active' }.keys
      end

      def pending_personas
        personas.select { |_, v| v['status'] == 'pending' }.keys
      end

      # { "CD-1" => decision hash plus 'id' and 'subsystem' }
      def decisions
        @decisions ||= subsystems.flat_map do |name, file|
          (file['decisions'] || {}).map { |id, d| [id, d.merge('id' => id, 'subsystem' => name)] }
        end.to_h
      end

      # { resource_key => resource hash plus 'subsystem' }
      def resources
        @resources ||= subsystems.flat_map do |name, file|
          file.fetch('resources').map { |key, res| [key, res.merge('subsystem' => name, 'key' => key)] }
        end.to_h
      end

      def action_names(resource_key)
        resources.fetch(resource_key).fetch('actions').keys
      end

      def action_states(resource_key, action)
        spec = resources.fetch(resource_key).fetch('actions').fetch(action)
        spec['states'] || resources.fetch(resource_key).fetch('states')
      end

      # Expanded cells: { "resource.action.persona.state" => Cell } for active personas only.
      def cells
        @cells ||= build_cells
      end

      def cell(resource, action, persona, state)
        cells["#{resource}.#{action}.#{persona}.#{state}"]
      end

      # Validation problems in the contract itself, independent of any snapshot.
      def problems
        @problems ||= []
        build_cells
        @problems.dup
      end

      private

      def read(name)
        YAML.safe_load_file(@dir.join(name), permitted_classes: [Symbol]) || {}
      end

      def build_cells
        return @cells if @cells

        @problems = []
        @cells = {}
        resources.each do |key, res|
          check_resource(key, res)
          res.fetch('actions').each { |action, spec| expand_action(key, res, action, spec) }
        end
        @cells
      end

      def check_resource(key, res)
        problems_for(key, 'unknown classification') unless classifications.key?(res['classification'])
        ids = res.fetch('rules', []).map { |r| r['id'] }
        problems_for(key, 'duplicate rule ids') if ids.uniq.size != ids.size
        problems_for(key, 'last rule must be default_deny') unless ids.last == 'default_deny'
        res.fetch('rules', []).each do |rule|
          bad = Array(rule['applies_to']) - res.fetch('actions').keys
          problems_for(key, "rule #{rule['id']} applies_to unknown actions #{bad.join(', ')}") if bad.any?
        end
        (res['states'] || []).each { |s| problems_for(key, "unknown state #{s}") unless states.key?(s) }
      end

      def expand_action(key, res, action, spec)
        rows = spec.fetch('rows')
        rows.each { |row| check_row(key, action, row, res) }
        action_states(key, action).each do |state|
          active_personas.each do |persona|
            row = rows.find { |r| covers?(r, 'personas', persona) && covers?(r, 'states', state) }
            if row.nil?
              problems_for("#{key}.#{action}", "no row covers #{persona} x #{state}")
              next
            end
            @cells["#{key}.#{action}.#{persona}.#{state}"] = build_cell(key, action, persona, state, row)
          end
        end
      end

      def build_cell(key, action, persona, state, row)
        Cell.new(resource: key, action:, persona:, state:, outcome: row['outcome'], rule: row['rule'],
                 reason: [row['reason'], row['note'] && "(#{row['note']})"].compact.join(' ').presence, note: row['note'], condition: row['condition'], fixture: row['fixture'],
                 deviation: row['deviation'], undecided: row['undecided'])
      end

      def covers?(row, field, value)
        list = row[field]
        list.nil? || list == 'all' || Array(list).include?(value)
      end

      def check_row(key, action, row, res)
        where = "#{key}.#{action}"
        extra = row.keys - ROW_KEYS
        problems_for(where, "unknown row keys #{extra.join(', ')}") if extra.any?
        problems_for(where, "bad outcome #{row['outcome'].inspect}") unless OUTCOMES.include?(row['outcome'])
        problems_for(where, 'row needs a reason') if row['reason'].to_s.strip.empty? && !%w[na
                                                                                            undecided].include?(row['outcome']) && row['deviation'].nil?
        check_row_rule(where, row, res)
        check_row_extras(where, row)
      end

      def check_row_rule(where, row, res)
        return if row['outcome'] == 'na' || (row['rule'].nil? && row['outcome'] == 'conditional')

        rule_ids = res.fetch('rules', []).map { |r| r['id'] }
        problems_for(where, "unknown rule #{row['rule'].inspect}") unless rule_ids.include?(row['rule'])
        actual_rule = row.dig('deviation', 'actual_rule')
        problems_for(where, "unknown actual_rule #{actual_rule.inspect}") if actual_rule && rule_ids.exclude?(actual_rule)
      end

      def check_row_extras(where, row)
        check_conditional(where, row)
        check_deviation(where, row)
        check_undecided(where, row)
      end

      def check_conditional(where, row)
        return unless row['outcome'] == 'conditional'

        problems_for(where, 'conditional row needs condition and fixture') if row['condition'].nil? || row['fixture'].nil?
      end

      def check_deviation(where, row)
        dev = row['deviation']
        return unless dev

        problems_for(where, 'deviation needs actual and decision') unless dev['actual'] && dev['decision']
        problems_for(where, 'deviation must keep a deny or allow intended outcome') unless %w[allow deny].include?(row['outcome'])
        check_decision(where, dev['decision'], 'known_deviation')
      end

      def check_undecided(where, row)
        undecided = row['undecided']
        problems_for(where, 'undecided outcome needs an undecided block') if row['outcome'] == 'undecided' && undecided.nil?
        return unless undecided

        problems_for(where, 'undecided needs actual, suggests and decision') unless undecided.values_at('actual', 'suggests', 'decision').all?
        check_decision(where, undecided['decision'], 'undecided')
      end

      def check_decision(where, id, kind)
        decision = decisions[id]
        return problems_for(where, "unknown decision #{id.inspect}") unless decision

        problems_for(where, "decision #{id} is #{decision['kind']}, expected #{kind}") unless decision['kind'] == kind
      end

      def problems_for(where, message)
        @problems << "#{where}: #{message}"
      end
    end
  end
end
# rubocop:enable Metrics/AbcSize, Metrics/ClassLength, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity, Layout/LineLength, Style/MultilineBlockChain, Metrics/MethodLength
