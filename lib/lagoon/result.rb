# frozen_string_literal: true

module Lagoon
  Result = Data.define(:path, :content, :warnings, :counts) do
    def initialize(path:, content:, warnings: [], counts: {})
      super(
        path: path.to_s.freeze,
        content: content.to_s.freeze,
        warnings: warnings.map(&:to_s).freeze,
        counts: counts.transform_keys(&:to_sym).freeze
      )
    end

    def to_s
      path
    end

    def to_path
      path
    end
  end
end
