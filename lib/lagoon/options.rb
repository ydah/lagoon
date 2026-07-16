# frozen_string_literal: true

module Lagoon
  class Options
    include Enumerable

    COMMON_KEYS = %i[output verbose strict eager_load].freeze
    KEYS = {
      model: COMMON_KEYS + %i[
        direction brief show_attributes show_methods include_inheritance exclude specify
        all_models show_belongs_to hide_through all_columns hide_magic hide_types
        include_framework_bases duplicate_sti_attributes
      ],
      controller: COMMON_KEYS + %i[
        direction brief include_inheritance exclude specify all_controllers hide_public
        hide_protected hide_private include_framework_bases
      ],
      er: COMMON_KEYS + %i[exclude specify connections internal_tables],
      controller_model: COMMON_KEYS + %i[
        direction exclude specify all_controllers show_actions helper_models
      ]
    }.transform_values(&:freeze).freeze

    attr_reader :kind

    def self.for(kind, raw_options = nil, config: Lagoon.configuration, **keyword_options)
      options = (raw_options || {}).to_h.merge(keyword_options)
      new(kind, options, config: config)
    end

    def self.allowed_keys(kind)
      KEYS.fetch(kind)
    end

    def initialize(kind, raw_options = {}, config: Lagoon.configuration)
      @kind = kind.to_sym
      @config = config
      @raw = symbolize_keys(raw_options)
      validate_keys!
      @values = normalize.freeze
      freeze
    end

    def [](key)
      @values[key.to_sym]
    end

    def fetch(key, *defaults, &)
      @values.fetch(key.to_sym, *defaults, &)
    end

    def key?(key)
      @values.key?(key.to_sym)
    end

    def each(&)
      @values.each(&)
    end

    def to_h
      @values.dup
    end

    private

    def symbolize_keys(raw_options)
      raw_options.to_h.transform_keys(&:to_sym)
    end

    def validate_keys!
      unknown = @raw.keys - self.class.allowed_keys(@kind)
      return if unknown.empty?

      raise ConfigurationError, "Unknown #{@kind} option(s): #{unknown.sort.join(', ')}"
    end

    def normalize
      values = common_values
      case @kind
      when :model then values.merge(model_values)
      when :controller then values.merge(controller_values)
      when :er then values.merge(er_values)
      when :controller_model then values.merge(controller_model_values)
      else raise ConfigurationError, "Unknown diagram kind: #{@kind}"
      end
    end

    def common_values
      {
        output: optional_path(@raw[:output]),
        verbose: boolean(:verbose, false),
        strict: boolean(:strict, @config.strict),
        eager_load: boolean(:eager_load, true)
      }
    end

    def model_values
      brief = boolean(:brief, false)
      {
        direction: direction,
        brief: brief,
        show_attributes: brief ? false : boolean(:show_attributes, @config.show_attributes),
        show_methods: brief ? false : boolean(:show_methods, @config.show_methods),
        include_inheritance: boolean(:include_inheritance, @config.include_inheritance),
        exclude: names(@config.exclude_models, @raw[:exclude]),
        specify: names(@raw[:specify]),
        all_models: boolean(:all_models, false),
        show_belongs_to: boolean(:show_belongs_to, false),
        hide_through: boolean(:hide_through, false),
        all_columns: boolean(:all_columns, false),
        hide_magic: boolean(:hide_magic, false),
        hide_types: boolean(:hide_types, false),
        include_framework_bases: boolean(:include_framework_bases, @config.include_framework_bases),
        duplicate_sti_attributes: boolean(:duplicate_sti_attributes, false)
      }
    end

    def controller_values
      brief = boolean(:brief, false)
      {
        direction: direction,
        brief: brief,
        include_inheritance: boolean(:include_inheritance, @config.include_inheritance),
        exclude: names(@config.exclude_controllers, @raw[:exclude]),
        specify: names(@raw[:specify]),
        all_controllers: boolean(:all_controllers, false),
        hide_public: brief || boolean(:hide_public, false),
        hide_protected: brief || boolean(:hide_protected, false),
        hide_private: brief || boolean(:hide_private, false),
        include_framework_bases: boolean(:include_framework_bases, @config.include_framework_bases)
      }
    end

    def er_values
      {
        exclude: names(@config.exclude_tables, @raw[:exclude]),
        specify: names(@raw[:specify]),
        connections: @raw[:connections],
        internal_tables: names(@raw.fetch(:internal_tables, @config.internal_tables))
      }
    end

    def controller_model_values
      {
        direction: direction,
        exclude: names(@config.exclude_controllers, @raw[:exclude]),
        specify: names(@raw[:specify]),
        all_controllers: boolean(:all_controllers, false),
        show_actions: boolean(:show_actions, true),
        helper_models: normalize_helper_models(@raw.fetch(:helper_models, @config.helper_models))
      }
    end

    def direction
      value = @raw.fetch(:direction, @config.diagram_direction)
      Configuration.validate_direction!(value)
    end

    def boolean(key, default)
      @raw.key?(key) ? !!@raw[key] : default
    end

    def names(*groups)
      groups.compact.flatten.map(&:to_s).reject(&:empty?).uniq.sort.freeze
    end

    def normalize_helper_models(mapping)
      mapping.to_h.each_with_object({}) do |(helper, model), result|
        result[helper.to_s] = model.to_s
      end.freeze
    end

    def optional_path(path)
      return nil if path.nil?

      value = path.to_s
      raise ConfigurationError, 'Output path cannot be empty' if value.empty?

      value.freeze
    end
  end
end
