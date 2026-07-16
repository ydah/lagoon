# frozen_string_literal: true

module Lagoon
  class Error < StandardError; end
  class ConfigurationError < Error; end
  class RailsLoadError < Error; end
  class ParseError < Error; end
  class OutputError < Error; end
end
