# frozen_string_literal: true

# rubocop:disable Metrics/AbcSize, Metrics/ClassLength, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity, Layout/LineLength, Style/MultilineBlockChain, Metrics/MethodLength

module BetterTogether
  module AccessContract
    # Checks that sit above single cells. Each method returns an array of readable problems.
    class Invariants
      READ_ACTIONS = %w[show scope download view_members].freeze
      STANDING_ROLES = %w[platform_manager platform_steward].freeze

      attr_reader :contract, :actual

      def initialize(contract, snapshot = Snapshot.load)
        @contract = contract
        @actual = Snapshot.flatten(snapshot)
      end

      def all
        {
          'standing roles never read member private or personal data' => standing_role_privacy,
          'every pilot policy has a contract entry' => policy_coverage,
          'every routed pilot action authorizes or is allowlisted' => controller_authorization,
          'every referenced permission is seeded, granted and checked' => permission_wiring,
          'every rule is used and agrees with its cells' => rule_coherence
        }
      end

      def standing_role_privacy
        guarded = contract.classifications.reject { |_, v| v['standing_role_may_read'] }.keys
        contract.cells.values.flat_map do |cell|
          next [] unless guarded.include?(contract.resources[cell.resource]['classification'])
          next [] unless READ_ACTIONS.include?(cell.action) && STANDING_ROLES.include?(cell.persona)
          # The unclaimed fixture is a public profile; its private rows follow each row's own privacy.
          next [] if %w[public unclaimed].include?(cell.state)

          standing_role_problems(cell)
        end
      end

      def policy_coverage
        contract.subsystems.flat_map do |name, file|
          pattern = Regexp.new(file.fetch('policy_pattern'))
          policy_files.filter_map do |base|
            next unless base.match?(pattern)
            next if contracted_policies.include?(base) || deferred_policies(file).include?(base)

            "#{name}: app/policies/better_together/#{base}_policy.rb matches /#{pattern.source}/ and has no contract entry or deferral"
          end + stale_deferrals(name, file)
        end
      end

      def controller_authorization
        inventory.routed_actions.filter_map do |route|
          next unless route[:status] == :missing

          "#{route[:controller]}##{route[:action]} neither authorizes nor policy-scopes and is not allowlisted"
        end
      end

      def permission_wiring
        seeded = seed_permissions
        granted = granted_permissions
        contract.subsystems.flat_map do |name, file|
          opt_in = file['opt_in_permissions'] || {}
          file['resources'].values.flat_map { |res| res['permissions'] || [] }.uniq.flat_map do |perm|
            permission_problems(name, perm, seeded:, granted:, opt_in:)
          end
        end
      end

      def rule_coherence
        contract.resources.flat_map do |key, res|
          used = used_rule_ids(key)
          res['rules'].flat_map do |rule|
            unused = rule['id'] != 'default_deny' && !rule['unprobed'] && used.exclude?(rule['id'])
            [("#{key}: rule #{rule['id']} is not referenced by any cell" if unused), *outcome_problems(key, rule)]
          end.compact
        end
      end

      def inventory
        @inventory ||= Inventory.new(contract)
      end

      private

      def standing_role_problems(cell)
        seen = actual[cell.key]
        problems = []
        problems << "#{cell.key}: contract intends #{cell.outcome} for a standing role" if %w[allow undecided conditional].include?(cell.outcome)
        problems << "#{cell.key}: app allows a standing role and no known_deviation records it" if seen == 'allow' && cell.deviation.nil?
        problems
      end

      def contracted_policies
        @contracted_policies ||= contract.resources.values.map { |r| underscore_policy(r['policy']) }
      end

      def deferred_policies(file)
        (file['deferred_policies'] || {}).keys.map(&:underscore)
      end

      def stale_deferrals(name, file)
        deferred_policies(file).filter_map do |base|
          next "#{name}: deferred policy #{base} has no policy file" unless policy_files.include?(base)
          next "#{name}: deferred policy #{base} is also contracted" if contracted_policies.include?(base)
        end
      end

      def underscore_policy(class_name)
        class_name.delete_prefix('BetterTogether::').delete_suffix('Policy').underscore
      end

      def policy_files
        root = AccessContract.root.join('app/policies/better_together')
        @policy_files ||= Dir[root.join('**/*_policy.rb')]
                          .map { |f| Pathname(f).relative_path_from(root).to_s.delete_suffix('_policy.rb') }.sort
      end

      def seed_permissions
        seed_records('resource_permissions.yml').map { |r| r['key'] }
      end

      def granted_permissions
        seed_records('role_resource_permissions.yml').to_set { |r| r['refs']['resource_permission'].split(':').last }
      end

      def seed_records(name)
        YAML.safe_load_file(AccessContract.root.join('config/seeds/better_together/rbac/records', name))['records']
      end

      def permission_problems(name, perm, seeded:, granted:, opt_in:)
        problems = []
        problems << "#{name}: permission #{perm} is not seeded" unless seeded.include?(perm)
        problems << "#{name}: permission #{perm} is granted to no role and not listed in opt_in_permissions" unless granted.include?(perm) || opt_in.key?(perm)
        problems << "#{name}: permission #{perm} is never checked by a policy" if checked_in_policies(perm).empty?
        problems << "#{name}: opt_in permission #{perm} is granted to a default role; remove the opt_in entry" if opt_in.key?(perm) && granted.include?(perm)
        problems
      end

      # Files under app/policies that name the permission literally.
      def checked_in_policies(perm)
        @policy_text ||= Dir[AccessContract.root.join('app/policies/**/*.rb')].to_h { |f| [f, File.read(f)] }
        @policy_text.select { |_, text| text.match?(/['"]#{perm}['"]|:#{perm}\b/) }.keys
      end

      def used_rule_ids(resource)
        contract.cells.values.select { |c| c.resource == resource }.flat_map do |cell|
          [cell.rule, cell.deviation&.dig('actual_rule')]
        end.compact.uniq
      end

      def outcome_problems(resource, rule)
        contract.cells.values.select { |c| c.resource == resource }.filter_map do |cell|
          check_cell_rule(cell, rule)
        end.uniq
      end

      def check_cell_rule(cell, rule)
        if cell.rule == rule['id'] && %w[allow deny].include?(cell.outcome) && rule['on_yes'] != cell.outcome
          "#{cell.resource}: #{cell.key} is #{cell.outcome} but rule #{rule['id']} decides #{rule['on_yes']}"
        elsif cell.deviation&.dig('actual_rule') == rule['id'] && rule['on_yes'] != cell.deviation['actual']
          "#{cell.resource}: #{cell.key} app outcome #{cell.deviation['actual']} but rule #{rule['id']} decides #{rule['on_yes']}"
        end
      end
    end
  end
end
# rubocop:enable Metrics/AbcSize, Metrics/ClassLength, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity, Layout/LineLength, Style/MultilineBlockChain, Metrics/MethodLength
