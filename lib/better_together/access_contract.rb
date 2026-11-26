# frozen_string_literal: true

require 'yaml'
require 'json'
require 'pathname'

module BetterTogether
  # Declarative access contract: EXPECTED access per persona, record state and action,
  # compared with the ACTUAL behaviour recorded by the policy probe spec.
  module AccessContract
    class Error < StandardError; end

    CONTRACT_DIR = 'config/access_contracts'
    SNAPSHOT_PATH = 'spec/access_contract/snapshot.json'
    DOCS_DIR = 'docs/reference/access_contracts'
    DIAGRAM_SOURCE_DIR = 'docs/diagrams/source'
    SUBSYSTEMS = %w[communities people joatu billing].freeze

    def self.root
      BetterTogether::Engine.root
    end
  end
end

require_relative 'access_contract/contract'
require_relative 'access_contract/snapshot'
require_relative 'access_contract/drift'
require_relative 'access_contract/invariants'
require_relative 'access_contract/inventory'
require_relative 'access_contract/docs_generator'
