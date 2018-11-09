# frozen_string_literal: true

require 'logger'

# Logging support
module Amplitude
  module Logging
    # Get the logger instance
    #
    # @return [Logger]
    def logger
      Amplitude.logger
    end
  end
end
