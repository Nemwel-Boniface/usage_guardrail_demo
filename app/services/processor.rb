class Processor
  def initialize(date = Date.today)
    @month = date.beginning_of_month
  end

  def call
    tracker = UsageTracker.find_by!(month: @month)

    tracker.with_lock do
      if tracker.locked || tracker.request_count + 1 > tracker.request_limit
        # attempt to persist the permanent kill switch, then stop
        tracker.update!(locked: true)
        raise BudgetExceededError
      end

      # increment the counter for a successful request
      tracker.increment!(:request_count)
    end
  end
end
