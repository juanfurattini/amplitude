# frozen_string_literal: true

require 'singleton'

module Amplitude
  class Configuration
    include Singleton

    attr_accessor :api_key, :secret_key, :use_rails_logger,
                  :time_formatter, :event_properties_formatter, :user_properties_formatter

    def initialize
      @api_key = nil
      @secret_key = nil
      @use_rails_logger = false
      @time_formatter = -> (time) { time ? time.to_i * 1_000 : nil }
      @event_properties_formatter = -> (props) { props || {} }
      @user_properties_formatter = -> (props) { props || {} }
    end

    def use_rails_logger?
      !(!use_rails_logger)
    end
  end
end
