# frozen_string_literal: true

namespace :better_together do
  namespace :access do
    desc 'Generate access contract docs and diagram sources from the contract and snapshot'
    task docs: :environment do
      generator = BetterTogether::AccessContract::DocsGenerator.new
      generator.write
      puts "Wrote #{generator.files.size} files. Now run bin/render_diagrams and commit the exports."
    end

    desc 'Fail when generated access contract docs are out of date (CI)'
    task check: :environment do
      stale = BetterTogether::AccessContract::DocsGenerator.new.stale
      abort "Stale access contract docs, run better_together:access:docs:\n  #{stale.join("\n  ")}" if stale.any?

      puts 'Access contract docs are current.'
    end

    desc 'Print contract problems, drift and invariant failures'
    task verify: :environment do
      contract = BetterTogether::AccessContract::Contract.load
      problems = contract.problems + BetterTogether::AccessContract::Drift.new(contract).diffs.map(&:to_s) +
                 BetterTogether::AccessContract::Invariants.new(contract).all.values.flatten
      abort problems.join("\n") if problems.any?

      puts 'Access contract verified.'
    end
  end
end
