
class TimestepFaultState
  require 'time'
  def initialize(model)
    @model = model
  end

  def make(path, faulted_months=nil, faulted_days=nil, faulted_daysofweek=nil, faulted_hours=nil)
    timestep = @model.getTimestep
    timestepsPerHour = timestep.numberOfTimestepsPerHour
    runPeriod = @model.getRunPeriod
    beginDate = Date.parse("#{2014}-#{runPeriod.getBeginMonth}-#{runPeriod.getBeginDayOfMonth}")
    endDate = Date.parse("#{2014}-#{runPeriod.getEndMonth}-#{runPeriod.getEndDayOfMonth}")
    daysPassed = (endDate - beginDate).to_i + 1
    numTimestepsPerDay = 24 * timestepsPerHour
    fault_array = Array.new
    startday = @model.getYearDescription.dayofWeekforStartDay

    listdays = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
    days = ["","","","","","",""]
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
    step = Rational(60 * 60 / timestepsPerHour, 86400)
    startDate = DateTime.new(2009,runPeriod.getBeginMonth,runPeriod.getBeginDayOfMonth,0,0,0)
    File.open(path, 'w') do |file|
      file.puts ["Faulted", "Month", "Day", "Time", "DayOfWeek", "epoch_time"].join(',')
      (daysPassed * numTimestepsPerDay).times do
        line = [0,"","","","",""]
        lineDate = startDate + step
        line[1] = (lineDate - step).month
        line[2] = (lineDate - step).day
        if lineDate.hour == 0 and lineDate.min == 0 and lineDate.sec == 0
          line[3] = " %02d:%02d:%02d" % [24, lineDate.min, lineDate.sec]
          lineDatehour = 24
        else
          line[3] = " %02d:%02d:%02d" % [lineDate.hour, lineDate.min, lineDate.sec]
          lineDatehour = lineDate.hour
        end
        startDate = lineDate
        if i < (24 * timestepsPerHour)
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
          if faulted_months[k].include? line[1] and faulted_days[k].include? line[2] and faulted_daysofweek[k].include? line[4] and faulted_hours[k].include? lineDatehour
            if not (faulted_hours[k].min == lineDatehour and lineDate.min == 0)
              if not (faulted_hours[k].max == lineDatehour and lineDate.min != 0)
                line[0] = 1
              end
            end
          end
        end
        line[5] = (lineDate + Rational(7,24)).strftime('%s') # tk need to parse this 7 (it's the time zone offset)
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