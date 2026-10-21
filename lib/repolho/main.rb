# typed: false
# frozen_string_literal: true
require_relative "container"
require_relative "page"
require_relative "report"
require_relative "stats"
require "nokogiri"
require "erb"

module Repolho
  class Main
    def initialize(path, data, locals = {})
      @path     = path
      @data     = normalize_data(data)
      @locals   = locals
      @columns  = make_columns
      @page     = Page.new("page", locals, make_stats)
      @report   = Report.new("report", locals, make_stats)
      @previous = ""
      @after    = ""
      @body     = ""

      @report.containers << @page
      @report.page = @page
    end

    def content
      @page.content
    end

    def run
      parse

      @page.append_raw(render_erb(@previous))
      @page.append_raw(@body)

      @data.each do |row|
        @report.call(:row, row)
      end

      @report.call(:finish, nil)
      @page.append_raw(render_erb(@after))
      @page.finalize
    end

    private

    def make_columns
      return [] if @data.empty?

      sample = @data.first

      sample.keys.select do |col|
        val = sample[col]
        val.is_a?(Numeric) || (val.is_a?(String) && val.match?(/\A-?\d+(\.\d+)?\z/))
      end
    end

    def normalize_data(data)
      return [] if data.nil? || (data.respond_to?(:empty?) && data.empty?)

      # ActiveRecord::Result (exec_query)
      if data.respond_to?(:columns) && data.respond_to?(:each)
        return data.map { |row| row.to_h.transform_keys(&:to_s) }
      end

      # ActiveRecord::Relation, array of models, or any Enumerable of objects with attributes
      rows = data.respond_to?(:to_a) ? data.to_a : Array(data)
      return [] if rows.empty?

      first = rows.first
      if first.respond_to?(:attributes)
        return rows.map { |r| r.attributes.transform_keys(&:to_s) }
      end

      # Already an array of hashes
      if first.is_a?(Hash)
        return rows.map { |r| r.transform_keys(&:to_s) }
      end

      rows
    end

    def make_stats
      @columns.each_with_object({}) do |column, memo|
        memo[column] = Stats.new
      end
    end

    def parse
      content = File.read(@path)
      extract_sections(content)
      build_report_structure
    end

    def extract_sections(content)
      matches = content.gsub(/\n/, "").match(/(?<previous>\A.*?)(?<body><body[^>]*>.*?)(?<report><report>.*?<\/report>)(?<after>.*)\z/m)

      @body     = matches[:body]
      @previous = matches[:previous]
      @after    = matches[:after]
      @report_xml = matches[:report]
    end

    def build_report_structure
      parsed = Nokogiri::HTML.parse(@report_xml)
      report = parsed.search("report")

      @report.header = info(report.search("> report-header").first)
      @report.footer = info(report.search("> report-footer").first)

      build_page(report)
      build_groups(report)
    end

    def build_page(report)
      page = report.search("report-page").first

      @page.header       = info(page.search("> report-header").first)
      @page.footer       = info(page.search("> report-footer").first)
      @page.row_template = report.search("report-row").first&.inner_html
      @page.rows         = page["rows"].to_i if page["rows"]
      @page.page         = @page
    end

    def build_groups(report)
      page = report.search("report-page").first
      ref_container = @page
      ref_element   = page

      while ref_element
        next_container = ref_element.search("> report-group").first
        break unless next_container

        container = build_group(next_container)
        ref_container.containers << container

        ref_container = container
        ref_element   = next_container
      end
    end

    def build_group(element)
      container = Container.new(element["id"], @locals, make_stats)
      container.header = info(element.search("> report-header").first)
      container.footer = info(element.search("> report-footer").first)
      container.attr   = element["attr"]
      container.reprint_header_on_page_break = element["reprint-header-on-page-break"] == "true"
      container.page   = @page
      container
    end

    def info(element)
      return { content: "" } unless element

      { content: element.inner_html }
    end

    def render_erb(content)
      return "" if content.nil? || content.empty?

      ERB.new(content).result(@page.instance_eval { binding })
    end
  end
end
