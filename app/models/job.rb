class Job < ApplicationRecord
  after_create :schedule_active_job

  def schedule_active_job
    RunScheduledJob.set(wait: 10.seconds).perform_later(self)
  end
end
