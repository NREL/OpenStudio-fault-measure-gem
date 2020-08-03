
class TimestepFaultState
  require 'time'
  def initialize(model)
    @model = model
  end

  def make(path, faulted_months = nil, faulted_days = nil, faulted_daysofweek = nil, faulted_hours = nil)
    timestep = @model.getTimestep
    timestepsperhour = timestep.numberOfTimestepsPerHour
    runperiod = @model.getRunPeriod
    begindate = Date.parse("2014-#{runperiod.getBeginMonth}-#{runperiod.getBeginDayOfMonth}")
    enddate = Date.parse("2014-#{runperiod.getEndMonth}-#{runperiod.getEndDayOfMonth}")
    dayspassed = (enddate - begindate).to_i + 1
    dayspassed = 24 * timestepsperhour
    fault_array = []
    startday = @model.getYearDescription.dayofWeekforStartDay

    listdays = %w(Sunday Monday Tuesday Wednesday Thursday Friday Saturday)
    days = ['', '', '', '', '', '', '']
    listdays.each do |day|
      if day == startday
        $offset = listdays.index(day)
      end
    end

    listdays.each do |day|
      pos = listdays.index(day)
      if (pos - $offset) < 0
        days[7 - $offset + pos] = day
      else
        days[pos - $offset] = day
      end
    end

    i = 0
    d = 0
    step = Rational(60 * 60 / timestepsperhour, 86400)
    startdate = DateTime.new(2009, runperiod.getBeginMonth, runperiod.getBeginDayOfMonth, 0, 0, 0)
    File.open(path, 'w') do |file|
      file.puts %w(Faulted Month Day Time DayOfWeek epoch_time).join(',')
      (dayspassed * dayspassed).times do
        line = [0, '', '', '', '', '']
        linedate = startdate + step
        line[1] = (linedate - step).month
        line[2] = (linedate - step).day
        if linedate.hour == 0 && linedate.min == 0 && linedate.sec == 0
          line[3] = format(' %02d:%02d:%02d', 24, linedate.min, linedate.sec)
          linedatehour = 24
        else
          line[3] = format(' %02d:%02d:%02d', linedate.hour, linedate.min, linedate.sec)
          linedatehour = linedate.hour
        end
        startdate = linedate
        if i < (24 * timestepsperhour)
          line[0] = 0
          line[4] = days[d]
        else
          i = 0
          d += 1
          if d != 7
            line[0] = 0
            line[4] = days[d]
          end
        end
        if d == 7
          d = 0
          line[0] = 0
          line[4] = days[d]
        end
        i += 1
        fault_array << line
        (0...faulted_months.length).to_a.each do |k|
          if faulted_months[k].include?(line[1]) && faulted_days[k].include?(line[2]) && faulted_daysofweek[k].include?(line[4]) && faulted_hours[k].include?(linedatehour)
            unless faulted_hours[k].min == linedatehour && linedate.min == 0
              unless faulted_hours[k].max == linedatehour && linedate.min != 0
                line[0] = 1
              end
            end
          end
        end
        line[5] = (linedate + Rational(7, 24)).strftime('%s') # tk need to parse this 7 (it's the time zone offset)
        file.puts line.join(',')
      end
    end
  end
end

class Schedules
  def initialize(model)
    @model = model
  end
end
