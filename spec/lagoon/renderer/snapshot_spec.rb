# frozen_string_literal: true

RSpec.describe "renderer snapshots" do
  def snapshot(name)
    File.read(File.expand_path("../../fixtures/snapshots/#{name}.mermaid", __dir__)).chomp
  end

  it "keeps class output deterministic and escaped" do
    data = {
      classes: [
        { name: "Post", abstract: false, attributes: [], methods: [] },
        {
          name: "Admin::User",
          abstract: false,
          attributes: [{ name: 'display"name', type: :string, visibility: "+" }],
          methods: [{ name: "active?", visibility: "+" }]
        }
      ],
      relationships: [
        {
          source: "Admin::User",
          target: "Post",
          type: :association,
          label: "has_many posts",
          source_cardinality: "1",
          target_cardinality: "*"
        }
      ]
    }

    output = Lagoon::Renderer::ClassDiagramRenderer.new(direction: "LR").render(data)

    expect(output).to eq(snapshot("class_diagram"))
  end

  it "keeps ER output deterministic and safely identified" do
    data = {
      entities: [
        {
          name: "audit.logs",
          attributes: [
            { name: "actor-id", type: :string, primary_key: false, foreign_key: true, unique: false }
          ]
        },
        { name: "accounts", attributes: [] }
      ],
      relationships: [
        {
          source: "accounts",
          target: "audit.logs",
          label: 'has "many"',
          source_cardinality: :one,
          target_cardinality: :zero_or_many,
          identifying: false
        }
      ]
    }

    output = Lagoon::Renderer::ErDiagramRenderer.new.render(data)

    expect(output).to eq(snapshot("er_diagram"))
  end

  it "keeps dependency output deterministic" do
    data = {
      relationships: [
        { controller: "Admin::UsersController", model: "User", actions: %w[show index] }
      ]
    }

    output = Lagoon::Renderer::ControllerModelErRenderer.new(show_actions: true).render(data)

    expect(output).to eq(snapshot("controller_model_diagram"))
  end
end
