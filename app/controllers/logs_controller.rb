class LogsController < ApplicationController
  def index
    @logs = Log.includes(:picture).order(posted_at: :desc)
  end
end
