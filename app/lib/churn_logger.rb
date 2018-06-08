require 'logger'

module ChurnLogger
  def log
    @log ||= ::Logger.new(STDOUT).tap do |log|
      log.level = ::Logger::INFO
    end
  end

  def error_log
    @error_log ||= ::Logger.new(STDERR).tap do |log|
      log.level = ::Logger::DEBUG
    end
  end
end
