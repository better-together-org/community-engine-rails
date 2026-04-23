# frozen_string_literal: true

# Runs the message content migration inline so fresh installs do not depend on
# the Rake task registry being available during migration execution.
class MigrateUnencryptedMessageContentAndDropColumn < ActiveRecord::Migration[7.1]
  def up
    BetterTogether::Message.reset_column_information

    BetterTogether::Message.find_each do |message|
      next if message.content.persisted? || message[:content].nil?

      message.content = message[:content]
      message.save!
    end
  end

  def down; end
end
