class Job < ApplicationRecord
  after_create :schedule_active_job

  def schedule_active_job
    RunSchduledJob.perform_now(self)
  end
end
