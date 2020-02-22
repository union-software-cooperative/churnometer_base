#  Churnometer - A dashboard for exploring a membership organisations turn-over/churn
#  Copyright (C) 2012-2013 Lucas Rohde (freeChange)
#  lukerohde@gmail.com
#
#  Churnometer is free software: you can redistribute it and/or modify
#  it under the terms of the GNU Affero General Public License as published by
#  the Free Software Foundation, either version 3 of the License, or
#  (at your option) any later version.
#
#  Churnometer is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU Affero General Public License for more details.
#
#  You should have received a copy of the GNU Affero General Public License
#  along with Churnometer.  If not, see <http://www.gnu.org/licenses/>.

require 'json'
require 'csv'

require './lib/settings.rb'

class ChurnPresenter_Tables
  include Enumerable
  include Settings

  attr_accessor :tables

  def initialize(app, request)
    @app = app
    @request = request

    @tables = Array.new

    user_data_tables =
      if @request.type == :summary
        if @request.groupby_column_id == 'userid'
          (Array.new << @app.summary_user_data_tables['userid'])
        else
          @request.auth.role.summary_data_tables
        end
      else
        @request.auth.role.detail_data_tables
      end

    user_data_tables.each do |user_data_table|
      @tables << ChurnPresenter_Table.new(app, request, user_data_table.display_name, user_data_table.description, user_data_table.column_names)
    end
  end

  # Tables wrappers
  def each
    tables.each { |table| yield table}
  end

  def [](index)
    @tables.find{ |t| t.id == index.downcase }
  end
end



class ChurnPresenter_Table
  attr_reader :id
  attr_reader :name
  attr_reader :description
  attr_reader :type
  attr_reader :columns

  include Settings
  include ChurnPresenter_Helpers

  def initialize(app, request, name, description, columns)
    @app = app
    @id = name.gsub(' ', '').downcase
    @name = name
    @description = description
    @request = request
    @type = request.type
    @data = request.data

    @column_id_to_header = {}
    @columns = []

    columns.each do |c|
      next if c.empty?

      # If the entry in the 'columns' array is an id of one of the dimensions, then get the database's
      # column name for that dimension.
      #
      # Otherwise, the column may be one that's expected to be returned from the query that produced
      # the data, i.e. query_detail returns a column called 'row_header'.
      #
      # If neither condition is true or the resulting column name isn't present in the data being used
      # to present the table, then don't include the column in the table display.

      # dimension_for_id_with_delta is used to retrieve the master dimensions from query columns that
      # express deltas, i.e. returning delta info for the 'status' dimension from 'oldstatus',
      # 'newstatus', etc.
      dimension_for_column_id = @app.dimensions.dimension_for_id_with_delta(c)

      data_column_name =
        if !dimension_for_column_id.nil?
          dimension_for_column_id.column_base_name
        else
          c
        end

      if request.data[0].include?(data_column_name)
        @columns << data_column_name

        if dimension_for_column_id.nil?
          # col_names is from Settings mixin
          @column_id_to_header[data_column_name] = col_names[c] || c
        else
          settings_entry = col_names[dimension_for_column_id.id]

          # dbeswick: downcasing of dimension name is done to keep consistency with previous behaviour
          # use the entry in the Settings mixin's 'col_names' hash if avaiable, otherwise use the
          # dimension's name.
          @column_id_to_header[data_column_name] =
            if settings_entry.nil? || settings_entry.empty?
              dimension_for_column_id.name.downcase
            else
              settings_entry
            end
        end
      end
    end
  end

  def header
    @column_id_to_header
  end

  def footer
    if @footer.nil? && type==:summary
      @footer = Hash.new

      @data.each do |row|
        @columns.each do |column_name|
          value = row[column_name]
          @footer[column_name] ||= 0
          @footer[column_name] = safe_add footer[column_name], value
        end
      end
    end

    @footer
  end

  def display_header(column_name)
    content = @column_id_to_header[column_name] || column_name

    if bold_col?(column_name)
      "<strong>#{content}</strong>"
    else
      content
    end
  end

  def date_col(column_name)
    date_cols.include?(column_name) ? "class=\"{sorter: 'medDate'}\"" : ""
  end

  def display_cell(column_name, row)
    value = row[column_name]

    if date_cols.include?(column_name)
      value = format_date(row[column_name])
    end

    #todo figure out why this doesn't work for member tables
    if column_name == 'changedate'
      value = Date.parse(row['changedate']).strftime(DateFormatDisplay)
    end

    if column_name == 'row_header1'
      content = "<a href=\"#{build_url(drill_down_header(row, @app)) }\">#{row['row_header1']}</a>"
    elsif column_name == 'period_header'
      content = "<a href=\"#{build_url(drill_down_interval(row))}\">#{value}</a>"
    elsif can_detail_cell? column_name, value
      content = "<a href=\"#{build_url(drill_down_cell(row, column_name)) }\">#{value}</a>"
    elsif can_export_cell? column_name, value
      content = "<a href=\"export_table#{build_url(drill_down_cell(row, column_name).merge!({'table' => 'membersummary'}))}\">#{value}</a>"
    else
      content = value
    end

    if bold_col?(column_name)
        bold(content)
    else
      content
    end
  end

  def display_footer(column_name, total)
    if !no_total.include?(column_name)
      if can_detail_cell?(column_name, total)
        content = "<a href=\"#{build_url(drill_down_footer(column_name))}\">#{total}</a>"
      elsif can_export_cell?(column_name, total)
          content = "<a href=\"export_table#{build_url(drill_down_footer(column_name).merge!({'table' => 'membersummary'}))}\">#{total}</a>"
      else
        content = total
      end

      if bold_col?(column_name)
        bold(content)
      else
        content
      end
    end
  end

  def bold(content)
    "<span class=\"bold_col\">#{content}</span>"
  end

  def tooltips
    tips.reject{ |k,v| !@columns.include?(k)}
  end

  # Wrappers
  def [](index)
    @data[index]
  end

  def each
    @data.each { |row| yield row }
  end

  def raw_data
    @data
  end

  def to_json
    @data.to_json
  end

  def to_csv
    CSV.open("tmp/data.csv", "w", { headers: true }) do |csv|
      csv << @columns.map { |c| @column_id_to_header[c] || c }

      @data.each(&csv.method(:<<))
    end

    "tmp/data.csv"
  end

  def to_excel
    book = Spreadsheet::Excel::Workbook.new
    sheet = book.create_worksheet

     # Add header
    @columns.each_with_index do |c, x|
      sheet[0, x] = (@column_id_to_header[c] || c)
    end

    # Add data
    @data.each_with_index do |row, y|
      @columns.each_with_index do |c,x|
        if filter_columns.include?(c)
          sheet[y + 1, x] = row[c].to_f
        else
          sheet[y + 1, x] = row[c]
        end
      end
    end

    path = "tmp/data.xls"
    book.write path

    path
  end

  private
  def drill_down_footer(column_name)
    { 'column' => column_name }
  end

  def drill_down_interval(row)
    drill_down_header(row, @app).merge!({
      'period' => 'custom',
      'startDate' => row['period_start'],
      'endDate' => row['period_end']
    })
  end

  def can_detail_cell?(column_name, value)
    (
      filter_columns.include? column_name
    ) && (value.to_i != 0 && value.to_i.abs < MaxMemberList)
  end

  def can_export_cell?(column_name, value)
    (
      filter_columns.include? column_name
    ) && (value.to_i != 0)
  end

  def safe_add(a, b)
    if (a =~ /\./) || (b =~ /\./ )
      a.to_f + b.to_f
    else
      a.to_i + b.to_i
    end
  end
end
