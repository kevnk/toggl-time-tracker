// Generated by CoffeeScript 1.7.1
(function() {
  var Site;

  Site = {
    init: function() {
      this.setLocalData(false);
      this.documentTitle = document.title;
      if (location.search) {
        document.location = location.origin + location.pathname;
      }
      this.getData();
      this.attachAutoRefresh();
      return this;
    },
    setLocalData: function(ignoreQueryParams) {
      if (ignoreQueryParams == null) {
        ignoreQueryParams = true;
      }
      this.apiKey = !ignoreQueryParams ? this.getParameterByName('a') || localStorage.getItem('apiKey') : localStorage.getItem('apiKey');
      this.workspaceId = !ignoreQueryParams ? this.getParameterByName('s') || localStorage.getItem('workspaceId') : localStorage.getItem('workspaceId');
      this.userId = !ignoreQueryParams ? this.getParameterByName('u') || localStorage.getItem('userId') : localStorage.getItem('userId');
      if (_.isNull(this.apiKey)) {
        this.apiKey = prompt('Enter your toggl auth token') + '';
      }
      if (_.isNull(this.workspaceId)) {
        this.workspaceId = prompt('Enter your toggl workspaceId') + '';
      }
      if (_.isNull(this.userId)) {
        this.userId = prompt('Enter your toggl userId') + '';
      }
      localStorage.setItem('apiKey', this.apiKey);
      localStorage.setItem('workspaceId', this.workspaceId);
      localStorage.setItem('userId', this.userId);
      this.$content = $('#content');
      this.$loader = $('.row.loading');
      this.today = moment().hour(0).minute(0).second(0);
      this.bom = moment(this.today._d).date(1);
      this.eom = moment(this.today._d).date(this.today.daysInMonth());
      this.isTheFirst = this.today.date() === this.bom.date();
      this.isTheLast = this.today.date() === this.eom.date();
      this.isWeekday = this.today.isWeekDay();
      this.isHoliday = this.today.holiday();
      this.savedVacations = localStorage.getItem('vacations') ? localStorage.getItem('vacations').split(',') : [];
      this.holidays = [];
      this.holidaysByName = {};
      return moment().range(this.bom._d, this.eom._d).by('days', (function(_this) {
        return function(moment) {
          var holiday, holidayObj;
          if (!moment.isWeekDay()) {
            return;
          }
          holiday = moment.holiday();
          if (!_.isUndefined(holiday)) {
            holidayObj = {
              name: holiday,
              date: moment,
              checked: _.contains(_this.savedVacations, holiday)
            };
            _this.holidays.push(holidayObj);
            return _this.holidaysByName[holiday] = holidayObj;
          }
        };
      })(this));
    },
    setCalculatedVariables: function() {},
    getData: function() {
      var qSince, qToday, qUntil, that;
      qSince = this.bom.format('YYYY-MM-DD');
      qUntil = this.eom.format('YYYY-MM-DD');
      qToday = this.today.format('YYYY-MM-DD');
      this.detailsUrl = 'https://toggl.com/reports/api/v2/details?rounding=Off&status=active&user_ids=' + this.userId + '&name=&billable=both&calculate=time&sortDirection=asc&sortBy=date&page=1&description=&since=' + qSince + '&until=' + qUntil + '&workspace_id=' + this.workspaceId + '&period=thisMonth&with_total_currencies=1&grouping=&subgrouping=time_entries&order_field=date&order_desc=off&distinct_rates=Off&user_agent=Toggl+New+3.28.13&bars_count=31&subgrouping_ids=true&bookmark_token=';
      this.summaryUrl = 'https://toggl.com/reports/api/v2/summary.json?grouping=projects&subgrouping=time_entries&order_field=title&order_desc=off&rounding=Off&distinct_rates=Off&status=active&user_ids=' + this.userId + '&name=&billable=both&workspace_id=' + this.workspaceId + '&calculate=time&sortDirection=asc&sortBy=title&page=1&description=&since=' + qToday + '&until=' + qToday + '&period=today&with_total_currencies=1&user_agent=Toggl+New+3.28.13&bars_count=31&subgrouping_ids=true&bookmark_token=';
      that = this;
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
          _this.todaysHours = Math.round(_this.summary.total_grand / 1000 / 60 / 60 * 10) / 10;
          _this.totalHours = Math.round(_this.details.total_grand / 1000 / 60 / 60 * 10) / 10;
          return _this.displayData();
        };
      })(this)).fail((function(_this) {
        return function() {
          return alert('fail');
        };
      })(this));
    },
    displayData: function() {
      this.addDebug();
      return this.toggleContent();
    },
    toggleContent: function(show) {
      if (show == null) {
        show = true;
      }
      if (show) {
        this.$loader.addClass('fade');
        return this.$content.removeClass('fade');
      } else {
        this.$loader.removeClass('fade');
        return this.$content.addClass('fade');
      }
    },
    attachVacationsDays: function() {},
    storeVacationDays: function() {},
    attachAutoRefresh: function() {
      this.autoUpdate = 0;
      this.autoTimer = moment();
      return $(window).on('blur', (function(_this) {
        return function() {
          clearInterval(_this.autoUpdate);
          return _this.autoUpdate = setInterval(function() {
            return _this.getData();
          }, 2 * 60 * 1000);
        };
      })(this)).on('focus', (function(_this) {
        return function() {
          clearInterval(_this.autoUpdate);
          if (moment().diff(_this.autoTimer) > 2 * 60 * 1000) {
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
    },
    addDebug: function() {
      if (location.host !== 'localhost') {
        return;
      }
      console.log('%c DEBUG: Site -->', 'color:#F80', Site);
      this.$debug = this.$debug || $('body').append('<div id="debug" class="container">').find('#debug');
      return _.each(this, (function(_this) {
        return function(item, key) {
          if (!_.isFunction(item)) {
            if (_.isObject(item)) {
              return console.log('%c DEBUG: ' + key + ' -->', 'color:#F80', item);
            } else {
              return _this.$debug.append('<strong>' + key + ':</strong> ' + item + '<br>');
            }
          }
        };
      })(this));
    }
  };

  Site.init();

}).call(this);
