# frozen_string_literal: true

class AddPostgisExtensionToDatabase < ActiveRecord::Migration[7.0] # rubocop:todo Style/Documentation
  def change
    enable_extension 'postgis'
  end
end
