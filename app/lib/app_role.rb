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

require './lib/config'

class AppRoleMissingException < RuntimeError
  def initialize(role_id)
    super("The role '#{role_id}' hasn't been defined.")
  end
end

class AppRoles
  include Enumerable

  def initialize
    @id_to_role = {}
  end

  # summary_data_tables: A UserDataTables instance containing all of the possible UserDataTables defined
  #   for 'summary' queries.
  # detail_data_tables: As above, for 'detail' queries.
  def from_config_element(config_element, summary_data_tables, detail_data_tables, default_password)
    config_element.ensure_kindof(Hash)

    config_element.value.each do |role_id, hash_element|
      role = AppRole.from_config_element(role_id.downcase, hash_element, summary_data_tables, detail_data_tables, default_password)
      @id_to_role[role.id] = role
    end
  end

  def [](id)
    @id_to_role[id]
  end

  def get_mandatory(id)
    self[id] || raise(AppRoleMissingException.new(id))
  end

  def each(&block)
    @id_to_role.values.each(&block)
  end
end

class AppRole
  attr_reader :id
  attr_reader :password
  attr_reader :summary_data_tables
  attr_reader :detail_data_tables
  attr_reader :admin

  def self.config_forbidden_ids
    ['all', 'none']
  end

  def self.from_config_element(id, config_element, summary_data_tables, detail_data_tables, default_password)
    config_element.instance_eval do
      ensure_kindof(Hash)
    end

    if config_forbidden_ids().include?(id)
      raise BadConfigDataFormatException.new(config_element, "The role id '#{id}' is reserved and can't be used in the config file.")
    end

    hash = config_element

    new(id,
        config_element.optional('password') || default_password,
        resolve_data_tables(config_element['summary_data_tables'], summary_data_tables, config_element),
        resolve_data_tables(config_element['detail_data_tables'], detail_data_tables, config_element),
        config_element.optional('show_transactions') || false,
        config_element.optional('show_target_calculation') || false,
        config_element.optional('admin') || false)
  end

  # id: a string identifier
  # password: password string for the role. Pass 'nil' if no password is required (any given password
  #   will satisfy authentication in this case.)
  # summary_data_tables: UserDataTable instances describing those tables shown to the user in response
  #    to 'summary' queries.
  # detail_data_tables: As above, but for 'detail' queries.
  # allow_transactions: True if the expensive transaction queries are run for this role.
  # allow_target_calculation_display: True if the growth targets are displayed for users of this role.
  def initialize(id,
                 password,
                 summary_data_tables,
                 detail_data_tables,
                 allow_transactions,
                 allow_target_calculation_display,
                 admin)
    @id = id
    @password = password
    @summary_data_tables = summary_data_tables
    @detail_data_tables = detail_data_tables
    @allow_transactions = allow_transactions
    @allow_target_calculation_display = allow_target_calculation_display
    @admin = admin
  end

  def allow_transactions?
    @allow_transactions == true
  end

  def allow_target_calculation_display?
    @allow_target_calculation_display == true
  end

  # Returns true if the given password passes the role's authentication requirements.
  def password_authenticates?(password)
    @password.nil? || password == @password
  end

  def admin?
    @admin
  end

  protected
  def self.resolve_data_tables(table_id_elements, data_tables, config_element)
    if table_id_elements
      table_id_elements.value.collect do |table_id_element|
        table = data_tables[table_id_element.value]

        raise ConfigBadDataFormatException.new(config_element, "No such data table '#{table_id_element.value}'.)") if table.nil?

        table
      end
    else
      nil
    end
  end
end

# Describes an unauthenticated user.
class AppRoleUnauthenticated < AppRole
  def initialize
    super('unauthenticated', nil, nil, nil, false, false, nil)
  end

  def password_authenticates?(password)
    false
  end
end
