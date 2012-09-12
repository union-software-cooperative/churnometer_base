require './lib/query/query_summary'

class QuerySummaryGroupByEmployer < QuerySummary
protected
  def sql_final_select_outputs
    result = super

    result <<
      if @header1 == 'employerid'
<<-EOS	
		, e.lateness::text
		, e.payrollcontactdetail::text
		, e.paidto::date
		, e.paymenttype::text
EOS
      else
<<-EOS
		, ''::text lateness
		, ''::text payrollcontactdetail
		, null::date paidto
		, ''::text paymenttype
EOS
      end

    result
  end
end
