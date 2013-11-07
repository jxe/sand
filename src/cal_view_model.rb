Placeholder = Struct.new(:label, :startDate)

class CalViewModel

	##############################################
	# mappings between indexpaths, sections, rows,
	# calendar events, droptarget placeholders

	attr_reader :date_open
	TIMES = %w{ bfst morn lunch aft hpy_hr eve night }


	######
	# managing placeholder appearance/disappearance

	def hover section
		date = section && sections[section]
		if @date_open == date
			# no-op

		elsif !@date_open
			@date_open = date
			puts "before_open:\n   #{inspect_row(date)}"
			add_basic_placeholders
			puts "after_open:\n   #{inspect_row(date)}"

		elsif !section
			puts "before close:\n   #{inspect_row(@date_open)}"
			remove_all_placeholders
			puts "after close:\n   #{inspect_row(@date_open)}"
			@date_open = nil

		else
			remove_all_placeholders
			@date_open = date
			add_basic_placeholders

		end
	end


	def add_basic_placeholders
		TIMES.each do |label|
			t = @date_open + NSDate::HOUR_RANGES[label.to_sym].begin.hours
			next unless Time.now - t < 1.hour
			next if objs(@date_open).any?{ |e| e.startDate == t }

			place = objs(@date_open).index{ |x| x.startDate > t }
			place ||= objs(@date_open).size
			objs(@date_open).insert(place, Placeholder.new(label, t))
		end
	end



	def remove_all_placeholders
		objs(@date_open).reject!{ |p| Placeholder === p }
	end



	######
	# creating/removing events

	def add_event_at_placeholder(pl, person, text)
		start_time = pl.startDate
		date = start_time.start_of_day
		ev = Event.add_event(start_time, person, text)
		@objs[date][@objs[date].index(pl)] = ev
	end

	def add_event_before_event(ev0, person, text)
		start_time = ev0.startDate
		date = start_time.start_of_day
		ev = Event.add_event(start_time, person, text)
		@objs[date].insert(@objs[date].index(ev0), ev)
		ev
	end

	def today_paths
		(0..objs(Time.today.start_of_day).size-1).map{ |i| [0,i].nsindexpath }
	end

	def inspect_all_rows
		@objs.keys.map{ |k| "#{k.inspect}: #{inspect_row k}" }.join
	end

	def inspect_row date
		objs(date).map do |obj|
			case obj
			when EKEvent;
				"EV(#{obj.title}, #{obj.startDate.time_of_day_label})"
			when Placeholder; 
				":#{obj.startDate.time_of_day_label}"
			else
				obj.inspect
			end
		end.join("\n    ")
	end

	def move_before_event(ev, ev0)
		date = ev.startDate.start_of_day
		old_loc = objs(date).index(ev)
		new_loc = objs(date).index(ev0)
		ev.startDate = ev0.startDate
		ev.endDate = ev0.endDate
		Event.save(ev)
		puts "\n\npreviously:\n\n#{inspect_row(date)}"
		objs(date).insert(new_loc, :tmp)
		objs(date).delete(ev)
		new_loc = objs(date).index(:tmp)
		objs(date)[new_loc] = ev
		puts "\n\nnow:\n\n#{inspect_row(date)}"
		return new_loc
	end

	def move_to_placeholder(ev, placeholder)
		date = ev.startDate.start_of_day
		old_loc = objs(date).index(ev)
		new_loc = objs(date).index(placeholder)
		ev.startDate = placeholder.startDate
		ev.endDate = placeholder.startDate + 2.hours
		Event.save(ev)
		objs(date)[new_loc] = ev
		objs(date).delete_at(old_loc)
	end

	def remove_event(ev)
		objs(ev.startDate.start_of_day).delete(ev)
		if ev.calendar.allowsContentModifications
	  		ev.delete!
  		else
  			ev.hide_matching!
  		end
	end



	######
	# basic access

	def objs d; @objs[d] ||= []; end

	def placeholder_positions
		return [] unless @date_open
		p = []
		objs(@date_open).each_with_index do |t,i|
			p << i if Placeholder === t
		end
		section = sections.index(@date_open)
		p.map{ |p| [section,p].nsindexpath }
	end

	def section(n)
		objs(sections[n])
	end

	def thing_at_index_path p
		return section(p.section)[p.row]
	end

	def index_path_for_event(ev)
		id = ev.eventIdentifier
		date = ev.startDate.start_of_day
		section = sections.index(date)
		row = objs(date).index{ |e| EKEvent === e && e.eventIdentifier == id }
		[section,row].nsindexpath
	end

	def index_path_for_thing(thing)
		date = thing.startDate.start_of_day
		section = sections.index(date)
		row = objs(date).index(thing)
		return unless section and row
		[section,row].nsindexpath
	end

	def item_count_for_section n
		section(n).size
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
		@objs = {}
		return unless AuthenticationController.all_authed?

		Event.legit_events(timeframe, proc{ reload }).each do |ev|
			morning = ev.startDate.start_of_day
			section = @objs[morning] ||= []
			section << ev unless section.detect{ |existing| existing.title == ev.title and existing.startDate == ev.startDate }
		end
	end

	def sections
		timeframe_dates
	end

end
