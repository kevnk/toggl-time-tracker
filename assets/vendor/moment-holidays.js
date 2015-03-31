//## Moment.JS Holiday Plugin
//
//Usage:
//  Call .holiday() from any moment object. If date is a US Federal Holiday, name of the holiday will be returned.
//  Otherwise, return nothing.
//
//  Example:
//    `moment('12/25/2013').holiday()` will return "Christmas Day"
//
//Holidays:
//  You can configure holiday bellow. The 'M' stands for Month and represents fixed day holidays.
//  The 'W' stands for Week, and represents holidays with date based on week day rules.
//  Example: '10/2/1' Columbus Day (Second monday of october).
//
//License:
//  Copyright (c) 2013 [Jr. Hames](http://jrham.es) under [MIT License](http://opensource.org/licenses/MIT)
(function() {
    var moment;

    moment = typeof require !== "undefined" && require !== null ? require("moment") : this.moment;

    var _getEaster = function(d) {
        var Y = d.getFullYear();
        var C = Math.floor(Y/100);
        var N = Y - 19*Math.floor(Y/19);
        var K = Math.floor((C - 17)/25);
        var I = C - Math.floor(C/4) - Math.floor((C - K)/3) + 19*N + 15;
        I = I - 30*Math.floor((I/30));
        I = I - Math.floor(I/28)*(1 - Math.floor(I/28)*Math.floor(29/(I + 1))*Math.floor((21 - N)/11));
        var J = Y + Math.floor(Y/4) + I + 2 - C + Math.floor(C/4);
        J = J - 7*Math.floor(J/7);
        var L = I - J;
        var M = 3 + Math.floor((L + 40)/44);
        var D = L + 28 - 31*Math.floor(M/4);

        // zero-index month
        M = M - 1;

        return moment(new Date(Y, M, D));
    }

    var _isGoodFriday = function(d) {
        var easter = _getEaster(d);
        var goodFriday = moment(easter._d).subtract(2, 'days')._d;
        return d.getMonth() === goodFriday.getMonth() && d.getDate() === goodFriday.getDate();
    }

    var _isEaster = function(d) {
        var easter = _getEaster(d)._d;
        return d.getMonth() === easter.getMonth() && d.getDate() === easter.getDate();
    }

    //Holiday definitions
    var _holidays = {
        'M': {//Month, Day
            '01/01': "New Year's Day",
            '07/04': "Independence Day",
            '11/11': "Veteran's Day",
            '11/28': "Thanksgiving Day",
            '11/29': "Day after Thanksgiving",
            '12/24': "Christmas Eve",
            '12/25': "Christmas Day",
            '12/31': "New Year's Eve"
        },
        'W': {//Month, Week of Month, Day of Week
            '1/3/1': "Martin Luther King Jr. Day",
            '2/3/1': "Washington's Birthday",
            '5/5/1': "Memorial Day",
            '9/1/1': "Labor Day",
            '10/2/1': "Columbus Day",
            '11/4/4': "Thanksgiving Day"
        },
        'F': [
            { 'Easter': _isEaster },
            { 'Good Friday': _isGoodFriday }
        ]
    };

    moment.fn.holiday = function() {
        var diff = 1+ (0 | (this._d.getDate() - 1) / 7),
            memorial = (this._d.getDay() === 1 && (this._d.getDate() + 7) > 30) ? "5" : null,
            that = this;


        var checkFunctions = function() {
            for (var i = _holidays.F.length - 1; i >= 0; i--) {
                var obj = _holidays.F[i];
                for (prop in obj) {
                    var func = obj[prop];
                    if(typeof func === 'function') {
                        if(func(that._d)) {
                            return prop;
                        }
                    }
                }
            }
            return undefined;
        }

        return (_holidays['M'][this.format('MM/DD')] || _holidays['W'][this.format('M/'+ (memorial || diff) +'/d')]) || checkFunctions();
    };

    if ((typeof module !== "undefined" && module !== null ? module.exports : void 0) != null) {
        module.exports = moment;
    }

}(this));