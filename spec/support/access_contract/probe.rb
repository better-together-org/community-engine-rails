# frozen_string_literal: true

# rubocop:disable Metrics/AbcSize, Metrics/ClassLength, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity, Layout/LineLength, Style/MultilineBlockChain, Metrics/MethodLength

require_relative 'world'
require_relative 'resources'
require_relative 'billing_resources'

module AccessContractProbe
  # Calls every policy action and Scope#resolve for the pilot resources and returns a
  # deterministic hash: resource -> action -> persona -> state -> "allow" | "deny" | "na".
  class Runner
    def initialize(contract)
      @contract = contract
    end

    def run
      Rails.cache.clear
      world = World.new
      resources = AccessContractProbe::Resources.build(world)
      result = {}
      @contract.resources.each_key do |key|
        probe = resources.fetch(key) { raise "no probe for contract resource #{key}" }
        result[key] = probe_resource(key, probe)
      end
      Rails.cache.clear
      { 'version' => 1, 'resources' => result }
    end

    private

    def probe_resource(key, probe)
      expected = @contract.action_names(key)
      raise "probe/contract action mismatch for #{key}: #{expected} vs #{probe.actions.keys}" if expected.sort != probe.actions.keys.sort

      expected.to_h do |action|
        [action, probe_action(key, probe, action)]
      end
    end

    def probe_action(key, probe, action)
      personas = @contract.active_personas
      personas.to_h do |persona|
        states = @contract.action_states(key, action).to_h { |state| [state, probe.evaluate(action, persona, state)] }
        [persona, states]
      end
    end
  end
end
# rubocop:enable Metrics/AbcSize, Metrics/ClassLength, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity, Layout/LineLength, Style/MultilineBlockChain, Metrics/MethodLength
