# frozen_string_literal: true

RSpec.describe Lagoon::Parser::SchemaParser do
  let(:id) { double("Column", name: "id", type: :integer, null: false) }
  let(:user_id) { double("Column", name: "user_id", type: :integer, null: false) }
  let(:foreign_key) { double("ForeignKey", column: "user_id", to_table: "users") }
  let(:schema_cache) { double("SchemaCache") }
  let(:connection) do
    double(
      "Connection",
      tables: %w[posts users schema_migrations],
      schema_cache: schema_cache
    )
  end

  before do
    allow(schema_cache).to receive(:columns).with("posts").and_return([id, user_id])
    allow(schema_cache).to receive(:columns).with("users").and_return([id])
    allow(connection).to receive(:primary_keys).with("posts").and_return(["id"])
    allow(connection).to receive(:primary_keys).with("users").and_return(["id"])
    allow(connection).to receive(:foreign_keys).with("posts").and_return([foreign_key])
    allow(connection).to receive(:foreign_keys).with("users").and_return([])
    allow(connection).to receive(:indexes).with("posts").and_return([])
    allow(connection).to receive(:indexes).with("users").and_return([])
  end

  it "builds a parent-to-child ER relationship from actual metadata" do
    result = described_class.new(connections: { primary: connection }).parse

    expect(result[:entities].map { |entity| entity[:name] }).to eq(%w[posts users])
    expect(result[:relationships]).to contain_exactly(
      hash_including(
        source: "users",
        target: "posts",
        source_cardinality: :one,
        target_cardinality: :zero_or_many
      )
    )
  end

  it "implements exclude and specify" do
    excluded = described_class.new(connections: { primary: connection }, exclude: ["posts"]).parse
    specified = described_class.new(connections: { primary: connection }, specify: ["users"]).parse

    expect(excluded[:entities].map { |entity| entity[:name] }).to eq(["users"])
    expect(specified[:entities].map { |entity| entity[:name] }).to eq(["users"])
  end

  it "qualifies tables for multiple databases" do
    result = described_class.new(connections: { primary: connection, archive: connection }).parse

    expect(result[:entities].map { |entity| entity[:name] }).to include(
      "primary.posts", "primary.users", "archive.posts", "archive.users"
    )
    expect(result[:relationships]).to include(
      hash_including(source: "primary.users", target: "primary.posts"),
      hash_including(source: "archive.users", target: "archive.posts")
    )
  end
end
