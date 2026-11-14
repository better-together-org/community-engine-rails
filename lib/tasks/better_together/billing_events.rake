# frozen_string_literal: true

# Billing event operations. Listing never prints the payload or the error text (both are
# encrypted for a reason); replaying changes data, so it only reports unless APPLY=1.
namespace :better_together do
  namespace :billing do
    desc 'List failed and dead-lettered billing events, newest first: ' \
         'rake "better_together:billing:list_events[failed|dead_lettered|all]". Never prints payloads or errors.'
    task :list_events, [:state] => :environment do |_task, args|
      puts BetterTogether::Billing::EventOperations.list(args[:state].presence || 'all')
    end

    desc 'Show one billing event\'s state and history: rake "better_together:billing:show_event[ID]". No payload, no error text.'
    task :show_event, [:id] => :environment do |_task, args|
      abort 'Give the event id: better_together:billing:show_event[ID]' if args[:id].blank?

      puts BetterTogether::Billing::EventOperations.detail(BetterTogether::Billing::Event.find(args[:id]))
    end

    desc 'Replay one failed or dead-lettered billing event, or all of them with ALL=1. Reports only until APPLY=1. ' \
         'Needs OPERATOR=<person id> (a host platform manager): rake "better_together:billing:replay_event[ID]" APPLY=1 OPERATOR=...'
    task :replay_event, [:id] => :environment do |_task, args|
      abort 'Give one event id, or set ALL=1 to replay every failed and dead-lettered event.' if args[:id].blank? && ENV['ALL'].blank?

      events = ENV['ALL'].present? ? BetterTogether::Billing::Event.problematic.newest_first : [BetterTogether::Billing::Event.find(args[:id])]
      puts BetterTogether::Billing::EventOperations.replay(events, apply: ENV['APPLY'].present?, operator_id: ENV.fetch('OPERATOR', nil))
    end
  end
end
