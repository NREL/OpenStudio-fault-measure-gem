# This ruby scripts contain the constants that can be used as global variables
# for schedule settings

$months = %w(January February March April May June
             July August September October November December)
$weekdays = %w(Monday Tuesday Wednesday Thursday Friday)
$weekend = %w(Saturday Sunday)
$dayofweeks = %w(Monday Tuesday Wednesday Thursday Friday Saturday Sunday)
$e_days = { 'January' => 31, 'February' => 28, 'March' => 31, 'April' => 30,
            'May' => 31, 'June' => 30, 'July' => 31, 'August' => 31,
            'September' => 30, 'October' => 31, 'November' => 30,
            'December' => 31 }
$not_faulted = 'Not faulted'
$all_days = 'All days'
$weekdaysonly = 'Weekdays only'
$weekendonly = 'Weekend only'
$end_hour = 15
$allzonechoices = '* All Zones *'
