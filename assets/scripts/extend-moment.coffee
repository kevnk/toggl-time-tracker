# @see https://github.com/jmeas/moment-business

# Extend Moment

nearestPeriodicValue = (point, value, period) ->
  value - period * Math.round((value - point) / period);

containedPeriodicValues = (start, end, value, period) ->
  # Inclusive start; exclusive end
  if start == end
    return 0
  # Flip our interval if it isn't ordered properly
  if start > end
    newEnd = start
    start = end
    end = newEnd
  # Make our interval have an exclusive end
  end--
  nearest = nearestPeriodicValue(start, value, period)
  # Ensure that the nearest value is in front of the start
  # of the interval
  if nearest - start < 0
    nearest += period
  # If we can't even reach the first value, then it is 0
  if nearest - start > end - start
    0
  else
    1 + parseInt((end - nearest) / period)

determineSign = (x) ->
  x = +x
  if x > 0 then 1 else -1

moment.fn.weekDays = (start) ->
  startDay = start.day()
  totalDays = Math.abs(@diff(start, 'days'))
  containedSundays = containedPeriodicValues(startDay, totalDays + startDay, 0, 7)
  containedSaturdays = containedPeriodicValues(startDay, totalDays + startDay, 6, 7)
  totalDays - (containedSaturdays + containedSundays)

moment.fn.weekendDays = (start) ->
  Math.abs(@diff(start, 'days')) - @weekDays(start)

moment.fn.addWeekDays = (count) ->
  if count == 0 or isNaN(count)
    return this
  sign = determineSign(count)
  day = @day()
  absIncrement = Math.abs(count)
  days = 0
  if day == 0 and sign == -1
    days = 1
  else if day == 6 and sign == 1
    days = 1
  # Add padding for weekends.
  paddedAbsIncrement = absIncrement
  if day != 0 and day != 6 and sign > 0
    paddedAbsIncrement += day
  else if day != 0 and day != 6 and sign < 0
    paddedAbsIncrement += 6 - day
  weekendsInbetween = Math.max(Math.floor(paddedAbsIncrement / 5) - 1, 0) + (if paddedAbsIncrement > 5 and paddedAbsIncrement % 5 > 0 then 1 else 0)
  # Add the increment and number of weekends.
  days += absIncrement + weekendsInbetween * 2
  @add sign * days, 'days'
  this

# The inverse of adding

moment.fn.subtractWeekDays = (count) ->
  @addWeekDays -count

# Returns a Boolean representing
# whether or not the moment is Mon-Fri

moment.fn.isWeekDay = ->
  @isoWeekday() < 6

# The inverse of the above method

moment.fn.isWeekendDay = ->
  @isoWeekday() > 5



