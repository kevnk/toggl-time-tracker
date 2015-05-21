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

    @lastTargetHours = localStorage.getItem('lastTargetHours') || 140
    @lastDaysOff = localStorage.getItem('lastDaysOff') || 0
    @lastTakenDaysOff = localStorage.getItem('lastTakenDaysOff') || 0


  calculateVariables: ->
    @isWorkDay = @isWeekday

    @daysOff = @daysOff || @lastDaysOff
    @takenDaysOff = @takenDaysOff || @lastTakenDaysOff

    @totalWeekDays = @bom.weekDays( @eom )
    @weekDaysToToday = @bom.weekDays( @today )
    @weekDaysToEom = @eom.weekDays( @today )


    @workDaysTotal = @totalWeekDays - @daysOff
    @workDaysWorkedToday = @weekDaysToToday - @takenDaysOff # Includes today
    @workDaysWorked = if @isWorkDay then @workDaysWorkedToday - 1 else @workDaysWorkedToday

    @workDaysLeft = @weekDaysToEom - @daysOff

    @todayAvg = @round (@totalHours / @workDaysWorkedToday)
    @yesterdayAvg = @todayAvg
    if @todaysHours
      @yesterdayAvg = @round ((@totalHours - @todaysHours) / (@workDaysWorked))

    @avgPercentageChange = @round ((@todayAvg - @yesterdayAvg) / @yesterdayAvg), true

    @targetHours = @targetHours || @lastTargetHours
    @targetAvg = @round (@targetHours / @workDaysTotal)

    @hoursTodayToTargetAvg = @round ((@targetAvg * @workDaysWorked) - @totalHours)
    # @hoursTodayToTargetAvg = '✓' if @hoursTodayToTargetAvg <= 0

    @totalHoursTodayToTargetAvg = @round (@hoursTodayToTargetAvg + @todaysHours)
    @percentageTodayToTargetAvg = @round (@todaysHours / @totalHoursTodayToTargetAvg), true

    @totalHoursLeftToEomTarget = @round (@targetHours - @totalHours)
    @avgTodayToEomTarget = @round (@totalHoursLeftToEomTarget / @workDaysLeft)
    @hoursTodayToEomTargetAvg = @round (@avgTodayToEomTarget - @todaysHours)
    @percentageTodayToEomTargetAvg = @round (@todaysHours / @avgTodayToEomTarget), true

    # @avgTodayToEomTarget = '✓' if @todayAvg > @targetAvg
    # @hoursTodayToEomTargetAvg = '✓' if @todayAvg > @targetAvg
    # @percentageTodayToEomTargetAvg = 100 if @todayAvg > @targetAvg

    @percentageTodayAvg = @round (@todayAvg / @targetAvg), true


    return

  round: (val, isPercent = false) ->
    result = Math.round( val * 100 )
    result = result / 100 unless isPercent
    result

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
    @createTargetTodaySlide()
    @createTargetEomSlide()

    @addSlidesToContent()
    @addSlickCarousel()
    @addStats()
    @addAdjustersToContent()
    @recalculateValues()
    @addDebug()
    @toggleContent()


  # hours to hit target today
  # avg to hit target by eom


  createTargetTodaySlide: ->
    $slide = $('<div class="hoursTodayToTargetAvg_slide"/>')
    $slide.append $('<h1>Hit Target Avg Today</h1>')

    $hoursToTarget = $('<div data-percentageTodayToTargetAvg="width">')
    $hoursToTarget.append $('<h3><span data-hoursTodayToTargetAvg/> <small>Hours Left Today</small></h3>')
    $outer = $('<div class="outer">').append $hoursToTarget

    $slide.append $outer

    @slides.push $slide


  createTargetEomSlide: ->
    $slide = $('<div class="hoursTodayToEomTargetAvg_slide"/>')
    $slide.append $('<h1>Hit Target Avg By End of Month</h1>')

    $hoursToTarget = $('<div data-percentageTodayToEomTargetAvg="width">')
    $hoursToTarget.append $('<h3><span data-hoursTodayToEomTargetAvg/> <small>Hours Left Today</small></h3>')
    $outer = $('<div class="outer">').append $hoursToTarget

    $slide.append $outer

    @slides.push $slide


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
      arrows: false,
      slidesToShow: 1,
      slidesToScroll: 1,
      infinite: true
    }).slick('slickGoTo', @lastSlickIndex, true)
    @$slides.on 'afterChange', (event, slick, currentSlide) ->
      localStorage.setItem('lastSlickIndex', currentSlide)


  addStats: ->
    $stats = $('<div id="stats">')

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

    # current avg
    $todayAvg = $('<div>')
    $todayAvg.append $('<h3 data-todayAvg>')
    $todayAvg.append $('<small>Current Avg</small>')
    $stats.append $todayAvg

    # current avg
    $avgTodayToEomTarget = $('<div>')
    $avgTodayToEomTarget.append $('<h3 data-avgTodayToEomTarget>')
    $avgTodayToEomTarget.append $('<small>Avg To EOM Target</small>')
    $stats.append $avgTodayToEomTarget

    # % change from yesterday's avg
    # $changeInAvg = $('<div>')
    # $changeInAvg.append $('<h3 data-avgPercentageChange>')
    # $changeInAvg.append $('<small>Avg % Change From Yesterday</small>')
    # $stats.append $changeInAvg

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

    labelTargetHours = $('<label for=targetHours_adjuster>Target Hours for ' + moment().format('MMMM') + ': </label>')
      .append('<span data-targetHours>')
    rangeTargetHours = $('<input type=range id=targetHours_adjuster min=100 value=' + @targetHours + ' max=200 step=1>')
    rangeTargetHours.on 'input', =>
      @targetHours = rangeTargetHours.val()
      @recalculateValues()

    $adjusters.append $('<div>').append(labelTargetHours).append(rangeTargetHours)


    labelDaysOff = $('<label for=daysOff_adjuster>Remaining Days Off: </label>')
      .append('<span data-daysOff>')
    rangeDaysOff = $('<input type=range id=daysOff_adjuster min=0 value=' + @daysOff + ' max=15 step=1>')
    rangeDaysOff.on 'input', =>
      @daysOff = rangeDaysOff.val()
      @recalculateValues()

    $adjusters.append $('<div>').append(labelDaysOff).append(rangeDaysOff)


    labelTakenDaysOff = $('<label for=takenDaysOff_adjuster>Used Days Off: </label>')
      .append('<span data-takenDaysOff>')
    rangeTakenDaysOff = $('<input type=range id=takenDaysOff_adjuster min=0 value=' + @takenDaysOff + ' max=15 step=1>')
    rangeTakenDaysOff.on 'input', =>
      @takenDaysOff = rangeTakenDaysOff.val()
      @recalculateValues()

    $adjusters.append $('<div>').append(labelTakenDaysOff).append(rangeTakenDaysOff)


    @$content.append $adjusters

  toggleContent: (show=true) ->
    if show
      @$loader.removeClass('in')
      @$content.addClass('in')
    else
      @$loader.addClass('in')
      @$content.removeClass('in')


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
      'hoursTodayToEomTargetAvg'
      'percentageTodayToEomTargetAvg'
      'avgTodayToEomTarget'
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
          addPercent = method is 'width' || _.contains(['avgPercentageChange', 'percentageTodayToTargetAvg'], variable)
          val += '%' if addPercent

          # Set it
          if method is 'html'
            $el.html val
          else
            css = {}
            val = '100%' if parseFloat(val, 10) > 100
            css[method] = val
            $el.css css


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