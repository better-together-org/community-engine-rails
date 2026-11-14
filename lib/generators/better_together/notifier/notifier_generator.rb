# frozen_string_literal: true

require_relative '../namespace_options'

module BetterTogether
  module Generators
    # rails generate better_together:notifier NewReply [--mailer=ReplyMailer] [--namespace=X]
    class NotifierGenerator < Rails::Generators::NamedBase
      include NamespaceOptions

      source_root File.expand_path('templates', __dir__)

      class_option :mailer, type: :string, default: nil, desc: 'Mailer class for the email delivery (omit for none)'

      def create_notifier
        template 'notifier.rb.tt', "app/notifiers/#{ns_path}#{notifier_file}.rb"
      end

      def create_notifier_spec
        template 'notifier_spec.rb.tt', "spec/notifiers/#{ns_path}#{notifier_file}_spec.rb"
      end

      private

      def notifier_class
        class_name.end_with?('Notifier') ? class_name : "#{class_name}Notifier"
      end

      def notifier_file
        notifier_class.underscore
      end

      def notifier_body
        lines = ["# Noticed notifier for #{notifier_class.delete_suffix('Notifier').titleize} events.",
                 "class #{notifier_class} < #{'BetterTogether::' unless module_name}ApplicationNotifier",
                 "  deliver_by :action_cable, channel: 'BetterTogether::NotificationsChannel',",
                 '                            message: :build_message, queue: :notifications']
        lines += email_delivery_lines
        lines += ['', '  validates :record, presence: true', '',
                  '  def build_message(notification)',
                  '    { title: notification.event.class.name, url: nil }',
                  '  end', 'end']
        namespaced_lines("#{lines.join("\n")}\n")
      end

      def email_delivery_lines
        return [] unless options[:mailer]

        ["  deliver_by :email, mailer: '#{options[:mailer]}', method: :notify,",
         '                     params: :email_params, queue: :mailers']
      end
    end
  end
end
