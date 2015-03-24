// Generated by CoffeeScript 1.7.1
(function() {
  var Site;

  Site = {
    init: function() {
      var qSince, qToday, qUntil;
      this.setLocalData(false);
      if (location.search) {
        document.location = location.origin + location.pathname;
      }
      this.documentTitle = document.title;
      this.displaySettings();
      this.attachCopyLink();
      qSince = moment().date(1).format('YYYY-MM-DD');
      qUntil = moment().date(moment().daysInMonth()).format('YYYY-MM-DD');
      qToday = moment().format('YYYY-MM-DD');
      this.detailsUrl = 'https://toggl.com/reports/api/v2/details?rounding=Off&status=active&user_ids=' + this.userId + '&name=&billable=both&calculate=time&sortDirection=asc&sortBy=date&page=1&description=&since=' + qSince + '&until=' + qUntil + '&workspace_id=' + this.workspaceId + '&period=thisMonth&with_total_currencies=1&grouping=&subgrouping=time_entries&order_field=date&order_desc=off&distinct_rates=Off&user_agent=Toggl+New+3.28.13&bars_count=31&subgrouping_ids=true&bookmark_token=';
      this.summaryUrl = 'https://toggl.com/reports/api/v2/summary.json?grouping=projects&subgrouping=time_entries&order_field=title&order_desc=off&rounding=Off&distinct_rates=Off&status=active&user_ids=' + this.userId + '&name=&billable=both&workspace_id=' + this.workspaceId + '&calculate=time&sortDirection=asc&sortBy=title&page=1&description=&since=' + qToday + '&until=' + qToday + '&period=today&with_total_currencies=1&user_agent=Toggl+New+3.28.13&bars_count=31&subgrouping_ids=true&bookmark_token=';
      this.getData();
      this.attachAutoRefresh();
      return this;
    },
    setLocalData: function(ignoreQueryParams) {
      if (ignoreQueryParams == null) {
        ignoreQueryParams = true;
      }
      this.targetEarnings = !ignoreQueryParams ? this.getParameterByName('e') || localStorage.getItem('earnings') : localStorage.getItem('earnings');
      this.wage = !ignoreQueryParams ? this.getParameterByName('w') || localStorage.getItem('wage') : localStorage.getItem('wage');
      this.userId = !ignoreQueryParams ? this.getParameterByName('u') || localStorage.getItem('userId') : localStorage.getItem('userId');
      this.workspaceId = !ignoreQueryParams ? this.getParameterByName('s') || localStorage.getItem('workspaceId') : localStorage.getItem('workspaceId');
      this.apiKey = !ignoreQueryParams ? this.getParameterByName('a') || localStorage.getItem('apiKey') : localStorage.getItem('apiKey');
      if (!(this.targetEarnings > 0)) {
        this.targetEarnings = parseFloat(prompt('Enter your target earnings'), 10);
      }
      if (!(this.wage > 0)) {
        this.wage = parseFloat(prompt('Enter your hourly wage'), 10);
      }
      if (_.isNull(this.apiKey)) {
        this.apiKey = prompt('Enter your toggl auth token') + '';
      }
      if (_.isNull(this.workspaceId)) {
        this.workspaceId = prompt('Enter your toggl workspaceId') + '';
      }
      if (_.isNull(this.userId)) {
        this.userId = prompt('Enter your toggl userId') + '';
      }
      localStorage.setItem('earnings', this.targetEarnings);
      localStorage.setItem('wage', this.wage);
      localStorage.setItem('userId', this.userId);
      localStorage.setItem('workspaceId', this.workspaceId);
      localStorage.setItem('apiKey', this.apiKey);
      return this.targetHrs = this.targetEarnings / this.wage;
    },
    getData: function() {
      var that;
      that = this;
      $('.loading').fadeIn('fast');
      $('.row.fade.in').removeClass('in');
      return $.when($.ajax({
        url: this.detailsUrl,
        beforeSend: (function(_this) {
          return function(xhr) {
            xhr.setRequestHeader('Authorization', 'Basic ' + _this.apiKey);
            return xhr.setRequestHeader('X-Requested-With', 'XMLHttpRequest');
          };
        })(this),
        type: 'GET',
        dataType: 'json',
        contentType: 'application/json',
        success: (function(_this) {
          return function(data) {
            return _this.details = data;
          };
        })(this)
      }), $.ajax({
        url: this.summaryUrl,
        beforeSend: (function(_this) {
          return function(xhr) {
            xhr.setRequestHeader('Authorization', 'Basic ' + _this.apiKey);
            return xhr.setRequestHeader('X-Requested-With', 'XMLHttpRequest');
          };
        })(this),
        type: 'GET',
        dataType: 'json',
        contentType: 'application/json',
        success: (function(_this) {
          return function(data) {
            return _this.summary = data;
          };
        })(this)
      })).done((function(_this) {
        return function() {
          return _this.displayData();
        };
      })(this)).fail((function(_this) {
        return function() {
          return $('.loading').removeClass('loading').addClass('error').html('<h1><span class="label label-danger">Error! Wrong credentials!</span></h1> <a class="btn btn-default" href="reset/">Try reseting your variables</a>');
        };
      })(this));
    },
    displayData: function() {
      var $clockOut, $current, $target, $targetAvgToday, $targetHrs, $targetToday, $total, bom, currentAvg, daysLeft, daysLeftToday, daysWorked, eod, eom, targetAvg, targetAvgToday, targetToday, today, todaysHours, totalHours;
      $total = $('.total-hours-display');
      $current = $('.current-avg-display');
      $target = $('.target-avg-display');
      $targetHrs = $('.target-hours-display');
      $targetToday = $('.target-today-display');
      $targetAvgToday = $('.target-avg-today-display');
      $clockOut = $('.clock-out-display');
      todaysHours = Math.round(this.summary.total_grand / 1000 / 60 / 60 * 10) / 10;
      totalHours = Math.round(this.details.total_grand / 1000 / 60 / 60 * 10) / 10;
      $total.html(totalHours);
      today = moment().hour(0);
      bom = moment().date(1);
      daysWorked = today.weekDays(bom);
      currentAvg = Math.round(totalHours / daysWorked * 10) / 10;
      $current.html(currentAvg);
      $targetHrs.html(this.targetHrs);
      eom = moment().date(today.daysInMonth());
      daysLeft = today.weekDays(eom);
      targetAvg = Math.round((this.targetHrs - totalHours) / daysLeft * 10) / 10;
      $target.html(targetAvg);
      daysLeftToday = daysLeft + 1;
      targetAvgToday = Math.round((this.targetHrs - totalHours + todaysHours) / daysLeftToday * 10) / 10;
      $targetAvgToday.html(targetAvgToday);
      targetToday = Math.round((targetAvgToday - todaysHours) * 10) / 10;
      $targetToday.html(targetToday);
      eod = moment().add(targetToday, 'h').format('h:mma');
      $clockOut.html(eod);
      document.title = '(' + targetToday + ') ' + this.documentTitle;
      $('body').removeClass('show-menu');
      return $('.loading').stop().fadeOut(function() {
        return $('.row.fade').addClass('in');
      });
    },
    displaySettings: function() {
      var $apiKey, $earnings, $form, $inputs, $saveBtn, $userId, $wage, $workspaceId;
      $form = $('.menu form');
      $inputs = $form.find('input');
      $saveBtn = $form.find('button');
      $earnings = $('#earnings').val(this.targetEarnings);
      $wage = $('#wage').val(this.wage);
      $userId = $('#userId').val(this.userId);
      $workspaceId = $('#workspaceId').val(this.workspaceId);
      $apiKey = $('#apiKey').val(this.apiKey);
      return $form.on('submit', (function(_this) {
        return function(e) {
          e.preventDefault();
          localStorage.setItem('earnings', $earnings.val());
          localStorage.setItem('wage', $wage.val());
          localStorage.setItem('userId', $userId.val());
          localStorage.setItem('workspaceId', $workspaceId.val());
          localStorage.setItem('apiKey', $apiKey.val());
          _this.setLocalData();
          _this.displayData();
          return false;
        };
      })(this));
    },
    attachCopyLink: function() {
      var $btn, btn;
      $btn = $('.menu .btn-link');
      btn = new ZeroClipboard($btn.get(0));
      $btn.on('mousedown', (function(_this) {
        return function() {
          var url;
          url = location.href;
          url += '?e=' + _this.targetEarnings;
          url += '&w=' + _this.wage;
          url += '&u=' + _this.userId;
          url += '&s=' + _this.workspaceId;
          url += '&a=' + _this.apiKey;
          return $btn.attr('data-clipboard-text', url);
        };
      })(this));
      return btn.on('ready', function() {
        return btn.on('afterCopy', function(event) {
          var msgs;
          msgs = ['Hip hip hooray!', 'Woohoo!', 'Fantabalistic!', 'Ain\'t that special?!', '(successkid)!', '(rockon)!', '...like a boss!'];
          $('#msg').html('Copied! ' + _.sample(msgs)).addClass('in');
          return setTimeout(function() {
            return $('#msg').removeClass('in');
          }, 2000);
        });
      });
    },
    attachAutoRefresh: function() {
      this.autoUpdate = 0;
      this.autoTimer = moment();
      return $(window).on('blur', (function(_this) {
        return function() {
          clearInterval(_this.autoUpdate);
          return _this.autoUpdate = setInterval(function() {
            return _this.getData();
          }, 5 * 60 * 1000);
        };
      })(this)).on('focus', (function(_this) {
        return function() {
          clearInterval(_this.autoUpdate);
          if (moment().diff(_this.autoTimer) > 5 * 60 * 1000) {
            _this.autoTimer = moment();
            return _this.getData();
          }
        };
      })(this));
    },
    getParameterByName: function(name) {
      var regex, results;
      name = name.replace(/[\[]/, "\\[").replace(/[\]]/, "\\]");
      regex = new RegExp("[\\?&]" + name + "=([^&#]*)");
      results = regex.exec(location.search);
      if (results === null) {
        return '';
      } else {
        return decodeURIComponent(results[1].replace(/\+/g, " "));
      }
    }
  };

  Site.init();

}).call(this);
