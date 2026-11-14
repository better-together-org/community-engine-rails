# frozen_string_literal: true

namespace :better_together do
  namespace :billing do
    desc 'List the Pay webhook deliveries still waiting (failed, or refused as unattributable), oldest first. ' \
         'Never prints the event: it is encrypted for a reason.'
    task pay_webhooks: :environment do
      rows = Pay::Webhook.order(:created_at)

      if rows.none?
        puts 'No Pay webhook deliveries are waiting.'
      else
        rows.each { |row| puts "#{row.id}  #{row.processor}.#{row.event_type}  #{row.created_at.iso8601}" }
      end
    end

    desc 'Process one kept Pay webhook delivery again: rake better_together:billing:reprocess_pay_webhook[ID]. ' \
         'Runs Pay\'s own handlers as well as ours; both are written to be repeated.'
    task :reprocess_pay_webhook, [:id] => :environment do |_task, args|
      abort 'Give the delivery id: better_together:billing:reprocess_pay_webhook[ID]' if args[:id].blank?

      row = Pay::Webhook.find(args[:id])
      row.process!
      puts "Processed #{row.processor}.#{row.event_type} and removed the delivery."
    end
  end
end
