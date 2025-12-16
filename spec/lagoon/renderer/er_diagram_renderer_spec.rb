# frozen_string_literal: true

RSpec.describe Lagoon::Renderer::ErDiagramRenderer do
  subject(:renderer) { described_class.new }

  describe "#render" do
    let(:parsed_data) do
      {
        entities: [
          {
            name: "users",
            attributes: [
              { name: "id", type: :integer, primary_key: true, foreign_key: false, unique: false },
              { name: "name", type: :string, primary_key: false, foreign_key: false, unique: false },
              { name: "email", type: :string, primary_key: false, foreign_key: false, unique: true }
            ]
          },
          {
            name: "posts",
            attributes: [
              { name: "id", type: :integer, primary_key: true, foreign_key: false, unique: false },
              { name: "title", type: :string, primary_key: false, foreign_key: false, unique: false },
              { name: "user_id", type: :integer, primary_key: false, foreign_key: true, unique: false }
            ]
          }
        ],
        relationships: [
          {
            source: "users",
            target: "posts",
            label: "has many",
            source_cardinality: "||",
            target_cardinality: "}o",
            identifying: true
          }
        ]
      }
    end

    it "generates valid Mermaid ER diagram" do
      output = renderer.render(parsed_data)

      expect(output).to include("erDiagram")
      expect(output).to match(/USERS.*--.*POSTS/)
      expect(output).to include("USERS {")
      expect(output).to include("int id PK")
      expect(output).to include("string name")
      expect(output).to include("string email UK")
      expect(output).to include("POSTS {")
      expect(output).to include("int user_id FK")
    end

    it "handles entities without relationships" do
      data = {
        entities: [
          {
            name: "tags",
            attributes: [
              { name: "id", type: :integer, primary_key: true, foreign_key: false, unique: false },
              { name: "name", type: :string, primary_key: false, foreign_key: false, unique: false }
            ]
          }
        ],
        relationships: []
      }

      output = renderer.render(data)
      expect(output).to include("erDiagram")
      expect(output).to include("TAGS {")
      expect(output).to include("int id PK")
      expect(output).to include("string name")
    end

    it "handles non-identifying relationships" do
      data = {
        entities: [
          { name: "users", attributes: [] },
          { name: "profiles", attributes: [] }
        ],
        relationships: [
          {
            source: "users",
            target: "profiles",
            label: "has one",
            source_cardinality: "||",
            target_cardinality: "|o",
            identifying: false
          }
        ]
      }

      output = renderer.render(data)
      expect(output).to match(/USERS.*\.\..*PROFILES/)
    end
  end

  describe "#cardinality_symbol" do
    it "converts '1' to '||'" do
      expect(renderer.send(:cardinality_symbol, "1")).to eq("||")
    end

    it "converts '0..1' to '|o'" do
      expect(renderer.send(:cardinality_symbol, "0..1")).to eq("|o")
    end

    it "converts '1..*' to '}|'" do
      expect(renderer.send(:cardinality_symbol, "1..*")).to eq("}|")
    end

    it "converts '*' to '}o'" do
      expect(renderer.send(:cardinality_symbol, "*")).to eq("}o")
    end

    it "defaults to '||' for unknown cardinality" do
      expect(renderer.send(:cardinality_symbol, "unknown")).to eq("||")
    end
  end

  describe "#type_to_er_type" do
    it "converts integer to int" do
      expect(renderer.send(:type_to_er_type, :integer)).to eq("int")
    end

    it "converts string to string" do
      expect(renderer.send(:type_to_er_type, :string)).to eq("string")
    end

    it "converts text to text" do
      expect(renderer.send(:type_to_er_type, :text)).to eq("text")
    end

    it "converts datetime to datetime" do
      expect(renderer.send(:type_to_er_type, :datetime)).to eq("datetime")
    end

    it "converts json to json" do
      expect(renderer.send(:type_to_er_type, :json)).to eq("json")
    end
  end
end
