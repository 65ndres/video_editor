class RunScheduledJob < ApplicationJob
  queue_as :default

  def perform(*args)
    job         = args.first
    class_name  = job.class_name
    action_name = job.action_name

    clazz = class_name.constantize.
    clazz.send(action_name, job)    
  end
end