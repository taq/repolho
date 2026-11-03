# typed: false
# frozen_string_literal: true

module Repolho
  class Page < Container
    attr_reader :content, :row_number, :rows, :page_number
    attr_accessor :min_row_for_break

    def initialize(id, locals, stats)
      super(id, locals, stats)

      @content     = []
      @rows        = 60
      @valid_rows  = @rows
      @row_number  = 1
      @page_number = 1
      @page_open   = false
      @last_page   = false
    end

    def rows=(number)
      @rows = number
      @valid_rows = @rows
    end

    def last_page?
      @last_page
    end

    def mark_as_last!
      @last_page = true
    end

    # Injects pre-rendered HTML (expected to contain <tr>s) as additional rows.
    # Each <tr> is appended individually so normal page-break logic applies.
    def inject_as_rows(html)
      return if html.nil? || html.strip.empty?

      Nokogiri::HTML(html).search("tr").each do |tr|
        check_page_break
        # After a break, status is FINISHED; reopen so later :finish can still emit the footer
        @status = STARTED if @status == FINISHED
        self << tr.to_html
      end
    end

    # Fills the current page with blank rows up to the limit and forces a break
    # using the existing page-break path. Called *after* a group footer has
    # already been emitted, so the footer stays on the current page and the
    # next group starts on a fresh page.
    #
    # After the break, the new page is opened and its header is emitted
    # immediately so subsequent content (the group footer) appears *after*
    # the page header, not before it.
    def pad_and_break
      remaining = @valid_rows - @row_number
      if remaining > 0
        blank = %(<tr><td colspan="200">&nbsp;</td></tr>)
        remaining.times { self << blank }
      end
      check_page_break

      # Open the new page and emit its header right away.
      # check_page_break left status as FINISHED; we start the page now
      # so later check_started does not emit the header again (late).
      return if @page_open

      open_page
      if @status == FINISHED
        header_html = start
        self << header_html if header_html && !header_html.to_s.strip.empty?
        @status = STARTED
      end
    end

    def <<(content)
      return unless content

      open_page unless @page_open

      content = content.is_a?(String) ? content : Array(content).join

      parsed = Nokogiri::HTML(content)
      trs    = parsed.search("tr")
      @row_number += trs.size
      @content << content
    end

    # Appends content outside the page tbodies (previous, body, after)
    def append_raw(content)
      return unless content

      @content << content
    end

    def open_page
      return if @page_open

      @content << %(<tbody class="repolho-page" data-page="#{@page_number}" style="break-after: page; page-break-after: always;">)
      @page_open = true
    end

    def close_page
      return unless @page_open

      @content << "</tbody>"
      @page_open = false
      @page_number += 1
    end

    def finalize
      close_page
    end

    private

    def check_page_break
      return unless @row_number >= @valid_rows

      @page << finish
      close_page
      reset_stats
      @row_number = 0
      @status = FINISHED

      force_header_reprint_on_children
    end
  end
end
