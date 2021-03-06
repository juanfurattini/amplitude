# frozen_string_literal: true

require 'amplitude/version'
require 'amplitude/configuration'
require 'amplitude/event'
require 'amplitude/identification'
require 'amplitude/api'
require 'amplitude/logging'

module Amplitude
  def self.configuration
    @configuration ||= Amplitude::Configuration.instance
  end

  def self.configure
    yield configuration if block_given?
  end

  # @!attribute [rw] logger
  # @return [Logger] The logger.
  def self.logger
    @logger ||= rails_logger || default_logger
  end

  class << self
    private

    # Create and configure a logger
    # @return [Logger]
    def default_logger
      Logger.new($stdout).tap { |logger| logger.level = Logger::WARN }
    end

    # Check to see if client is being used in a Rails environment and get the logger if present.
    # Setting the ENV variable 'VERONA_USE_RAILS_LOGGER' to false will force the client
    # to use its own logger.
    #
    # @return [Logger]
    def rails_logger
      ::Rails.logger if configuration.use_rails_logger? && can_use_rails_logger?
    end

    def can_use_rails_logger?
      defined?(::Rails) && ::Rails.respond_to?(:logger) && !::Rails.logger.nil?
    end
  end
end
