# frozen_string_literal: true

module Lagoon
  module Analyzer
    # Analyzes ActiveRecord models to extract metadata
    # including columns, methods, associations, and inheritance
    class ActiveRecordAnalyzer
      # Analyze a single model and return its metadata
      #
      # @param model [Class] ActiveRecord model class
      # @param options [Hash] Analysis options
      # @return [Hash] Model metadata
      def analyze_model(model, options = {})
        {
          name: model.name,
          abstract: model.abstract_class?,
          attributes: extract_columns(model, options),
          methods: extract_methods(model, options)
        }
      end

      # Extract associations from a model
      #
      # @param model [Class] ActiveRecord model class
      # @param options [Hash] Extraction options
      # @return [Array<Hash>] Association metadata
      def extract_associations(model, options = {})
        associations = []

        model.reflect_on_all_associations.each do |assoc|
          next if assoc.options[:through] && options[:hide_through]

          association_data = build_association(model, assoc, options)
          associations << association_data if association_data
        end

        associations
      end

      # Extract inheritance relationship from a model
      #
      # @param model [Class] ActiveRecord model class
      # @return [Array<Hash>] Inheritance metadata (empty or single element)
      def extract_inheritance(model)
        extract_inheritance_with_options(model)
      end

      def extract_inheritance_with_options(model, include_framework_base: false)
        return [] if model.superclass == ActiveRecord::Base && !include_framework_base
        return [] if model.superclass.nil? || model.superclass.name.nil?
        return [] if !include_framework_base && framework_model?(model.superclass)

        [{
          source: model.superclass.name,
          target: model.name,
          type: :inheritance,
          label: nil
        }]
      rescue NameError
        []
      end

      private

      def extract_columns(model, options = {})
        return [] unless options.fetch(:show_attributes, true)
        return [] unless model.table_exists?
        return [] if sti_subclass?(model) && !options[:duplicate_sti_attributes]

        columns = model.columns
        if options[:hide_magic] && !options[:all_columns]
          columns = columns.reject do |column|
            magic_field?(column.name)
          end
        end

        columns.sort_by(&:name).map do |column|
          {
            name: column.name,
            type: column.type,
            visibility: '+'
          }
        end
      end

      def magic_field?(field_name)
        %w[id created_at updated_at].include?(field_name)
      end

      def extract_methods(model, options = {})
        return [] unless options[:show_methods]

        declared_methods(model, :public_instance_methods, '+') +
          declared_methods(model, :protected_instance_methods, '#') +
          declared_methods(model, :private_instance_methods, '-')
      end

      def build_association(model, assoc, options = {})
        case assoc.macro
        when :belongs_to
          return nil unless options[:show_belongs_to]

          {
            source: model.name,
            target: association_target(assoc),
            type: :association,
            macro: :belongs_to,
            label: association_label(assoc),
            source_cardinality: '1',
            target_cardinality: belongs_to_optional?(model, assoc) ? '0..1' : '1',
            polymorphic: !assoc.options[:polymorphic].nil?
          }
        when :has_one
          {
            source: model.name,
            target: assoc.class_name,
            type: :association,
            macro: :has_one,
            label: association_label(assoc),
            source_cardinality: '1',
            target_cardinality: '0..1'
          }
        when :has_many
          {
            source: model.name,
            target: assoc.class_name,
            type: :association,
            macro: :has_many,
            label: association_label(assoc),
            source_cardinality: '1',
            target_cardinality: '*'
          }
        when :has_and_belongs_to_many
          {
            source: model.name,
            target: assoc.class_name,
            type: :association,
            macro: :has_and_belongs_to_many,
            label: association_label(assoc),
            source_cardinality: '*',
            target_cardinality: '*'
          }
        end
      rescue NameError
        nil
      end

      def declared_methods(model, query, visibility)
        model.public_send(query, false).select { |name| application_method?(model, name) }
                                       .sort_by(&:to_s).map do |name|
          { name: name.to_s, visibility: visibility }
        end
      end

      def application_method?(model, method_name)
        source_file = model.instance_method(method_name).source_location&.first
        return false unless source_file
        return application_model_file?(source_file) if defined?(Rails) && Rails.respond_to?(:root)

        !source_file.match?(%r{/gems/(?:activerecord|activesupport)-})
      rescue NameError
        false
      end

      def application_model_file?(source_file)
        models_path = File.expand_path(File.join(Rails.root.to_s, 'app', 'models'))
        File.expand_path(source_file).start_with?("#{models_path}#{File::SEPARATOR}")
      end

      def association_target(association)
        return association.name.to_s.camelize if association.options[:polymorphic]

        association.class_name
      end

      def association_label(association)
        label = "#{association.macro} #{association.name}"
        label += " through #{association.options[:through]}" if association.options[:through]
        label += ' (polymorphic)' if association.options[:polymorphic]
        label
      end

      def belongs_to_optional?(model, association)
        return association.options[:optional] if association.options.key?(:optional)
        return !association.options[:required] if association.options.key?(:required)

        return false unless model.respond_to?(:belongs_to_required_by_default)

        required = model.belongs_to_required_by_default
        required.nil? ? false : !required
      end

      def sti_subclass?(model)
        model.respond_to?(:base_class) && model.base_class != model && model.table_name == model.base_class.table_name
      end

      def framework_model?(model)
        model.name.start_with?('ActiveRecord::')
      end
    end
  end
end
