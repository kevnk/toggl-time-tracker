Site =
  init: () ->
    @setLocalData(false)

    # Redirect without the query params if they existed
    if location.search
      document.location = location.origin + location.pathname

    @documentTitle = document.title
    @displaySettings()
    @attachCopyLink()

    qSince = moment().date(1).format('YYYY-MM-DD')
    qUntil = moment().date(moment().daysInMonth()).format('YYYY-MM-DD')
    qToday = moment().format('YYYY-MM-DD')

    @detailsUrl = 'https://toggl.com/reports/api/v2/details?rounding=Off&status=active&user_ids=' + @userId + '&name=&billable=both&calculate=time&sortDirection=asc&sortBy=date&page=1&description=&since=' + qSince + '&until=' + qUntil + '&workspace_id=' + @workspaceId + '&period=thisMonth&with_total_currencies=1&grouping=&subgrouping=time_entries&order_field=date&order_desc=off&distinct_rates=Off&user_agent=Toggl+New+3.28.13&bars_count=31&subgrouping_ids=true&bookmark_token='
    @summaryUrl = 'https://toggl.com/reports/api/v2/summary.json?grouping=projects&subgrouping=time_entries&order_field=title&order_desc=off&rounding=Off&distinct_rates=Off&status=active&user_ids=' + @userId + '&name=&billable=both&workspace_id=' + @workspaceId + '&calculate=time&sortDirection=asc&sortBy=title&page=1&description=&since=' + qToday + '&until=' + qToday + '&period=today&with_total_currencies=1&user_agent=Toggl+New+3.28.13&bars_count=31&subgrouping_ids=true&bookmark_token='

    @getData()

    # Update every 15 minutes
    setInterval =>
      @getData()
    , 15 * 60 * 1000

  setLocalData: (ignoreQueryParams=true) ->
    @targetEarnings = unless ignoreQueryParams then @getParameterByName('e') or localStorage.getItem('earnings') else localStorage.getItem('earnings')
    @wage = unless ignoreQueryParams then @getParameterByName('w') or localStorage.getItem('wage') else localStorage.getItem('wage')
    @userId = unless ignoreQueryParams then @getParameterByName('u') or localStorage.getItem('userId') else localStorage.getItem('userId')
    @workspaceId = unless ignoreQueryParams then @getParameterByName('s') or localStorage.getItem('workspaceId') else localStorage.getItem('workspaceId')
    @apiKey = unless ignoreQueryParams then @getParameterByName('a') or localStorage.getItem('apiKey') else localStorage.getItem('apiKey')

    unless @targetEarnings > 0
      @targetEarnings = parseFloat(prompt('Enter your target earnings'), 10)

    unless @wage > 0
      @wage = parseFloat(prompt('Enter your hourly wage'), 10)

    if _.isNull(@apiKey)
      @apiKey = prompt('Enter your toggl auth token') + ''

    if _.isNull(@workspaceId)
      @workspaceId = prompt('Enter your toggl workspaceId') + ''

    if _.isNull(@userId)
      @userId = prompt('Enter your toggl userId') + ''

    localStorage.setItem('earnings', @targetEarnings)
    localStorage.setItem('wage', @wage)
    localStorage.setItem('userId', @userId)
    localStorage.setItem('workspaceId', @workspaceId)
    localStorage.setItem('apiKey', @apiKey)

    @targetHrs = @targetEarnings / @wage

  getData: ->
    that = this
    $('.loading').fadeIn('fast')
    $('.row.fade.in').removeClass('in')
    $.when(
      $.ajax({
        url: @detailsUrl
        beforeSend: (xhr) =>
          xhr.setRequestHeader 'Authorization', 'Basic ' + @apiKey
          xhr.setRequestHeader 'X-Requested-With', 'XMLHttpRequest'
        type: 'GET'
        dataType: 'json'
        contentType: 'application/json'
        success: (data) =>
          @details = data
      }),
      $.ajax({
        url: @summaryUrl
        beforeSend: (xhr) =>
          xhr.setRequestHeader 'Authorization', 'Basic ' + @apiKey
          xhr.setRequestHeader 'X-Requested-With', 'XMLHttpRequest'
        type: 'GET'
        dataType: 'json'
        contentType: 'application/json'
        success: (data) =>
          @summary = data
      })
    ).done( =>
      @displayData()
    ).fail( =>
      $('.loading').removeClass('loading').addClass('error').html '<h1><span class="label label-danger">Error! Wrong credentials!</span></h1>
        <a class="btn btn-default" href="reset/">Try reseting your variables</a>'
    )

  displayData: ->
    $total = $('.total-hours-display')
    $current = $('.current-avg-display')
    $target = $('.target-avg-display')
    $targetHrs = $('.target-hours-display')
    $targetToday = $('.target-today-display')
    $targetAvgToday = $('.target-avg-today-display')
    $clockOut = $('.clock-out-display')

    # TOTAL
    todaysHours = Math.round(@summary.total_grand / 1000 / 60 / 60 * 10) / 10
    totalHours = Math.round(@details.total_grand / 1000 / 60 / 60 * 10) / 10
    $total.html totalHours

    # CURRENT / yesterday's avg
    today = moment().hour(0)
    bom = moment().date(1)
    daysWorked = today.weekDays(bom)
    currentAvg = Math.round(totalHours / daysWorked * 10) / 10
    $current.html currentAvg

    # TARGET HOURS
    $targetHrs.html @targetHrs

    # TARGET AVG TOMOROW
    eom = moment().date today.daysInMonth()
    daysLeft = today.weekDays(eom)
    targetAvg = Math.round((@targetHrs - totalHours) / daysLeft * 10) / 10
    $target.html targetAvg

    # TARGET AVG TODAY
    daysLeftToday = daysLeft + 1
    targetAvgToday = Math.round((@targetHrs - totalHours + todaysHours) / daysLeftToday * 10) / 10
    $targetAvgToday.html targetAvgToday

    # TARGET TODAY
    targetToday = Math.round((targetAvgToday - todaysHours) * 10) / 10
    $targetToday.html targetToday

    # CLOCK OUT
    eod = moment().add(targetToday, 'h').format('h:mma')
    $clockOut.html eod

    # Show Stuff
    document.title = '(' + targetToday + ') ' + @documentTitle
    $('body').removeClass('show-menu')
    $('.loading').stop().fadeOut ->
      $('.row.fade').addClass('in')


  displaySettings: ->
    $form = $('.menu form')
    $inputs = $form.find('input')
    $saveBtn = $form.find('button')

    $earnings = $('#earnings').val @targetEarnings
    $wage = $('#wage').val @wage
    $userId = $('#userId').val @userId
    $workspaceId = $('#workspaceId').val @workspaceId
    $apiKey = $('#apiKey').val @apiKey

    $form.on 'submit', (e) =>
      e.preventDefault()

      localStorage.setItem('earnings', $earnings.val())
      localStorage.setItem('wage', $wage.val())
      localStorage.setItem('userId', $userId.val())
      localStorage.setItem('workspaceId', $workspaceId.val())
      localStorage.setItem('apiKey', $apiKey.val())

      @setLocalData()
      @displayData()

      return false

  attachCopyLink: ->
    $btn = $('.menu .btn-link')
    btn = new ZeroClipboard( $btn.get(0) )

    $btn.on 'mousedown', =>
      url = location.href
      url += '?e=' + @targetEarnings
      url += '&w=' + @wage
      url += '&u=' + @userId
      url += '&s=' + @workspaceId
      url += '&a=' + @apiKey
      $btn.attr('data-clipboard-text', url)

    btn.on 'ready', ->
      btn.on 'afterCopy', (event) ->
        msgs = [
          'Hip hip hooray!'
          'Woohoo!'
          'Fantabalistic!'
          'Ain\'t that special?!'
          '(successkid)!'
          '(rockon)!'
          '...like a boss!'
        ]
        $('#msg').html('Copied! ' + _.sample(msgs)).addClass('in')
        setTimeout ->
          $('#msg').removeClass('in')
        , 2000

  getParameterByName: (name) ->
    name = name.replace(/[\[]/, "\\[").replace(/[\]]/, "\\]")
    regex = new RegExp("[\\?&]" + name + "=([^&#]*)")
    results = regex.exec(location.search)
    if results is null then '' else decodeURIComponent(results[1].replace(/\+/g, " "))



Site.init()