# frozen_string_literal: true

namespace :better_together do
  namespace :seeds do
    run_packet = lambda do |apply|
      path = ENV.fetch('PACKET') { abort 'PACKET=/path/to/packet-directory is required' }
      identifier = ENV.fetch('PLATFORM') { abort 'PLATFORM=<platform identifier> is required' }
      platform = BetterTogether::Platform.find_by(identifier:) || abort("No platform with identifier #{identifier}")
      report = BetterTogether::Seeds::Plant.call(path:, platform:, apply:, restrict_sources: true)
      puts JSON.pretty_generate(report)
      exit(1) if report[:errors].any?
    end

    desc 'Dry run: plan a seed packet (PACKET=dir PLATFORM=identifier). Writes nothing.'
    task plan: :environment do
      run_packet.call(false)
    end

    desc 'Plant a seed packet (PACKET=dir PLATFORM=identifier). Dry run unless APPLY=1.'
    task plant: :environment do
      run_packet.call(ENV['APPLY'] == '1')
    end
  end
end
