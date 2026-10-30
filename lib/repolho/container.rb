# typed: false
# frozen_string_literal: true
require "erb"
require "cgi"
require_relative "stats"

module Repolho
  class Container
    attr_accessor :header, :footer, :containers, :row_template, :attr, :page, :report, :status, :reprint_header_on_page_break
    attr_reader :id, :number, :stats

    UNSTARTED = 0
    STARTED   = 1
    FINISHED  = 2

    def initialize(id, locals, stats)
      @id           = id
      @locals       = locals
      @stats        = stats
      @header       = nil
      @footer       = nil
      @containers   = []
      @status       = UNSTARTED
      @row_template = nil
      @cur_row      = nil
      @prev_row     = nil
      @number       = 1
      @attr         = nil
      @page         = nil
      @report       = nil

      create_locals
    end

    def call(type, data)
      @prev_row = @cur_row

      check_attribute_break(data)
      check_page_break

      @cur_row = data if data
      update_stats if data && type == :row
      check_started

      @containers.each do |container|
        container.call(type, data)
      end

      @page << row if type == :row
      check_finish(type)
    end

    def start
      return unless @header

      ERB.new(CGI.unescapeHTML(@header[:content])).result(binding)
    end

    def finish
      return unless @footer

      rst = ERB.new(CGI.unescapeHTML(@footer[:content])).result(binding)

      @number += 1
      rst
    end

    def row
      ERB.new(CGI.unescapeHTML(@row_template)).result(binding) if @row_template
    end

    def row_number = @page.row_number

    def sum(attr, context = nil)
      stat(attr, context)&.sum || 0.0
    end

    def avg(attr, context = nil)
      stat(attr, context)&.avg || 0.0
    end

    def count(attr, context = nil)
      stat(attr, context)&.count || 0
    end

    def min(attr, context = nil)
      stat(attr, context)&.min
    end

    def max(attr, context = nil)
      stat(attr, context)&.max
    end

    def attr(attr)
      return "" unless @cur_row

      @cur_row[attr.to_s]
    end

    def reset_stats
      @stats.each_value(&:reset)
    end

    def force_header_reprint
      @status = FINISHED if @status == STARTED
    end

    def force_header_reprint_on_children
      @containers.each do |container|
        container.force_header_reprint if container.reprint_header_on_page_break
        container.force_header_reprint_on_children
      end
    end

    private

    def create_locals
      @locals.each do |name, value|
        instance_variable_set("@#{name}".to_sym, value)
      end
    end

    def update_stats
      return unless @cur_row

      @stats.each do |key, stats|
        stats.add(@cur_row[key])
      end
    end

    def stat(attr, context = nil)
      target_stats = resolve_stats(context)
      target_stats&.[](attr.to_s)
    end

    def resolve_stats(context)
      return @stats if context.nil?

      case context
      when :page
        @page&.stats
      when :report
        @report&.stats
      when Container
        context.stats
      else
        @stats
      end
    end

    def check_attribute_break(data)
      return unless @attr && @prev_row && data
      return if self.is_a?(Page) || @status == FINISHED

      prev_attr = @prev_row[@attr]
      cur_attr  = data[@attr]

      if prev_attr != cur_attr
        @containers.each do |container|
          next if container.status == FINISHED

          @page << container.finish
          container.reset_stats
          container.status = FINISHED
        end

        @page << finish
        reset_stats
        @status = FINISHED
      end
    end

    def check_page_break
      return unless self.is_a?(Page)
      return unless @row_number >= @valid_rows

      @page << finish
      reset_stats
      @row_number = 0
      @status = FINISHED

      # Force header reprint on groups that requested it
      force_header_reprint_on_children
    end

    def check_started
      return unless @status != STARTED

      @page << start
      @status = STARTED
    end

    def check_finish(type)
      return unless type == :finish && @status != FINISHED

      @page << finish
      @status = FINISHED
      reset_stats
    end
  end
end
