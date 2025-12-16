# frozen_string_literal: true

require "active_support/core_ext/string"

module Lagoon
  module Parser
    class ModelParser
      attr_reader :options, :config

      def initialize(options = {})
        @options = options
        @config = Lagoon.configuration
      end

      def parse
        models = load_models
        classes = []
        relationships = []

        models.each do |model|
          next if excluded?(model)

          classes << parse_model(model)
          relationships.concat(extract_associations(model))
          relationships.concat(extract_inheritance(model)) if config.include_inheritance
        end

        {
          classes: classes,
          relationships: relationships
        }
      end

      private

      def load_models
        # Railsアプリケーションの全モデルをロード
        return [] unless defined?(Rails)

        Rails.application.eager_load!
        ActiveRecord::Base.descendants.reject(&:abstract_class?)
      end

      def excluded?(model)
        model_name = model.name
        config.exclude_models.include?(model_name)
      end

      def parse_model(model)
        {
          name: model.name,
          abstract: model.abstract_class?,
          attributes: config.show_attributes ? extract_columns(model) : [],
          methods: config.show_methods ? extract_methods(model) : []
        }
      end

      def extract_columns(model)
        return [] unless model.table_exists?

        columns = if options[:all_columns]
                    model.columns
                  else
                    model.columns.reject { |col| magic_field?(col.name) }
                  end

        columns.map do |column|
          {
            name: column.name,
            type: column.type,
            visibility: "+"
          }
        end
      end

      def magic_field?(field_name)
        # マジックフィールド（created_at, updated_at等）を判定
        return false if options[:all_columns]

        %w[id created_at updated_at].include?(field_name)
      end

      def extract_methods(_model)
        # publicメソッドを抽出（必要に応じて実装）
        []
      end

      def extract_associations(model)
        associations = []

        model.reflect_on_all_associations.each do |assoc|
          next if assoc.options[:through] && options[:hide_through]

          associations << build_association(model, assoc)
        end

        associations.compact
      end

      def build_association(model, assoc)
        case assoc.macro
        when :belongs_to
          return nil unless options[:show_belongs_to]

          {
            source: model.name,
            target: assoc.class_name,
            type: :association,
            label: "belongs_to #{assoc.name}",
            source_cardinality: "1",
            target_cardinality: "0..1"
          }
        when :has_one
          {
            source: model.name,
            target: assoc.class_name,
            type: :association,
            label: "has_one #{assoc.name}",
            source_cardinality: "1",
            target_cardinality: "0..1"
          }
        when :has_many
          {
            source: model.name,
            target: assoc.class_name,
            type: :association,
            label: "has_many #{assoc.name}",
            source_cardinality: "1",
            target_cardinality: "*"
          }
        when :has_and_belongs_to_many
          {
            source: model.name,
            target: assoc.class_name,
            type: :association,
            label: "has_and_belongs_to_many #{assoc.name}",
            source_cardinality: "*",
            target_cardinality: "*"
          }
        end
      rescue NameError
        # アソシエーション先のクラスが見つからない場合はスキップ
        nil
      end

      def extract_inheritance(model)
        return [] if model.superclass == ActiveRecord::Base
        return [] if model.superclass.abstract_class?

        [{
          source: model.superclass.name,
          target: model.name,
          type: :inheritance,
          label: nil
        }]
      rescue StandardError
        []
      end
    end
  end
end
