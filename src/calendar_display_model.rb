class CalendarDisplayModel

	##################################################################
	# mappings between indexpaths, sections, rows, and calendar events

	def timeframe
		dates = timeframe_dates
		[dates[0], dates[-1] + 24.hours]
	end

	def timeframe_dates
		@timeframe_dates ||= begin
			today = Time.today
			(0..14).map{ |n| today.delta(days: n).start_of_day }
		end
	end

	def load_events
		@timeframe_dates = nil
		@events_by_day = {}
		return unless AuthenticationController.all_authed?

		Event.legit_events(timeframe, proc{ reload }).each do |ev|
			morning = ev.startDate.start_of_day
			section = @events_by_day[morning] ||= []
			section << ev unless section.detect{ |existing| existing.title == ev.title and existing.startDate == ev.startDate }
		end
	end

	def sections
		timeframe_dates
	end

	def events_on_date d
		@events_by_day[d] || []
	end

	def item_count_for_section n
		date = sections[n]
		events = @events_by_day[date] || []
		events_on_date(date).length
	end

	def thing_at_index_path p
		date = sections[p.section]
		ev = events_on_date(date)[p.row]
		return :event, ev if ev
	end

	def add_event(start_time, person, text)
		ev = Event.add_event(start_time, person, text)
		id = ev.eventIdentifier
		date = ev.startDate.start_of_day
		section = sections.index(date)
		@events_by_day[date] ||= []
		@events_by_day[date] << ev
		@events_by_day[date] = @events_by_day[date].sort_by{ |e| e.startDate }
		row = events_on_date(date).index{ |e| e.eventIdentifier == id }
		path = [section,row].nsindexpath
		return ev, path
	end

	def remove_event(ev)
		events_on_date(ev.startDate.start_of_day).delete(ev)
		if ev.calendar.allowsContentModifications
	  		Event.delete!(ev)
  		else
  			Event.hide_matching(ev)
  		end
	end

	def index_path_for_event(ev)
		id = ev.eventIdentifier
		date = ev.startDate.start_of_day
		section = sections.index(date)
		row = events_on_date(date).index{ |e| e.eventIdentifier == id }
		[section,row].nsindexpath
	end

end
