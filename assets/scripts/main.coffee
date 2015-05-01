Site =
  init: () ->
    @setLocalData(false)
    @documentTitle = document.title

    # Redirect without the query params if they existed
    if location.search
      document.location = location.origin + location.pathname

    # @setCalculatedVariables()
    # @attachVacationsDays()
    @getData()
    @attachAutoRefresh()

    return this


  setLocalData: (ignoreQueryParams=true) ->
    @apiKey = unless ignoreQueryParams then @getParameterByName('a') or localStorage.getItem('apiKey') else localStorage.getItem('apiKey')
    @workspaceId = unless ignoreQueryParams then @getParameterByName('s') or localStorage.getItem('workspaceId') else localStorage.getItem('workspaceId')
    @userId = unless ignoreQueryParams then @getParameterByName('u') or localStorage.getItem('userId') else localStorage.getItem('userId')

    if _.isNull(@apiKey)
      @apiKey = prompt('Enter your toggl auth token') + ''

    if _.isNull(@workspaceId)
      @workspaceId = prompt('Enter your toggl workspaceId') + ''

    if _.isNull(@userId)
      @userId = prompt('Enter your toggl userId') + ''

    localStorage.setItem('apiKey', @apiKey)
    localStorage.setItem('workspaceId', @workspaceId)
    localStorage.setItem('userId', @userId)

    # Elements
    @$content = $('#content')
    @$loader = $('.row.loading')

    # Dates
    @today = moment().hour(0).minute(0).second(0)
    @bom = moment(@today._d).date(1)
    @eom = moment(@today._d).date( @today.daysInMonth() )

    # Exception days
    @isTheFirst = @today.date() is @bom.date()
    @isTheLast = @today.date() is @eom.date()
    @isWeekday = @today.isWeekDay()
    @isHoliday = @today.holiday()

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
    # # Vacations
    # @isVacationDay = _.some _.filter @savedVacations, (vacation) =>
    #   if @holidaysByName[vacation]
    #     @holidaysByName[vacation].date.format('YYYYMMDD') is @today.format('YYYYMMDD')
    #   else
    #     false

    # @vacationDaysRemaining = _.size _.filter @savedVacations, (vacation) =>
    #   if @holidaysByName[vacation]
    #     @holidaysByName[vacation].date > @today
    #   else
    #     true

    # @vacationDaysSpent = _.size(@savedVacations) - @vacationDaysRemaining

    # @isWorkDay = @isWeekday and not @isVacationDay

    # @workDaysTotal = @bom.weekDays( @eom ) + 1
    # @workDaysWorked = @bom.weekDays( @today ) - @vacationDaysSpent
    # @workDaysLeft = @workDaysTotal - @workDaysWorked - @vacationDaysRemaining
    # @workDaysLeftTomorrow = if @isWorkDay then @workDaysLeft - 1 else @workDaysLeft
    return


  getData: ->
    qSince = @bom.format('YYYY-MM-DD')
    qUntil = @eom.format('YYYY-MM-DD')
    qToday = @today.format('YYYY-MM-DD')
    @detailsUrl = 'https://toggl.com/reports/api/v2/details?rounding=Off&status=active&user_ids=' + @userId + '&name=&billable=both&calculate=time&sortDirection=asc&sortBy=date&page=1&description=&since=' + qSince + '&until=' + qUntil + '&workspace_id=' + @workspaceId + '&period=thisMonth&with_total_currencies=1&grouping=&subgrouping=time_entries&order_field=date&order_desc=off&distinct_rates=Off&user_agent=Toggl+New+3.28.13&bars_count=31&subgrouping_ids=true&bookmark_token='
    @summaryUrl = 'https://toggl.com/reports/api/v2/summary.json?grouping=projects&subgrouping=time_entries&order_field=title&order_desc=off&rounding=Off&distinct_rates=Off&status=active&user_ids=' + @userId + '&name=&billable=both&workspace_id=' + @workspaceId + '&calculate=time&sortDirection=asc&sortBy=title&page=1&description=&since=' + qToday + '&until=' + qToday + '&period=today&with_total_currencies=1&user_agent=Toggl+New+3.28.13&bars_count=31&subgrouping_ids=true&bookmark_token='

    that = this
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
      alert('fail')
    )


  displayData: ->
    @addDebug()
    @toggleContent()

  toggleContent: (show=true) ->
    if show
      @$loader.addClass('fade')
      @$content.removeClass('fade')
    else
      @$loader.removeClass('fade')
      @$content.addClass('fade')

  attachVacationsDays: ->
    # _.each @holidays, (holiday) =>
    #   checkedAttr = if holiday.checked then ' checked' else ''
    #   @$holidays.find('form').append('
    #     <div class="checkbox">
    #       <label class="btn btn-default"><input' + checkedAttr + ' data-name="' + holiday.name + '" type="checkbox"/> ' + holiday.name +
    #         '&nbsp;&nbsp;<span>' + holiday.date.format('ddd, MMM Do') + '<span>
    #       </label>
    #     </div>')

    # @$holidays.find('input').on 'change', =>
    #   @storeVacationDays()
    #   @setCalculatedVariables()
    #   @displayData()

    # # Manually add/subtract vacation days
    # form = @$holidays.find('form')
    # $minusBtn = @$holidays.find('#minus_vacation_day')
    # $plusBtn = @$holidays.find('#plus_vacation_day')

    # addManualVacationInput = ->
    #   form.append($('<div class="hide checkbox">
    #   <input checked type="checkbox" data-name="' + moment().format('YYYYMMDDhhmmss') + '"/>
    #   </div>'))

    # # Find manually added vacations and add hidden inputs
    # manualVacations = _.filter @savedVacations, (vacation) -> /\d/.test(vacation)
    # _.each manualVacations, addManualVacationInput

    # $plusBtn.on 'click', (e) =>
    #   addManualVacationInput()
    #   $minusBtn.removeClass('hide')
    #   @storeVacationDays()
    #   @setCalculatedVariables()
    #   @displayData()

    # $minusBtn.on 'click', (e) =>
    #   $minusBtn.addClass('hide') unless form.find('.checkbox.hide').size() >= 2
    #   form.find('.checkbox.hide').first().remove()
    #   @storeVacationDays()
    #   @setCalculatedVariables()
    #   @displayData()

    # $minusBtn.addClass('hide') if form.find('.checkbox.hide').size() < 1


  storeVacationDays: ->
    # vacations = [];
    # @$holidays.find('input[type=checkbox]:checked').each ->
    #   $el = $(this)
    #   vacations.push($el.data('name'))

    # @savedVacations = vacations
    # localStorage.setItem('vacations', vacations.join(','))
    return


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

  addDebug: ->
    return unless location.host is 'localhost'
    console.log('%c DEBUG: Site -->', 'color:#F80', Site)
    @$debug = @$debug || $('body').append('<div id="debug" class="container">').find('#debug')
    _.each @, (item, key) =>
      unless _.isFunction(item)
        if _.isObject(item)
          console.log('%c DEBUG: ' + key + ' -->', 'color:#F80', item)
        else
          @$debug.append '<strong>' + key + ':</strong> ' + item + '<br>'


Site.init()