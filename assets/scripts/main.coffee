Site =
  init: () ->
    @setLocalData(false)
    @documentTitle = document.title

    # Redirect without the query params if they existed
    if location.search
      document.location = location.origin + location.pathname

    @setCalculatedVariables()
    @attachVacationsDays()
    @displaySettings()
    @attachCopyLink()
    @getData()
    @attachAutoRefresh()

    return this


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

    # Dates
    @today = moment().hour(0).minute(0).second(0)
    @bom = moment(@today._d).date(1)
    @eom = moment(@today._d).date( @today.daysInMonth() )
    @tomorrow = moment(@today._d).add(1, 'day')
    @nmBom = moment(@tomorrow._d).date(1)
    @nmEom = moment(@tomorrow._d).date( @tomorrow.daysInMonth() )

    # Exception days
    @isTheFirst = @today.date() is @bom.date()
    @isTheLast = @today.date() is @eom.date()
    @isWeekday = @today.isWeekDay()
    @isHoliday = @today.holiday()
    @nmIsWeekday = @tomorrow.isWeekDay()
    @nmIsHoliday = @tomorrow.holiday()

    @savedVacations = if localStorage.getItem('vacations') then localStorage.getItem('vacations').split(',') else []
    @holidays = [];
    @holidaysByName = {}
    moment().range(@bom._d, @eom._d).by 'days', (moment) =>
      return unless moment.isWeekDay()
      holiday = moment.holiday();
      unless _.isUndefined(holiday)
        holidayObj =
          name: holiday
          date: moment
          checked: _.contains( @savedVacations, holiday )

        @holidays.push holidayObj
        @holidaysByName[holiday] = holidayObj


  setCalculatedVariables: ->
    # Vacations
    @isVacationDay = _.some _.filter @savedVacations, (vacation) =>
      if @holidaysByName[vacation]
        @holidaysByName[vacation].date.format('YYYYMMDD') is @today.format('YYYYMMDD')
      else
        false

    @vacationDaysRemaining = _.size _.filter @savedVacations, (vacation) =>
      if @holidaysByName[vacation]
        @holidaysByName[vacation].date > @today
      else
        true

    @vacationDaysSpent = _.size(@savedVacations) - @vacationDaysRemaining

    @isWorkDay = @isWeekday and not @isVacationDay

    @workDaysTotal = @bom.weekDays( @eom ) + 1
    @workDaysWorked = @bom.weekDays( @today ) - @vacationDaysSpent
    @workDaysLeft = @workDaysTotal - @workDaysWorked - @vacationDaysRemaining
    @workDaysLeftTomorrow = if @isWorkDay then @workDaysLeft - 1 else @workDaysLeft

    # ----------------------------------------------------
    # For last day of the month, calculate everything for next month (nm)
    # ----------------------------------------------------
    @nmIsVacationDay = _.some _.filter @savedVacations, (vacation) =>
      if @holidaysByName[vacation]
        @holidaysByName[vacation].date.format('YYYYMMDD') is @tomorrow.format('YYYYMMDD')
      else
        false

    @nmIsWorkDay = @nmIsWeekday and not @nmIsVacationDay

    @nmWorkDaysTotal = @nmBom.weekDays( @nmEom ) + 1
    @nmWorkDaysWorked = 0
    @nmWorkDaysLeft = @nmWorkDaysTotal
    @nmWorkDaysLeftTomorrow = if @nmIsWorkDay then @nmWorkDaysLeft - 1 else @nmWorkDaysLeft


  getData: ->
    qSince = @bom.format('YYYY-MM-DD')
    qUntil = @eom.format('YYYY-MM-DD')
    qToday = @today.format('YYYY-MM-DD')
    @detailsUrl = 'https://toggl.com/reports/api/v2/details?rounding=Off&status=active&user_ids=' + @userId + '&name=&billable=both&calculate=time&sortDirection=asc&sortBy=date&page=1&description=&since=' + qSince + '&until=' + qUntil + '&workspace_id=' + @workspaceId + '&period=thisMonth&with_total_currencies=1&grouping=&subgrouping=time_entries&order_field=date&order_desc=off&distinct_rates=Off&user_agent=Toggl+New+3.28.13&bars_count=31&subgrouping_ids=true&bookmark_token='
    @summaryUrl = 'https://toggl.com/reports/api/v2/summary.json?grouping=projects&subgrouping=time_entries&order_field=title&order_desc=off&rounding=Off&distinct_rates=Off&status=active&user_ids=' + @userId + '&name=&billable=both&workspace_id=' + @workspaceId + '&calculate=time&sortDirection=asc&sortBy=title&page=1&description=&since=' + qToday + '&until=' + qToday + '&period=today&with_total_currencies=1&user_agent=Toggl+New+3.28.13&bars_count=31&subgrouping_ids=true&bookmark_token='

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
      # Set needed data
      @todaysHours = Math.round(@summary.total_grand / 1000 / 60 / 60 * 10) / 10
      @totalHours = Math.round(@details.total_grand / 1000 / 60 / 60 * 10) / 10
      # Display data
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
    $vacation = $('.vacation-days-display')

    # TOTAL
    $total.html @totalHours

    # CURRENT / avg as of yesterday
    currentAvg = if @isTheFirst then @totalHours else (@totalHours - @todaysHours) / @workDaysWorked
    currentAvg = Math.round(currentAvg * 10) / 10
    $current.html currentAvg

    # TARGET HOURS
    $targetHrs.html @targetHrs

    # TARGET AVG TOMOROW
    unless @isTheLast
      targetAvg = Math.round((@targetHrs - @totalHours) / @workDaysLeftTomorrow * 10) / 10
    else
      targetAvg = Math.round(@targetHrs / @nmWorkDaysLeftTomorrow * 10) / 10
    $target.html targetAvg

    # TARGET AVG TODAY
    unless @isTheFirst
      targetAvgToday = Math.round((@targetHrs - @totalHours + @todaysHours) / @workDaysLeft * 10) / 10
    else
      targetAvgToday = Math.round((@targetHrs - @todaysHours) / @workDaysLeft * 10) / 10
    $targetAvgToday.html targetAvgToday

    # TARGET TODAY
    targetToday = Math.round((targetAvgToday - @todaysHours) * 10) / 10
    $targetToday.html targetToday

    # CLOCK OUT
    eod = moment().add(targetToday, 'h').format('h:mma')
    $clockOut.html eod

    # Display the number of vacation days
    $vacation.html @vacationDaysRemaining

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

  attachVacationsDays: ->
    @$holidays = $('#holidays')

    _.each @holidays, (holiday) =>
      checkedAttr = if holiday.checked then ' checked' else ''
      @$holidays.find('form').append('
        <div class="checkbox">
          <label class="btn btn-default"><input' + checkedAttr + ' data-name="' + holiday.name + '" type="checkbox"/> ' + holiday.name +
            '&nbsp;&nbsp;<span>' + holiday.date.format('ddd, MMM Do') + '<span>
          </label>
        </div>')

    @$holidays.find('input').on 'change', =>
      @storeVacationDays()
      @setCalculatedVariables()
      @displayData()

    # Manually add/subtract vacation days
    form = @$holidays.find('form')
    $minusBtn = @$holidays.find('#minus_vacation_day')
    $plusBtn = @$holidays.find('#plus_vacation_day')

    addManualVacationInput = ->
      form.append($('<div class="hide checkbox">
      <input checked type="checkbox" data-name="' + moment().format('YYYYMMDDhhmmss') + '"/>
      </div>'))

    # Find manually added vacations and add hidden inputs
    manualVacations = _.filter @savedVacations, (vacation) -> /\d/.test(vacation)
    _.each manualVacations, addManualVacationInput

    $plusBtn.on 'click', (e) =>
      addManualVacationInput()
      $minusBtn.removeClass('hide')
      @storeVacationDays()
      @setCalculatedVariables()
      @displayData()

    $minusBtn.on 'click', (e) =>
      $minusBtn.addClass('hide') unless form.find('.checkbox.hide').size() >= 2
      form.find('.checkbox.hide').first().remove()
      @storeVacationDays()
      @setCalculatedVariables()
      @displayData()

    $minusBtn.addClass('hide') if form.find('.checkbox.hide').size() < 1


  storeVacationDays: ->
    vacations = [];
    @$holidays.find('input[type=checkbox]:checked').each ->
      $el = $(this)
      vacations.push($el.data('name'))

    @savedVacations = vacations
    localStorage.setItem('vacations', vacations.join(','))


  attachAutoRefresh: ->
    @autoUpdate = 0
    @autoTimer = moment()

    # Update every 2 minutes
    $(window).on 'blur', =>
      clearInterval @autoUpdate
      @autoUpdate = setInterval =>
        @getData()
      , 2 * 60 * 1000

    # If idle for more than 2 minutes, refresh on focus
    .on 'focus', =>
      clearInterval @autoUpdate
      if moment().diff(@autoTimer) > 2 * 60 * 1000
        @autoTimer = moment()
        @getData()


  getParameterByName: (name) ->
    name = name.replace(/[\[]/, "\\[").replace(/[\]]/, "\\]")
    regex = new RegExp("[\\?&]" + name + "=([^&#]*)")
    results = regex.exec(location.search)
    if results is null then '' else decodeURIComponent(results[1].replace(/\+/g, " "))



Site.init()