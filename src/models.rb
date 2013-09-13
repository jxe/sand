class Contact < Nitron::Model
end


class NSDate
	HOUR_RANGES = {
		predawn: 0...5,
		dawn: 5...8,
		bfst: 8...10,
		morn: 10...12,
		lunch: 12...14,
		aft: 14...16,
		hpy_hr: 16...18,
		dinner: 18...21,
		night: 21...24
	}
	def day_of_week_label
		return "TODAY" if today?
		return "TOMORROW" if same_day?(NSDate.tomorrow)
		return strftime("%A").upcase
	end

	def time_of_day_label
			HOUR_RANGES.each do |k,v|
			return k if v.include? hour
		end
	end
end


class Event < Nitron::Model


	##########
	# calendar

	def self.add_event start_time, friend, title = nil
		puts "add_event: #{start_time.inspect} #{friend.inspect} #{title.inspect}"
		@event_store ||= EKEventStore.alloc.init
		ev = EKEvent.eventWithEventStore(@event_store)
		ev.startDate = start_time
		ev.endDate = start_time + 2.hours
		ev.title = title || (friend && "with #{friend.composite_name}") || "New event"
		ev.setCalendar(@event_store.defaultCalendarForNewEvents)
		error = Pointer.new('@')
		@event_store.saveEvent(ev, span:EKSpanThisEvent, commit:true, error:error)
		Event.assign(ev.eventIdentifier, friend) if friend
	end

	def self.fetch_events start_date, end_date, cb = nil
		@event_store ||= EKEventStore.alloc.init
	 	p = @event_store.predicateForEventsWithStartDate(start_date, endDate: end_date, calendars: nil)
		@event_store.eventsMatchingPredicate(p)
	end

	def self.legit_events(tf, cb = nil)
		events = fetch_events(*tf, cb) || []
		puts "#{events.length} events from cal"
		events.select do |ev|
			next if ev.allDay? or ev.availability == EKEventAvailabilityFree
			next if ev.endDate.timeIntervalSinceDate(ev.startDate) > 18.hours
			next if ev.startDate.timeIntervalSinceNow < -20.hours
			next if Event.is_hidden?(ev.eventIdentifier)
			true
		end
	end



	##########
	# setters

	def self.hide event_id
		post event_id, is_hidden: true
	end

	def self.assign event_id, person
		post event_id,
			friend_ab_record_id: person.uid,
			friend_name: person.composite_name,
			friend_image: person.photo,
	end


	##########
	# getters

	def self.unlinked_painted?(ev)
		return painted?(ev) && unlinked?(ev)
	end

	def self.unlinked?(ev)
		event = find_by_event_identifier(ev.eventIdentifier)
		return !event || !event.friend_ab_record_id
	end

	def self.delete!(ev)
		@event_store ||= EKEventStore.alloc.init
		error = Pointer.new('@')
		@event_store.removeEvent(ev, span:EKSpanThisEvent, commit:true, error:error)
	end

	def self.painted?(ev)
		return %{ creative exercise sweet }.include?(ev.title || '?')
	end

	def self.is_hidden? event_id
		event = find_by_event_identifier(event_id)
		event && event.is_hidden
	end

	def self.image(ev, &callback)
		if e = find_by_event_identifier(ev.eventIdentifier)
			return UIImage.alloc.initWithData(e.friend_image) if e.friend_image
			return nil if e.friend_ab_record_id
		end

		fetch_image_for_organizer(ev, callback)

		case ev.title
		when 'creative'; return UIImage.imageNamed('creative.png')
		when 'sweet'; return UIImage.imageNamed('sweet.png')
		when 'exercise'; return UIImage.imageNamed('exercise.png')
		end

		nil
	end



	##########
	# utils

	def self.post event_id, params = {}
		unless e = find_by_event_identifier(event_id)
			params[:event_identifier] = event_id
			create(params)
		else
			params.each do |keyPath, value|
    	        e.setValue(value, forKey:keyPath)
        	end
        	e.save
        end
	end

	def self.fetch_image_for_organizer(ev, callback)
		return unless ev.organizer and not ev.organizer.isCurrentUser
		# url = ev.organizer.URL
		Dispatch::Queue.concurrent.async do 
			record = ev.organizer.ABRecordWithAddressBook(AddressBook.address_book)
			person = record && AddressBook::Person.new(nil, record)
			e = person && assign(ev.eventIdentifier, person)
			Dispatch::Queue.main.async(&callback) if e and e.friend_image
		end
	end
end
