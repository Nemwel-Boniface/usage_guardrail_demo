## 6 — Reproduce the trap: the exact console steps to follow along

Open two terminals:

**Terminal A – Rails console**

```bash
rails console
```

**Terminal B – Watch development log**

```bash
tail -f log/development.log
# or
less +F log/development.log
```

Inside rails console, enable SQL logging to STDOUT (helpful for exact trace):

```ruby
ActiveRecord::Base.logger = Logger.new(STDOUT)
```

---

### Single-step demonstration (sequential, shows rollback)

```ruby
m = Date.today.beginning_of_month
tracker = UsageTracker.find_by!(month: m)

begin
  tracker.with_lock do
    if tracker.locked || tracker.request_count + 1 > tracker.request_limit
      tracker.update!(locked: true)
      raise BudgetExceededError
    end

    tracker.increment!(:request_count)
  end
rescue BudgetExceededError
  puts "Budget exceeded"
end

UsageTracker.find_by(month: m).attributes
```

---

### What to watch in development.log

You should capture and screenshot SQL lines like:

```
BEGIN
UPDATE "usage_trackers" SET "locked" = TRUE, "updated_at" = ... WHERE "usage_trackers"."id" = ...
ROLLBACK
```

Re-query shows `locked: false` despite the UPDATE line — that is the **“ghost update”** caused by raising the error inside the transaction block.

---

## Concurrent reproduction inside console (threads)

Paste this helper into the console to mimic parallel workers; it uses the connection pool correctly:

```ruby
def do_request(id, delay: 0.15)
  tracker = UsageTracker.find_by!(month: Date.today.beginning_of_month)

  tracker.with_lock do
    Rails.logger.info("JOB-#{id} inside TX=#{ActiveRecord::Base.connection.transaction_open?}")

    if tracker.locked || tracker.request_count + 1 > tracker.request_limit
      Rails.logger.info("JOB-#{id} update+raise")
      tracker.update!(locked: true)
      raise BudgetExceededError
    end

    sleep(delay) # force overlap so races occur
    tracker.increment!(:request_count)

    Rails.logger.info("JOB-#{id} incremented")
  end
rescue => e
  Rails.logger.info("JOB-#{id} err=#{e.class}")
end

threads = 8.times.map { |i| Thread.new { do_request(i) } }
threads.each(&:join)

UsageTracker.find_by(month: Date.today.beginning_of_month).attributes
```

---

### Expected concurrent result

Capture `development.log` during the run. Expect to see:

- at least one `UPDATE` followed directly by `ROLLBACK`
- final `UsageTracker` still showing `locked: false`  
  **or** `request_count` lower than the number of jobs you expected.

This proves why budget enforcement must raise errors **outside** the `with_lock` transaction to guarantee the locked state is actually persisted.

---