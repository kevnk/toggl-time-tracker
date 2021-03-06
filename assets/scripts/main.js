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
      this.setCalculatedVariables();
      this.attachVacationsDays();
      this.displaySettings();
      this.attachCopyLink();
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
      this.targetHrs = this.targetEarnings / this.wage;
      this.today = moment().hour(0).minute(0).second(0);
      this.bom = moment(this.today._d).date(1);
      this.eom = moment(this.today._d).date(this.today.daysInMonth());
      this.tomorrow = moment(this.today._d).add(1, 'day');
      this.nmBom = moment(this.tomorrow._d).date(1);
      this.nmEom = moment(this.tomorrow._d).date(this.tomorrow.daysInMonth());
      this.isTheFirst = this.today.date() === this.bom.date();
      this.isTheLast = this.today.date() === this.eom.date();
      this.isWeekday = this.today.isWeekDay();
      this.isHoliday = this.today.holiday();
      this.nmIsWeekday = this.tomorrow.isWeekDay();
      this.nmIsHoliday = this.tomorrow.holiday();
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
    setCalculatedVariables: function() {
      this.isVacationDay = _.some(_.filter(this.savedVacations, (function(_this) {
        return function(vacation) {
          if (_this.holidaysByName[vacation]) {
            return _this.holidaysByName[vacation].date.format('YYYYMMDD') === _this.today.format('YYYYMMDD');
          } else {
            return false;
          }
        };
      })(this)));
      this.vacationDaysRemaining = _.size(_.filter(this.savedVacations, (function(_this) {
        return function(vacation) {
          if (_this.holidaysByName[vacation]) {
            return _this.holidaysByName[vacation].date > _this.today;
          } else {
            return true;
          }
        };
      })(this)));
      this.vacationDaysSpent = _.size(this.savedVacations) - this.vacationDaysRemaining;
      this.isWorkDay = this.isWeekday && !this.isVacationDay;
      this.workDaysTotal = this.bom.weekDays(this.eom) + 1;
      this.workDaysWorked = this.bom.weekDays(this.today) - this.vacationDaysSpent;
      this.workDaysLeft = this.workDaysTotal - this.workDaysWorked - this.vacationDaysRemaining;
      this.workDaysLeftTomorrow = this.isWorkDay ? this.workDaysLeft - 1 : this.workDaysLeft;
      this.nmIsVacationDay = _.some(_.filter(this.savedVacations, (function(_this) {
        return function(vacation) {
          if (_this.holidaysByName[vacation]) {
            return _this.holidaysByName[vacation].date.format('YYYYMMDD') === _this.tomorrow.format('YYYYMMDD');
          } else {
            return false;
          }
        };
      })(this)));
      this.nmIsWorkDay = this.nmIsWeekday && !this.nmIsVacationDay;
      this.nmWorkDaysTotal = this.nmBom.weekDays(this.nmEom) + 1;
      this.nmWorkDaysWorked = 0;
      this.nmWorkDaysLeft = this.nmWorkDaysTotal;
      return this.nmWorkDaysLeftTomorrow = this.nmIsWorkDay ? this.nmWorkDaysLeft - 1 : this.nmWorkDaysLeft;
    },
    getData: function() {
      var qSince, qToday, qUntil, that;
      qSince = this.bom.format('YYYY-MM-DD');
      qUntil = this.eom.format('YYYY-MM-DD');
      qToday = this.today.format('YYYY-MM-DD');
      this.detailsUrl = 'https://toggl.com/reports/api/v2/details?rounding=Off&status=active&user_ids=' + this.userId + '&name=&billable=both&calculate=time&sortDirection=asc&sortBy=date&page=1&description=&since=' + qSince + '&until=' + qUntil + '&workspace_id=' + this.workspaceId + '&period=thisMonth&with_total_currencies=1&grouping=&subgrouping=time_entries&order_field=date&order_desc=off&distinct_rates=Off&user_agent=Toggl+New+3.28.13&bars_count=31&subgrouping_ids=true&bookmark_token=';
      this.summaryUrl = 'https://toggl.com/reports/api/v2/summary.json?grouping=projects&subgrouping=time_entries&order_field=title&order_desc=off&rounding=Off&distinct_rates=Off&status=active&user_ids=' + this.userId + '&name=&billable=both&workspace_id=' + this.workspaceId + '&calculate=time&sortDirection=asc&sortBy=title&page=1&description=&since=' + qToday + '&until=' + qToday + '&period=today&with_total_currencies=1&user_agent=Toggl+New+3.28.13&bars_count=31&subgrouping_ids=true&bookmark_token=';
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
          _this.todaysHours = Math.round(_this.summary.total_grand / 1000 / 60 / 60 * 10) / 10;
          _this.totalHours = Math.round(_this.details.total_grand / 1000 / 60 / 60 * 10) / 10;
          return _this.displayData();
        };
      })(this)).fail((function(_this) {
        return function() {
          return $('.loading').removeClass('loading').addClass('error').html('<h1><span class="label label-danger">Error! Wrong credentials!</span></h1> <a class="btn btn-default" href="reset/">Try reseting your variables</a>');
        };
      })(this));
    },
    displayData: function() {
      var $clockOut, $current, $target, $targetAvgToday, $targetHrs, $targetToday, $total, $vacation, currentAvg, eod, targetAvg, targetAvgToday, targetToday;
      $total = $('.total-hours-display');
      $current = $('.current-avg-display');
      $target = $('.target-avg-display');
      $targetHrs = $('.target-hours-display');
      $targetToday = $('.target-today-display');
      $targetAvgToday = $('.target-avg-today-display');
      $clockOut = $('.clock-out-display');
      $vacation = $('.vacation-days-display');
      $total.html(this.totalHours);
      currentAvg = this.isTheFirst ? this.totalHours : (this.totalHours - this.todaysHours) / this.workDaysWorked;
      currentAvg = Math.round(currentAvg * 10) / 10;
      $current.html(currentAvg);
      $targetHrs.html(this.targetHrs);
      if (!this.isTheLast) {
        targetAvg = Math.round((this.targetHrs - this.totalHours) / this.workDaysLeftTomorrow * 10) / 10;
      } else {
        targetAvg = Math.round(this.targetHrs / this.nmWorkDaysLeftTomorrow * 10) / 10;
      }
      $target.html(targetAvg);
      if (!this.isTheFirst) {
        targetAvgToday = Math.round((this.targetHrs - this.totalHours + this.todaysHours) / this.workDaysLeft * 10) / 10;
      } else {
        targetAvgToday = Math.round((this.targetHrs - this.todaysHours) / this.workDaysLeft * 10) / 10;
      }
      $targetAvgToday.html(targetAvgToday);
      targetToday = Math.round((targetAvgToday - this.todaysHours) * 10) / 10;
      $targetToday.html(targetToday);
      eod = moment().add(targetToday, 'h').format('h:mma');
      $clockOut.html(eod);
      $vacation.html(this.vacationDaysRemaining);
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
    attachVacationsDays: function() {
      var $minusBtn, $plusBtn, addManualVacationInput, form, manualVacations;
      this.$holidays = $('#holidays');
      _.each(this.holidays, (function(_this) {
        return function(holiday) {
          var checkedAttr;
          checkedAttr = holiday.checked ? ' checked' : '';
          return _this.$holidays.find('form').append('<div class="checkbox"> <label class="btn btn-default"><input' + checkedAttr + ' data-name="' + holiday.name + '" type="checkbox"/> ' + holiday.name + '&nbsp;&nbsp;<span>' + holiday.date.format('ddd, MMM Do') + '<span> </label> </div>');
        };
      })(this));
      this.$holidays.find('input').on('change', (function(_this) {
        return function() {
          _this.storeVacationDays();
          _this.setCalculatedVariables();
          return _this.displayData();
        };
      })(this));
      form = this.$holidays.find('form');
      $minusBtn = this.$holidays.find('#minus_vacation_day');
      $plusBtn = this.$holidays.find('#plus_vacation_day');
      addManualVacationInput = function() {
        return form.append($('<div class="hide checkbox"> <input checked type="checkbox" data-name="' + moment().format('YYYYMMDDhhmmss') + '"/> </div>'));
      };
      manualVacations = _.filter(this.savedVacations, function(vacation) {
        return /\d/.test(vacation);
      });
      _.each(manualVacations, addManualVacationInput);
      $plusBtn.on('click', (function(_this) {
        return function(e) {
          addManualVacationInput();
          $minusBtn.removeClass('hide');
          _this.storeVacationDays();
          _this.setCalculatedVariables();
          return _this.displayData();
        };
      })(this));
      $minusBtn.on('click', (function(_this) {
        return function(e) {
          if (!(form.find('.checkbox.hide').size() >= 2)) {
            $minusBtn.addClass('hide');
          }
          form.find('.checkbox.hide').first().remove();
          _this.storeVacationDays();
          _this.setCalculatedVariables();
          return _this.displayData();
        };
      })(this));
      if (form.find('.checkbox.hide').size() < 1) {
        return $minusBtn.addClass('hide');
      }
    },
    storeVacationDays: function() {
      var vacations;
      vacations = [];
      this.$holidays.find('input[type=checkbox]:checked').each(function() {
        var $el;
        $el = $(this);
        return vacations.push($el.data('name'));
      });
      this.savedVacations = vacations;
      return localStorage.setItem('vacations', vacations.join(','));
    },
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
    }
  };

  Site.init();

}).call(this);
