class Processor
  def initialize(date = Date.today)
    @month = date.beginning_of_month
  end

  def call
    tracker = UsageTracker.find_by!(month: @month)
    exceeded = false

    tracker.with_lock do
      if tracker.locked || tracker.request_count + 1 > tracker.request_limit
        # persist the lock inside the transaction
        tracker.update!(locked: true)
        exceeded = true
      else
        tracker.increment!(:request_count)
      end
    end

    # raise AFTER the transaction commits
    raise BudgetExceededError if exceeded
  end
end
