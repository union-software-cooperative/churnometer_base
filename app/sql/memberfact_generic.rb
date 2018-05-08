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

src_db = 'churnometer_regression'
dst_db = 'churnometer_regression_general'
fact_table = 'memberfact'
delta_fact_table = 'memberfacthelper5'
displaytext_table = 'displaytext'
user = 'churnuser'
pass = 'fcchurnpass'

ENV['PGPASSWORD'] = pass

admin_user = `whoami`.chomp
churnuser_params = "-h localhost -U #{user}"
dst_db_params = "#{churnuser_params} -d #{dst_db}"

def shell(cmd, echo=true)
  puts cmd
  result = `#{cmd}`
  raise "Command failed." if $? != 0
  puts result if echo
  result
end

def dbshell_pipe(cmd, str)
  cmd = "psql #{$dst_db_params} #{cmd}"
  puts cmd
  result = IO.popen(cmd, 'w+') do |io|
    io.write str
    io.close_write
    io.read
  end

  puts result
  raise "Command failed." if $? != 0
  result
end

shell("psql -U #{admin_user} -c 'drop database if exists #{dst_db};'")

shell("psql -U #{admin_user} -c 'create database churnometer_regression_general;'")

dump = shell("pg_dump #{churnuser_params} #{src_db}", false)
dbshell_pipe("#{churnuser_params} -d #{dst_db} -f -", dump)

=begin
keep columns:

changeid
memberid
changedate
net
gain
loss
status
_status
statusdelta
payinggain
payingloss
a1pgain
a1ploss
stoppedgain
stoppedloss
othergain
otherloss
duration
_changeid
_changedate
=end

change_columns = [
'branchid',
'industryid',
'lead',
'org',
'areaid',
'companyid',
'agreementexpiry',
'del',
'hsr',
'gender',
'feegroupid',
'state',
'nuwelectorate',
'statusstaffid',
'supportstaffid',
'employerid',
'hostemployerid',
'employmenttypeid',
'paymenttypeid',
]

i = 0

colname_to_index = {}
colname_to_newname = {}

change_columns.each do |col|
  index = i
  colname_to_index[col] = i
  i += 1

  new_col_name = "col#{index}"

  colname_to_newname[col] = new_col_name
  colname_to_newname["#{col}delta"] = new_col_name

  shell("psql #{dst_db_params} -c 'alter table #{delta_fact_table} rename #{col} to #{new_col_name};'")
  shell("psql #{dst_db_params} -c 'alter table #{delta_fact_table} rename #{col}delta to #{new_col_name}delta;'")
end

puts "#{delta_fact_table}"
puts colname_to_newname

colname_to_newname = {}

change_columns.each do |col|
  index = colname_to_index[col]

  new_col_name = "col#{index}"

  colname_to_newname["old#{col}"] = "old#{new_col_name}"
  colname_to_newname["new#{col}"] = "new#{new_col_name}"

  shell("psql #{dst_db_params} -c 'alter table #{fact_table} rename old#{col} to old#{new_col_name};'")
  shell("psql #{dst_db_params} -c 'alter table #{fact_table} rename new#{col} to new#{new_col_name};'")
end

puts "#{fact_table}"
puts colname_to_newname

change_columns.each do |col|
  index = colname_to_index[col]

  new_col_name = "col#{index}"

  shell("psql #{dst_db_params} -c \"update #{displaytext_table} set attribute = '#{new_col_name}' where attribute = '#{col}';\"")
end

puts "dimstart"
puts colname_to_newname

change_columns.each do |col|
  index = colname_to_index[col]

  new_col_name = "col#{index}"

  shell("psql #{dst_db_params} -c \"update dimstart set dimension = '#{new_col_name}' where dimension = '#{col}';\"")
end
