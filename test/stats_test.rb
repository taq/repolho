# frozen_string_literal: true

require_relative "test_helper"

module Repolho
  class StatsTest < Minitest::Test
    def setup
      @stats = Stats.new
    end

    def test_initial_state
      assert_equal 0.0, @stats.sum
      assert_equal 0, @stats.count
      assert_nil @stats.min
      assert_nil @stats.max
      assert_equal 0.0, @stats.avg
    end

    def test_add_numeric
      @stats.add(10)
      @stats.add(20.5)

      assert_equal 30.5, @stats.sum
      assert_equal 2, @stats.count
      assert_equal 10, @stats.min
      assert_equal 20.5, @stats.max
      assert_in_delta 15.25, @stats.avg, 0.001
    end

    def test_add_string_numeric
      @stats.add("15")
      @stats.add("-5.5")

      assert_equal 9.5, @stats.sum
      assert_equal 2, @stats.count
      assert_equal(-5.5, @stats.min)
      assert_equal 15.0, @stats.max
    end

    def test_add_nil_is_ignored
      @stats.add(nil)
      @stats.add(10)

      assert_equal 10.0, @stats.sum
      assert_equal 1, @stats.count
    end

    def test_avg_zero_count
      assert_equal 0.0, @stats.avg
    end

    def test_reset
      @stats.add(100)
      @stats.reset

      assert_equal 0.0, @stats.sum
      assert_equal 0, @stats.count
      assert_nil @stats.min
      assert_nil @stats.max
    end

    def test_min_max_single_value
      @stats.add(42)

      assert_equal 42, @stats.min
      assert_equal 42, @stats.max
    end
  end
end
