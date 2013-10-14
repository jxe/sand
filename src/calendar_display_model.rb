Placeholder = Struct.new(:label, :startDate)

class CalendarDisplayModel

	##############################################
	# mappings between indexpaths, sections, rows,
	# calendar events, droptarget placeholders

	# things[date] = [placeholders_and_events...]
	attr_reader :things
	attr_reader :date_open
	attr_reader :special_placeholder

	TIMES = %w{ bfst morn lunch aft hpy_hr eve night }


	######
	# managing placeholder appearance/disappearance

	def hover section, thing_to_cover = nil
		thing_to_cover = nil if Placeholder === thing_to_cover
		date = section && sections[section]
		if @date_open == date
			puts "@covering_thing: #{@covering_thing.inspect}; thing_to_cover: #{thing_to_cover.inspect}"
			if @covering_thing && @covering_thing == thing_to_cover && @special_placeholder
				# flip them!
				puts "flipping"
				idx1 = objs(@date_open).index(thing_to_cover)
				idx2 = objs(@date_open).index(@special_placeholder)
				objs(@date_open)[idx1] = @special_placeholder
				objs(@date_open)[idx2] = thing_to_cover
				puts "inserted1: #{objs(@date_open)[idx1].inspect}"
				puts "inserted2: #{objs(@date_open)[idx2].inspect}"

			else
				puts "changing"
				maybe_remove_special_placeholder if @special_placeholder
				maybe_add_special_placeholder(thing_to_cover)

			end

		elsif !@date_open
			@date_open = date
			add_basic_placeholders
			maybe_add_special_placeholder(thing_to_cover)

		elsif !section
			remove_all_placeholders
			@date_open = date

		else
			remove_all_placeholders
			@date_open = date
			add_basic_placeholders
			maybe_add_special_placeholder(thing_to_cover)

		end
	end

	def maybe_add_special_placeholder(thing_to_cover)
		if not thing_to_cover
			@covering_thing = nil
			@special_placeholder = nil
			return
		end

		# return if @covering_thing == thing_to_cover

		@covering_thing = thing_to_cover
		idx = objs(@date_open).index(thing_to_cover)
		date = thing_to_cover.startDate
		@special_placeholder = Placeholder.new(date.time_of_day_label, thing_to_cover.startDate)
		objs(@date_open).insert(idx, @special_placeholder)
		# matches = objs(@date_open).select{ |x| x.startDate == @time_of_day_open }
		# existing_placeholders = matches.detect{ |x| Placeholder === x }
		# if existing_placeholders
		# else
		# 	idx = objs(@date_open).index(matches.first)
		# end
	end





	def maybe_remove_special_placeholder
		return unless @special_placeholder
		objs(@date_open).delete(@special_placeholder)
		@special_placeholder = nil
	end

	def add_basic_placeholders
		TIMES.each do |label|
			t = @date_open + NSDate::HOUR_RANGES[label.to_sym].begin.hours
			next unless Time.now - t < 1.hour
			next if objs(@date_open).any?{ |e| e.startDate == t }
			objs(@date_open) << Placeholder.new(label, t)
		end
		@objs[@date_open] = objs(@date_open).sort_by{ |x| x.startDate }
	end

	def remove_all_placeholders
		objs(@date_open).reject!{ |p| Placeholder === p }
		@special_placeholder = nil
	end



	######
	# creating/removing events

	def add_event_at_placeholder(pl, person, text)
		start_time = pl.startDate
		date = start_time.start_of_day
		ev = Event.add_event(start_time, person, text)
		@objs[date][@objs[date].index(pl)] = ev
	end

	def move_to_placeholder(ev, placeholder)
		date = ev.startDate.start_of_day
		old_loc = objs(date).index(ev)
		new_loc = objs(date).index(placeholder)
		ev.startDate = placeholder.startDate
		Event.save(ev)
		objs(date)[new_loc] = ev
		objs(date).delete_at(old_loc)
	end

	def remove_event(ev)
		objs(ev.startDate.start_of_day).delete(ev)
		if ev.calendar.allowsContentModifications
	  		Event.delete!(ev)
  		else
  			Event.hide_matching(ev)
  		end
	end



	######
	# basic access

	def objs d; @objs[d] || []; end

	def special_placeholder_position
		@special_placeholder && index_path_for_thing(@special_placeholder)
	end

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
		# puts "thing: #{p.row}: #{section(p.section).inspect}"
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
