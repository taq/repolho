# frozen_string_literal: true

require_relative "test_helper"

module Repolho
  class ContainerTest < Minitest::Test
    def setup
      @stats = { "value" => Stats.new }
      @locals = { company: "Acme" }
      @container = Container.new("group1", @locals, @stats)
      @page = Page.new("page", {}, { "value" => Stats.new })
      @container.page = @page
    end

    def test_locals_become_instance_variables
      assert_equal "Acme", @container.instance_variable_get(:@company)
    end

    def test_sum_avg_count_min_max_delegate_to_stats
      @stats["value"].add(10)
      @stats["value"].add(20)

      assert_equal 30.0, @container.sum(:value)
      assert_in_delta 15.0, @container.avg(:value), 0.001
      assert_equal 2, @container.count(:value)
      assert_equal 10, @container.min(:value)
      assert_equal 20, @container.max(:value)
    end

    def test_sum_missing_attr_returns_zero
      assert_equal 0.0, @container.sum(:missing)
      assert_equal 0, @container.count(:missing)
    end

    def test_attr_returns_current_row_value
      @container.instance_variable_set(:@cur_row, { "id" => 42, "name" => "Test" })

      assert_equal 42, @container.attr(:id)
      assert_equal "Test", @container.attr(:name)
      assert_nil @container.attr(:missing)
    end

    def test_attr_without_current_row
      assert_equal "", @container.attr(:anything)
    end

    def test_start_renders_header_erb
      @container.header = { content: "<tr><td><%= @company %></td></tr>" }

      result = @container.start

      assert_includes result, "Acme"
      assert_includes result, "<tr>"
    end

    def test_finish_renders_footer_erb_and_increments_number
      @container.footer = { content: "<tr><td>Total: <%= sum(:value) %></td></tr>" }
      @stats["value"].add(100)

      result = @container.finish

      assert_includes result, "100"
      assert_equal 2, @container.number
    end

    def test_row_renders_template
      @container.row_template = "<tr><td><%= attr(:id) %></td></tr>"
      @container.instance_variable_set(:@cur_row, { "id" => 7 })

      result = @container.row

      assert_includes result, "7"
    end

    def test_row_without_template_returns_nil
      assert_nil @container.row
    end

    def test_force_header_reprint
      @container.status = Container::STARTED
      @container.force_header_reprint

      assert_equal Container::FINISHED, @container.status
    end

    def test_reset_stats
      @stats["value"].add(50)
      @container.reset_stats

      assert_equal 0.0, @stats["value"].sum
    end

    def test_status_constants
      assert_equal 0, Container::UNSTARTED
      assert_equal 1, Container::STARTED
      assert_equal 2, Container::FINISHED
    end
  end
end
