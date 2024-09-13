class Job < ApplicationRecord
  after_create :schedule_active_job

  def schedule_active_job
    RunScheduledJob.set(wait: 1.minute).perform_later(self)
  end
end
