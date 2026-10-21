# typed: false
# frozen_string_literal: true

module Repolho
  class Stats
    attr_reader :sum, :count, :min, :max

    def initialize
      reset
    end

    def add(value)
      return if value.nil?

      numeric = value.is_a?(Numeric) ? value : value.to_f
      @sum += numeric
      @count += 1
      @min = numeric if @min.nil? || numeric < @min
      @max = numeric if @max.nil? || numeric > @max
    end

    def avg
      @count.zero? ? 0.0 : @sum / @count
    end

    def reset
      @sum = 0.0
      @count = 0
      @min = nil
      @max = nil
    end
  end
end
