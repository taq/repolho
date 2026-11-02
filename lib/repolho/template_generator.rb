# typed: false
# frozen_string_literal: true

require "cgi"

module Repolho
  # Generates a .rep.erb template from a base template and column metadata.
  #
  # The base template must contain a <report-page> element and the markers
  # <!-- REPORT:HEADERS --> and <!-- REPORT:ROW -->. The page element is
  # required, matching the runtime expectation.
  #
  # Column labels are resolved case-insensitively (original, downcase, upcase)
  # via I18n when available. Otherwise a simple humanized form of the column
  # name is used.
  class TemplateGenerator
    HEADERS_MARKER = "<!-- REPORT:HEADERS -->"
    ROW_MARKER     = "<!-- REPORT:ROW -->"

    def initialize(base_path, data, model: nil, labels: {}, numeric: [])
      @base_path = base_path
      @data      = data
      @model     = model
      @labels    = labels.transform_keys(&:to_s)
      @numeric   = Array(numeric).map(&:to_s)
    end

    # Returns the generated template content as a String.
    def generate
      content = File.read(@base_path)
      validate_base!(content)

      columns = extract_columns(@data)
      raise ArgumentError, "No columns could be extracted from the given data" if columns.empty?

      headers = generate_headers(columns)
      row     = generate_row(columns)

      content
        .gsub(HEADERS_MARKER, headers)
        .gsub(ROW_MARKER, row)
    end

    # Writes the generated template to output_path.
    def write(output_path)
      File.write(output_path, generate)
    end

    private

    def validate_base!(content)
      unless content.include?("<report-page")
        raise ArgumentError, "Base template must contain a <report-page> element"
      end

      unless content.include?(HEADERS_MARKER)
        raise ArgumentError, "Base template must contain the marker #{HEADERS_MARKER}"
      end

      unless content.include?(ROW_MARKER)
        raise ArgumentError, "Base template must contain the marker #{ROW_MARKER}"
      end
    end

    def extract_columns(data)
      return data.map(&:to_s) if explicit_column_list?(data)

      if data.respond_to?(:columns)
        return data.columns.map(&:to_s)
      end

      if data.respond_to?(:klass) && data.klass.respond_to?(:column_names)
        if data.respond_to?(:select_values) && data.select_values.any?
          return data.select_values.map { |v| extract_column_name(v) }
        end
        return data.klass.column_names.map(&:to_s)
      end

      extract_from_rows(data)
    end

    def explicit_column_list?(data)
      data.is_a?(Array) && data.all? { |c| c.is_a?(String) || c.is_a?(Symbol) }
    end

    def extract_column_name(value)
      value.to_s.split(".").last.gsub(/["'`]/, "").strip
    end

    def extract_from_rows(data)
      rows = data.respond_to?(:to_a) ? data.to_a : Array(data)
      return [] if rows.empty?

      first = rows.first
      if first.respond_to?(:attributes)
        first.attributes.keys.map(&:to_s)
      elsif first.is_a?(Hash)
        first.keys.map(&:to_s)
      else
        []
      end
    end

    def generate_headers(columns)
      columns.map { |col| "<th>#{CGI.escapeHTML(column_label(col))}</th>" }.join("\n            ")
    end

    def generate_row(columns)
      cells = columns.map do |col|
        expr = if @numeric.include?(col)
                 %(<%= number_with_precision(attr(:#{col}), precision: 2) %>)
               else
                 %(<%= attr(:#{col}) %>)
               end
        "<td>#{expr}</td>"
      end

      <<~HTML.strip
        <report-row>
          <tr>
            #{cells.join("\n            ")}
          </tr>
        </report-row>
      HTML
    end

    def column_label(column)
      column = column.to_s
      return @labels[column] if @labels.key?(column)

      return humanize(column) unless defined?(I18n)

      [column, column.downcase, column.upcase].uniq.each do |key|
        full_key = if @model
                     "activerecord.attributes.#{@model.model_name.i18n_key}.#{key}"
                   else
                     "repolho.attributes.#{key}"
                   end

        result = I18n.t(full_key, default: nil)
        return result if result
      end

      humanize(column)
    end

    def humanize(column)
      column.to_s.tr("_", " ").capitalize
    end
  end
end
