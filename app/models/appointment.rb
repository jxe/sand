class IOSCalendar
  EVENT_STORE = EKEventStore.alloc.init

  def self.request_permission
  	EVENT_STORE.requestAccessToEntityType(EKEntityTypeEvent, completion:proc{ |a,b| });
  end

  def self.events(calendars, start_date, end_date)
  	p = EVENT_STORE.predicateForEventsWithStartDate(start_date, endDate:end_date, calendars:calendars)
  	EVENT_STORE.eventsMatchingPredicate(p)
  end
end


class Appointment < Struct.new(:when, :what)
  def self.all
  end
end
