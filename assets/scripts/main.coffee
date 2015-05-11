Site =
  init: () ->
    @setLocalData(false)
    @documentTitle = document.title

    # Redirect without the query params if they existed
    if location.search
      document.location = location.origin + location.pathname

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

    @lastTargetHours = localStorage.getItem('lastTargetHours') || 140


  calculateVariables: ->
    @todaysHours = Math.round(@summary.total_grand / 1000 / 60 / 60 * 10) / 10
    @totalHours = Math.round(@details.total_grand / 1000 / 60 / 60 * 10) / 10

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

    @isWorkDay = @isWeekday # and not @isVacationDay

    @workDaysTotal = @bom.weekDays( @eom )
    @workDaysWorked = @bom.weekDays( @today ) # - @vacationDaysSpent
    @workDaysWorked-- if @isWorkDay
    @workDaysLeft = @workDaysTotal - @workDaysWorked # - @vacationDaysRemaining
    # @workDaysLeftTomorrow = if @isWorkDay then @workDaysLeft - 1 else @workDaysLeft

    @todayAvg = Math.round( @totalHours / @workDaysWorked * 100 ) / 100
    @yesterdayAvg = @todayAvg
    if @isWorkDay
      @yesterdayAvg = Math.round( (@totalHours - @todaysHours) / (@workDaysWorked - 1) * 100 ) / 100

    @avgPercentageChange = Math.round( (@todayAvg - @yesterdayAvg) / @yesterdayAvg * 100 ) / 100

    @targetHours = @targetHours || @lastTargetHours
    @targetAvg = Math.round( @targetHours / @workDaysTotal * 100 ) / 100

    @hoursTodayToTargetAvg = Math.round( ((@targetAvg * @workDaysWorked) - @totalHours) * 100 ) / 100
    @totalHoursTodayToTargetAvg = Math.round( (@hoursTodayToTargetAvg + @todaysHours) * 100 ) / 100
    @percentageTodayToTargetAvg = Math.round( @todaysHours / @totalHoursTodayToTargetAvg * 100 )

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
      @calculateVariables()
      # Display data
      @displayData()
    ).fail( =>
      alert('fail')
    )


  displayData: ->
    @slides = []
    @addTargetSlide()

    @addSlidesToContent()
    @addSlickCarousel()
    @recalculateValues()
    @addDebug()
    @toggleContent()


  addTargetSlide: ->
    slide = $('<div id="target_slide"/>')

    label = $('<label for=target_hours>Target Hours for ' + moment().format('MMMM') + ': </label>')
      .append('<span data-targetHours>')
    range = $('<input type=range id=target_hours min=100 value=' + @targetHours + ' max=200 step=1>')
    range.on 'input', =>
      @targetHours = range.val()
      @recalculateValues()


    slideOuter = $('<div/>')
      .append('<strong data-targetAvg>')
      .append('<span>target avg</span>')
    slideInner = $('<div data-percentageTodayToTargetAvg=width>')
      .append('<strong data-hoursTodayToTargetAvg>')
      .append('<span>hours left</span>')
    slide.append(slideOuter.append(slideInner))

    slide.append label
    slide.append range

    @slides.push slide


  addSlidesToContent: ->
    @$content.html('<div id="slides"/><div id="pager"/>')
    _.each @slides, (slide, i) =>
      slideWrapper = $('<div id="slide-' + i + '"/>')
      slideWrapper.append(slide)
      @$content.find('#slides').append(slideWrapper)


  addSlickCarousel: ->
    @lastSlickIndex = localStorage.getItem('lastSlickIndex') || 0
    @$slides = $('#slides').slick({
      dots: true,
      speed: 500,
      slidesToShow: 1,
      slidesToScroll: 1,
      infinite: true
    }).slick('slickGoTo', @lastSlickIndex, true)
    @$slides.on 'afterChange', (event, slick, currentSlide) ->
      localStorage.setItem('lastSlickIndex', currentSlide)


  toggleContent: (show=true) ->
    if show
      @$loader.addClass('fade')
      @$content.removeClass('fade')
    else
      @$loader.removeClass('fade')
      @$content.addClass('fade')


  recalculateValues: ->
    @lastTargetHours = @targetHours
    localStorage.setItem('lastTargetHours', @lastTargetHours)

    # RECALCULATE
    @calculateVariables()

    boundVariables = [
      'percentageTodayToTargetAvg'
      'hoursTodayToTargetAvg'
      'totalHoursTodayToTargetAvg'
      'targetHours'
      'targetAvg'
    ]

    _.each boundVariables, (variable) =>
      $('[data-' + variable + ']').each (i, el) =>
        $el = $(el)
        method = $el.attr('data-' + variable) || 'html'
        if $el[method] and @[variable]
          val = @[variable]
          val += '%' if method is 'width'
          $el[method] val


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
    #   @calculateVariables()
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
    #   @calculateVariables()
    #   @displayData()

    # $minusBtn.on 'click', (e) =>
    #   $minusBtn.addClass('hide') unless form.find('.checkbox.hide').size() >= 2
    #   form.find('.checkbox.hide').first().remove()
    #   @storeVacationDays()
    #   @calculateVariables()
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
    @$debug = @$debug || $('body').append('<div id="debug" class="container">').find('#debug')

    @$debug.html('')

    console.log('%c DEBUG: Site -->', 'color:#F80', Site)
    _.each @, (item, key) =>
      unless _.isFunction(item)
        if _.isObject(item)
          if item._isAMomentObject
            # console.log('%c DEBUG: ' + key + ' -->', 'color:#F80', item)
            @$debug.append '<strong>' + key + ' (Moment):</strong> ' + item.format('MM/DD/YYYY hh:mm:ssa') + '<br>'
          else
            console.log('%c DEBUG: ' + key + ' -->', 'color:#F80', item)
        else
          @$debug.append '<strong>' + key + ':</strong> ' + item + '<br>'


Site.init()