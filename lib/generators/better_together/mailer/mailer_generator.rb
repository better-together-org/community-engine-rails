# frozen_string_literal: true

require_relative '../namespace_options'

module BetterTogether
  module Generators
    # rails generate better_together:mailer Reply notify [--namespace=X]
    class MailerGenerator < Rails::Generators::NamedBase
      include NamespaceOptions

      source_root File.expand_path('templates', __dir__)

      argument :actions, type: :array, default: [], banner: 'action action'

      def create_mailer
        template 'mailer.rb.tt', "app/mailers/#{ns_path}#{mailer_file}.rb"
      end

      def create_views
        actions.each do |action|
          @action = action
          template 'view.html.erb.tt', "app/views/#{ns_path}#{mailer_file}/#{action}.html.erb"
        end
      end

      def create_mailer_spec
        template 'mailer_spec.rb.tt', "spec/mailers/#{ns_path}#{mailer_file}_spec.rb"
      end

      private

      def mailer_class
        class_name.end_with?('Mailer') ? class_name : "#{class_name}Mailer"
      end

      def mailer_file
        mailer_class.underscore
      end

      def mailer_body
        methods = actions.map do |action|
          <<~RUBY.indent(2)
            def #{action}(recipient)
              @recipient = recipient
              mail(to: recipient.email, subject: I18n.t('#{i18n_scope}.#{action}.subject'))
            end
          RUBY
        end.join("\n")
        namespaced_lines(<<~RUBY)
          # Mailer for #{mailer_class.delete_suffix('Mailer').titleize} messages.
          class #{mailer_class} < #{'BetterTogether::' unless module_name}ApplicationMailer
          #{methods}end
        RUBY
      end

      def i18n_scope
        "#{ns_path.tr('/', '.')}#{mailer_file}"
      end
    end
  end
end
