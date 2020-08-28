require './lib/churn_presenters/helpers.rb'
require './lib/settings.rb'

class ChurnPresenter_Notices
  include Settings
  include ChurnPresenter_Helpers

  attr_accessor :notices

  def initialize(app, request)
    start_date = Date.parse(request.params['startDate'])
    end_date = Date.parse(request.params['endDate'])

    @notices = if File.exist?(notices_filename)
      YAML.load(File.read(notices_filename)).map do |h|
        ChurnPresenter_Notice.new(h, start_date, end_date)
      end
    else
      {}
    end
  end

  def for_display
    @notices.select(&:display)
  end

  def notices_filename
    @notices_filename ||= "./config/notices.yaml"
  end
end

class ChurnPresenter_Notice
  attr_reader :display, :date, :message

  def initialize(notice, start_date, end_date)
    @date = Date.parse(notice["date"])

    @display = (@date >= start_date && @date <= end_date)
    @message = notice["message"]
  end
end
