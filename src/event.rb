class Event < Nitron::Model


	##########
	# calendar

	def self.add_event start_time, friend, title = nil
		@event_store ||= EKEventStore.alloc.init
		ev = EKEvent.eventWithEventStore(@event_store)
		ev.startDate = start_time
		ev.endDate = start_time + 2.hours
		ev.title = title || (friend && "with #{friend.composite_name}") || "New event"
		ev.setCalendar(@event_store.defaultCalendarForNewEvents)
		error = Pointer.new('@')
		@event_store.saveEvent(ev, span:EKSpanThisEvent, commit:true, error:error)
		Event.assign(ev.eventIdentifier, friend) if friend
		ev
	end

	def self.save ev
		error = Pointer.new('@')
		@event_store.saveEvent(ev, span:EKSpanThisEvent, commit:true, error:error)
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

	def self.legit_events_matching(startDate, title)
		legit_events([startDate, startDate + 2.hours]).select{ |ev| ev.title == title }
	end


	##########
	# setters

	def self.hide event_id
		post event_id, is_hidden: true
	end

	def self.hide_matching ev
		legit_events_matching(ev.startDate, ev.title).each do |e|
			post e.eventIdentifier, is_hidden: true
		end
	end

	def self.assign event_id, person
		puts "assign: eventIdentifier: #{event_id}, friend_ab_record_id: #{person.uid}"
		post event_id,
			friend_ab_record_id: person.uid,
			friend_name: person.composite_name,
			friend_image: person.photo,
	end

	def self.unassign event_id
		post event_id,
			friend_ab_record_id: nil,
			friend_name: nil,
			friend_image: nil,
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

	def self.friend_ab_record_id(ev)
		puts "event_identifier: #{ev.eventIdentifier}"
		event = find_by_event_identifier(ev.eventIdentifier)
		puts "event: #{event.inspect}"
		return event && event.friend_ab_record_id
	end

	def self.refresh(ev)
		event = find_by_event_identifier(ev.eventIdentifier)
		event and event.destroy
	end


	def self.delete!(ev)
		@event_store ||= EKEventStore.alloc.init
		error = Pointer.new('@')
		@event_store.removeEvent(ev, span:EKSpanThisEvent, commit:true, error:error)
	end

	def self.is_hidden? event_id
		event = find_by_event_identifier(event_id)
		event && event.is_hidden
	end



	##############################
	#### MOVE TO DISPLAYMODEL ####

	def self.image_from_time(t)
		case t
		when :bfst;   return UIImage.imageNamed('img/tod/breakfast.jpg')
		when :lunch;  return UIImage.imageNamed('img/tod/lunch.jpg')
		when :eve;    return UIImage.imageNamed('img/tod/evening.jpg')
		when :night;  return UIImage.imageNamed('img/tod/night.jpg')
		when :hpy_hr;  return UIImage.imageNamed('img/tod/happy_hour.jpg')
		when :dawn;  return UIImage.imageNamed('img/tod/dawn.jpg')
		when :aft;  return UIImage.imageNamed('img/tod/afternoon.jpg')
		end
	end


	def self.image(ev, &callback)
		if e = find_by_event_identifier(ev.eventIdentifier)
			return UIImage.alloc.initWithData(e.friend_image) if e.friend_image
		end

		possibly_fetch_background_image(ev, callback) unless e and e.friend_ab_record_id and !e.friend_image

		image_from_title(ev.title) || image_from_time(ev.startDate.time_of_day_label)
	end



	#############################
	#### MOVE TO DOCKITEM.RB ####

	def self.suggestions_url(ev, loc)
		NSLog "pushing street address: #{loc}"
		# loc = loc.stringByAddingPercentEscapesUsingEncoding(NSUTF8StringEncoding)
		# loc2 = CFURLCreateStringByAddingPercentEscapes(nil, loc, nil, "!*'();:@&=+$,/?%#[]", KCFStringEncodingUTF8)
		loc2 = loc.gsub("\n"," ").sub(" United States", "").gsub(/\u200E|\s/, '%20')
		NSLog "%@", "converted to: #{loc2}"
		raw = raw_suggestions_url(ev)
		raw.sub("%%", loc2.strip)
	end

	def self.raw_suggestions_url(ev)
		time_label = ev.startDate.time_of_day_label

		case ev.title
		when /sunshine|exercise|quiet/
			return "http://www.yelp.com/search?find_desc=park+#{ev.title}&find_loc=%%"
		when /work/
			return "http://www.yelp.com/search?find_desc=cafe+working&find_loc=%%"
		when /cooking/
			return "http://www.pinterest.com/fooddotcom/recipe-of-the-day/"
		end

		case time_label
		when :bfst
			return "http://www.yelp.com/search?find_desc=breakfast&find_loc=%%"
		when :lunch
			return "http://www.yelp.com/search?find_desc=lunch&find_loc=%%"
		when :eve
			return "http://www.yelp.com/search?find_desc=dinner&find_loc=%%"
		when :night
			return "http://www.yelp.com/search?find_desc=bar&find_loc=%%"
		end

		return "http://www.yelp.com"
	end

	def self.painted?(ev)
		return %{ creative exercise sweet }.include?(ev.title || '?')
	end

	def self.image_from_title(title)
		case title
		when /friend/;         return UIImage.imageNamed('friends.jpg')
		when /appt/;          return UIImage.imageNamed('q.png')

		when /cooking/;        return UIImage.imageNamed('img/activities/cooking.jpg')
		when /exercise/;       return UIImage.imageNamed('img/activities/exercise.jpg')
		when /sunshine|fresh/; return UIImage.imageNamed('img/activities/sunshine.jpg')
		when /creative|work/;  return UIImage.imageNamed('img/activities/work.jpg')
		when /quiet/;          return UIImage.imageNamed('img/activities/quiet.jpg')
		end
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

	def self.possibly_fetch_background_image(ev, callback)
		url = ev.URL && ev.URL.absoluteString
		NSLog "ev.URL: #{url.inspect}"
		if url =~ /facebook\.com\/events\/(\d+)\/$/
			fbId = $1
			token = FBSession.activeSession.accessTokenData.accessToken
			graphPhoto = "https://graph.facebook.com/#{fbId}/picture?width=146&height=146&access_token=#{token}"
			NSLog "asking for photo: #{graphPhoto}"
			BW::HTTP.get(graphPhoto) do |response|
			  
  				if response.ok? and imagedata = response.body
					# NSLog "got imagedata: #{imagedata.inspect}"
					post ev.eventIdentifier,
						friend_image: imagedata
					Dispatch::Queue.main.async(&callback)
				else
					NSLog "error response: #{response.to_s}"
				end

			end

		elsif ev.organizer and not ev.organizer.isCurrentUser
			# url = ev.organizer.URL
			Dispatch::Queue.concurrent.async do 
				record = ev.organizer.ABRecordWithAddressBook(AddressBook.address_book)
				person = record && AddressBook::Person.new(nil, record)
				e = person && assign(ev.eventIdentifier, person)
				Dispatch::Queue.main.async(&callback) if e and e.friend_image
			end
		end
	end
end
