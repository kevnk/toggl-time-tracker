targetEarnings = parseFloat(localStorage.getItem('earnings'), 10)
wage = parseFloat(localStorage.getItem('wage'), 10)
apiKey = localStorage.getItem('apiKey')
workspaceId = localStorage.getItem('workspaceId')
userId = localStorage.getItem('userId')

unless _.isNumber(targetEarnings) && targetEarnings > 0
  targetEarnings = parseFloat(prompt('Enter your target earnings'), 10)
  localStorage.setItem('earnings', targetEarnings)

unless _.isNumber(wage) && wage > 0
  wage = parseFloat(prompt('Enter your hourly wage'), 10)
  localStorage.setItem('wage', wage)

if _.isNull(apiKey)
  apiKey = prompt('Enter your toggl api key') + ''
  localStorage.setItem('apiKey', apiKey)

if _.isNull(workspaceId)
  workspaceId = prompt('Enter your toggl workspaceId') + ''
  localStorage.setItem('workspaceId', workspaceId)

if _.isNull(userId)
  userId = prompt('Enter your toggl userId') + ''
  localStorage.setItem('userId', userId)

targetHrs = targetEarnings / wage


Site =
  init: () ->
    qSince = moment().date(1).format('YYYY-MM-DD')
    qUntil = moment().date(moment().daysInMonth()).format('YYYY-MM-DD')
    qToday = moment().format('YYYY-MM-DD')

    @detailsUrl = 'https://toggl.com/reports/api/v2/details?rounding=Off&status=active&user_ids=' + userId + '&name=&billable=both&calculate=time&sortDirection=asc&sortBy=date&page=1&description=&since=' + qSince + '&until=' + qUntil + '&workspace_id=' + workspaceId + '&period=thisMonth&with_total_currencies=1&grouping=&subgrouping=time_entries&order_field=date&order_desc=off&distinct_rates=Off&user_agent=Toggl+New+3.28.13&bars_count=31&subgrouping_ids=true&bookmark_token='
    @summaryUrl = 'https://toggl.com/reports/api/v2/summary.json?grouping=projects&subgrouping=time_entries&order_field=title&order_desc=off&rounding=Off&distinct_rates=Off&status=active&user_ids=' + userId + '&name=&billable=both&workspace_id=' + workspaceId + '&calculate=time&sortDirection=asc&sortBy=title&page=1&description=&since=' + qToday + '&until=' + qToday + '&period=today&with_total_currencies=1&user_agent=Toggl+New+3.28.13&bars_count=31&subgrouping_ids=true&bookmark_token='

    @getData()


  getData: ->
    that = this
    $.when(
      $.ajax({
        url: @detailsUrl
        beforeSend: (xhr) ->
          xhr.setRequestHeader 'Authorization', 'Basic ' + apiKey
          xhr.setRequestHeader 'X-Requested-With', 'XMLHttpRequest'
        type: 'GET'
        dataType: 'json'
        contentType: 'application/json'
        success: (data) =>
          @details = data
      }),
      $.ajax({
        url: @summaryUrl
        beforeSend: (xhr) ->
          xhr.setRequestHeader 'Authorization', 'Basic ' + apiKey
          xhr.setRequestHeader 'X-Requested-With', 'XMLHttpRequest'
        type: 'GET'
        dataType: 'json'
        contentType: 'application/json'
        success: (data) =>
          @summary = data
      })
    ).done =>
      @displayData()

  displayData: ->
    $total = $('.total-hours-display')
    $current = $('.current-avg-display')
    $target = $('.target-avg-display')
    $targetHrs = $('.target-hours-display')
    $targetToday = $('.target-today-display')
    $clockOut = $('.clock-out-display')

    # TOTAL
    totalHours = Math.round(@details.total_grand / 1000 / 60 / 60 * 10) / 10
    $total.html totalHours

    # CURRENT / yesterday's avg
    today = moment().hour(23)
    bom = moment().date(1)
    daysWorked = today.weekDays(bom)
    currentAvg = Math.round(totalHours / daysWorked * 10) / 10
    $current.html currentAvg

    # TARGET AVG
    eom = moment().date today.daysInMonth()
    daysLeft = today.weekDays(eom)
    targetAvg = Math.round((targetHrs - totalHours) / daysLeft * 10) / 10
    $target.html targetAvg

    # TARGET HOURS
    $targetHrs.html targetHrs

    # TARGET TODAY
    todaysHours = Math.round(@summary.total_grand / 1000 / 60 / 60 * 10) / 10
    targetToday = Math.round((targetAvg - todaysHours) * 10) / 10
    $targetToday.html targetToday

    # CLOCK OUT
    eod = moment().add(targetToday, 'h').format('h:mma')
    $clockOut.html eod



Site.init()