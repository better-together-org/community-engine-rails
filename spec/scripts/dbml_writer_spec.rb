# frozen_string_literal: true

require 'rails_helper'
require Rails.root.join('../../scripts/schema_dbml/schema_recorder').to_s
require Rails.root.join('../../scripts/schema_dbml/dbml_writer').to_s

RSpec.describe DbmlWriter, :skip_host_setup do
  let(:recorder) do
    SchemaRecorder.new.tap do |schema|
      schema.define(version: 1) do
        create_table 'parents', id: :uuid do |t|
          t.string 'name'
        end
        create_table 'children', id: :uuid do |t|
          t.uuid 'parent_id'
          t.uuid 'platform_id'
        end
        add_foreign_key 'children', 'parents'
        add_foreign_key 'children', 'parents', column: %w[parent_id platform_id], primary_key: %w[id platform_id]
      end
    end
  end

  it 'writes single-column references and leaves composite ones out' do
    dbml = described_class.new(recorder).to_s

    expect(dbml.scan(/^Ref:/).size).to eq(1)
    expect(dbml).to include('Ref: "children"."parent_id" > "parents"."id"')
  end
end
