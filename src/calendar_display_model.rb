Placeholder = Struct.new(:label, :startDate)

class CalendarDisplayModel

	##############################################
	# mappings between indexpaths, sections, rows,
	# calendar events, droptarget placeholders

	attr_reader :open_section
	TIMES = %w{ bfst morn lunch aft hpy_hr eve night }


	def things_in_section n
		events = events_on_date(sections[n])
		return events unless n == @open_section

		# generate placeholders
		date = sections[n]
		placeholders = []
		TIMES.each do |label|
			t = date + NSDate::HOUR_RANGES[label.to_sym].begin.hours
			next unless Time.now - t < 1.hour
			next if events.any?{ |e| e.startDate == t }
			placeholders << Placeholder.new(label, t)
		end

		(placeholders + events).sort_by{ |x| x.startDate}
	end




	def open_up_section s
		return if @open_section == s
		closed = @open_section ? placeholder_positions : []
		@open_section = s
		opened = @open_section ? placeholder_positions : []
		return opened, closed
	end

	def placeholder_positions
		return [] unless @open_section
		p = []
		things_in_section(@open_section).each_with_index do |t,i|
			p << i if Placeholder === t
		end
		p.map{ |p| [@open_section,p].nsindexpath }
	end

	def thing_at_index_path p
		return things_in_section(p.section)[p.row]
	end

	def index_path_for_event(ev)
		id = ev.eventIdentifier
		date = ev.startDate.start_of_day
		section = sections.index(date)
		xs = things_in_section section
		row = xs.index{ |e| EKEvent === e && e.eventIdentifier == id }
		[section,row].nsindexpath
	end

	def item_count_for_section n
		things_in_section(n).size
	end

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

	def moved(ev)
		date = ev.startDate.start_of_day
		@events_by_day[date] = @events_by_day[date].sort_by{ |e| e.startDate }
	end

	def add_event(start_time, person, text)
		ev = Event.add_event(start_time, person, text)
		id = ev.eventIdentifier
		date = ev.startDate.start_of_day
		# section = sections.index(date)
		@events_by_day[date] ||= []
		@events_by_day[date] << ev
		@events_by_day[date] = @events_by_day[date].sort_by{ |e| e.startDate }
		# row = things_in_section(section).index{ |e| e.eventIdentifier == id }
		# path = [section,row].nsindexpath
		return ev
	end

	def remove_event(ev)
		events_on_date(ev.startDate.start_of_day).delete(ev)
		if ev.calendar.allowsContentModifications
	  		Event.delete!(ev)
  		else
  			Event.hide_matching(ev)
  		end
	end

end
