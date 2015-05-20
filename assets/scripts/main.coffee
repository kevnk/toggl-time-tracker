window.Site =
  init: () ->
    @setLocalData(false)
    @documentTitle = document.title

    # Redirect without the query params if they existed
    if location.search
      document.location = location.origin + location.pathname

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
    @lastDaysOff = localStorage.getItem('lastDaysOff') || 0
    @lastTakenDaysOff = localStorage.getItem('lastTakenDaysOff') || 0


  calculateVariables: ->
    @isWorkDay = @isWeekday

    @daysOff = @daysOff || @lastDaysOff
    @takenDaysOff = @takenDaysOff || @lastTakenDaysOff
    @workDaysTotal = @bom.weekDays( @eom ) - @daysOff
    @workDaysWorked = @bom.weekDays( @today ) - 2 - @takenDaysOff
    @workDaysWorked++ if @isWorkDay
    @workDaysLeft = @workDaysTotal - @workDaysWorked

    @todayAvg = Math.round( @totalHours / @workDaysWorked * 100 ) / 100
    @yesterdayAvg = @todayAvg
    if @isWorkDay
      @yesterdayAvg = Math.round( (@totalHours - @todaysHours) / (@workDaysWorked - 1) * 100 ) / 100

    @avgPercentageChange = Math.round( (@todayAvg - @yesterdayAvg) / @yesterdayAvg * 100 )

    @targetHours = @targetHours || @lastTargetHours
    @targetAvg = Math.round( @targetHours / @workDaysTotal * 100 ) / 100

    @hoursTodayToTargetAvg = Math.round( ((@targetAvg * @workDaysWorked) - @totalHours) * 100 ) / 100
    @totalHoursTodayToTargetAvg = Math.round( (@hoursTodayToTargetAvg + @todaysHours) * 100 ) / 100
    @percentageTodayToTargetAvg = Math.round( @todaysHours / @totalHoursTodayToTargetAvg * 100 )

    @percentageTodayAvg = Math.round( @todayAvg / @targetAvg * 100 )



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

      @calculateVariables()
      # Display data
      @displayData()
    ).fail( =>
      alert('fail')
    )


  displayData: ->
    @slides = []
    @createTargetSlide()

    @addSlidesToContent()
    @addSlickCarousel()
    @addStats()
    @addAdjustersToContent()
    @recalculateValues()
    @addDebug()
    @toggleContent()


  # hours to hit target today
  # avg to hit target by eom


  createTargetSlide: ->
    slide = $('<div id="target_slide"/>')

    @slides.push slide

  createTargetSlide2: ->
    slide = $('<div id="target_slide"/>')

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


  addStats: ->
    $stats = $('<div id="stats">')

    # current avg
    $todayAvg = $('<div>')
    $todayAvg.append $('<h3 data-todayAvg>')
    $todayAvg.append $('<small>Current Avg</small>')
    $stats.append $todayAvg

    # % change from yesterday's avg
    $changeInAvg = $('<div>')
    $changeInAvg.append $('<h3 data-avgPercentageChange>')
    $changeInAvg.append $('<small>Avg % Change</small>')
    $stats.append $changeInAvg

    # todays hours logged
    $todaysHours = $('<div>')
    $todaysHours.append $('<h3 data-todaysHours>')
    $todaysHours.append $('<small>Today\'s Hours</small>')
    $stats.append $todaysHours

    # total hours logged
    $totalHours = $('<div>')
    $totalHours.append $('<h3 data-totalHours>')
    $totalHours.append $('<small>' + moment().format('MMMM') + ' Hours</small>')
    $stats.append $totalHours

    # Days worked
    $workDaysWorked = $('<div>')
    $workDaysWorked.append $('<h3 data-workDaysWorked>')
    $workDaysWorked.append $('<small>Days Worked</small>')
    $stats.append $workDaysWorked

    # Days left
    $workDaysLeft = $('<div>')
    $workDaysLeft.append $('<h3 data-workDaysLeft>')
    $workDaysLeft.append $('<small>Work Days Left</small>')
    $stats.append $workDaysLeft

    @$content.append $stats



  addAdjustersToContent: ->
    $adjusters = $('<div id="adjusters">')

    labelTargetHours = $('<label for=target_hours>Target Hours for ' + moment().format('MMMM') + ': </label>')
      .append('<span data-targetHours>')
    rangeTargetHours = $('<input type=range id=target_hours min=100 value=' + @targetHours + ' max=200 step=1>')
    rangeTargetHours.on 'input', =>
      @targetHours = rangeTargetHours.val()
      @recalculateValues()

    $adjusters.append $('<div>').append(labelTargetHours).append(rangeTargetHours)


    labelDaysOff = $('<label for=days_off>Remaining Days Off: </label>')
      .append('<span data-daysOff>')
    rangeDaysOff = $('<input type=range id=days_off min=0 value=' + @daysOff + ' max=15 step=1>')
    rangeDaysOff.on 'input', =>
      @daysOff = rangeDaysOff.val()
      @recalculateValues()

    $adjusters.append $('<div>').append(labelDaysOff).append(rangeDaysOff)


    labelTakenDaysOff = $('<label for=taken_days_off>Used Days Off: </label>')
      .append('<span data-takenDaysOff>')
    rangeTakenDaysOff = $('<input type=range id=taken_days_off min=0 value=' + @takenDaysOff + ' max=15 step=1>')
    rangeTakenDaysOff.on 'input', =>
      @takenDaysOff = rangeTakenDaysOff.val()
      @recalculateValues()

    $adjusters.append $('<div>').append(labelTakenDaysOff).append(rangeTakenDaysOff)


    @$content.append $adjusters

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

    @lastDaysOff = @daysOff
    localStorage.setItem('lastDaysOff', @lastDaysOff)

    @lastTakenDaysOff = @takenDaysOff
    localStorage.setItem('lastTakenDaysOff', @lastTakenDaysOff)

    # RECALCULATE
    @calculateVariables()
    @addDebug()

    boundVariables = [
      'percentageTodayToTargetAvg'
      'hoursTodayToTargetAvg'
      'totalHoursTodayToTargetAvg'
      'targetHours'
      'totalHours'
      'todaysHours'
      'targetAvg'
      'todayAvg'
      'percentageTodayAvg'
      'avgPercentageChange'
      'daysOff'
      'takenDaysOff'
      'workDaysWorked'
      'workDaysLeft'
    ]

    _.each boundVariables, (variable) =>
      $('[data-' + variable + ']').each (i, el) =>
        $el = $(el)
        method = $el.attr('data-' + variable) || 'html'
        unless _.isUndefined($el[method]) or _.isUndefined(@[variable])
          val = @[variable]
          # add negative class
          addNegClass = variable is 'avgPercentageChange' and val < 0
          if addNegClass
            $el.addClass('neg')
          else
            $el.removeClass('neg')
          # add positive class
          addPosClass = variable is 'avgPercentageChange' and val > 0
          if addPosClass
            $el.addClass('pos')
          else
            $el.removeClass('pos')
          # add percent sign
          addPercent = method is 'width' || _.contains(['avgPercentageChange'], variable)
          val += '%' if addPercent
          $el[method] val


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
    # console.clear() if @$debug
    console.log('%c ===========================================================', 'color:red')
    console.log('%c ===========================================================', 'color:red')
    @$debug = @$debug || $('body').append('<pre id="debug" class="container"><table><tbody/></table></pre>').find('#debug tbody')
    @$debug.html('')

    console.log('%c DEBUG: Site -->', 'color:#F80', Site)
    _.each @, (item, key) =>
      unless _.isFunction(item)
        if _.isObject(item)
          if item._isAMomentObject
            # console.log('%c DEBUG: ' + key + ' -->', 'color:#F80', item)
            @$debug.append '<tr><th>' + key + ' (Moment):</th><td>' + item.format('MM/DD/YYYY hh:mm:ssa') + '</td></tr>'
          else
            console.log('%c DEBUG: ' + key + ' -->', 'color:#F80', item)
        else
          @$debug.append '<tr><th>' + key + ':</th><td>' + item + '</td></tr>'


Site.init()