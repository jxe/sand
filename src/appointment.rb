class Contact < MotionDataWrapper::Model; end

class EKEvent

	def record
		@record ||= Event.find_by_event_identifier(eventIdentifier)
	end

	def dock_item
		@dock_item ||= DockItem.matching(self)
	end

	# delegated getters
	def is_hidden?; record && record.is_hidden; end
	def person_uid; record && record.friend_ab_record_id; end

	# delegated setters
	def hide!; post is_hidden: true; end
	def delete!; Event.delete!(self); end
	def post options; Event.post eventIdentifier, options; end


	# related persons

	def person=(person)
		post friend_ab_record_id: person.uid,
			 friend_name: person.composite_name,
			 friend_image: person.photo,
	end


	def person_abrecord
		person_abrecord ||= (person_uid && ABAddressBookGetPersonWithRecordID(AddressBook.address_book, person_uid))
	end

	def person
		person_abrecord && AddressBook::Person.new(AddressBook.address_book, person_abrecord)
	end

	def person_name
		person && person.composite_name
	end



	# etc

	def fast_delete?
		facebook? or raw_from_dock_item?
	end

	def facebook?
		self.URL && self.URL.host =~ /facebook/
	end

	def raw_from_dock_item?
		dock_item.matcher_type == :regex && !notes
		title != 'DEFAULT' && !dock_item.is_hidden && !notes
	end

	def hide_matching!
		Event.legit_events_matching(startDate, title).each do |e|
			e.post is_hidden: true
		end
	end



	# images

	def image_from_time
		case t = startDate.time_of_day_label
		when :dawn;  return UIImage.imageNamed('img/tod/dawn.jpg')
		when :bfst;   return UIImage.imageNamed('img/tod/breakfast.jpg')
		when :morn;  return UIImage.imageNamed('img/tod/breakfast.jpg')
		when :lunch;  return UIImage.imageNamed('img/tod/lunch.jpg')
		when :aft;  return UIImage.imageNamed('img/tod/afternoon.jpg')
		when :hpy_hr;  return UIImage.imageNamed('img/tod/happy_hour.jpg')
		when :eve;    return UIImage.imageNamed('img/tod/evening.jpg')
		when :night;  return UIImage.imageNamed('img/tod/night.jpg')
		else
			return UIImage.imageNamed('img/tod/night.jpg')
		end
	end

	def image(&callback)
		return UIImage.alloc.initWithData(record.friend_image) if record && record.friend_image
		Event.possibly_fetch_background_image(self, callback) unless record and record.friend_ab_record_id and !record.friend_image
		dock_item.title != 'DEFAULT' ? dock_item.uiimage : image_from_time
	end

end


class Event < MotionDataWrapper::Model


	##########
	# calendar

	def self.event_store
		@event_store ||= EKEventStore.alloc.init
	end

	def self.add_event start_time, friend, title = nil
		@event_store ||= EKEventStore.alloc.init
		ev = EKEvent.eventWithEventStore(@event_store)
		ev.startDate = start_time
		ev.endDate = start_time + 2.hours
		ev.title = title || (friend && "with #{friend.composite_name}") || "New event"
		ev.setCalendar(@event_store.defaultCalendarForNewEvents)
		error = Pointer.new('@')
		@event_store.saveEvent(ev, span:EKSpanThisEvent, commit:true, error:error)
		ev.person = friend if friend
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
			next if ev.is_hidden?
			true
		end
	end

	def self.legit_events_matching(startDate, title)
		legit_events([startDate, startDate + 2.hours]).select{ |ev| ev.title == title }
	end



	##########
	# getters

	def self.refresh(ev)
		event = find_by_event_identifier(ev.eventIdentifier)
		event and event.destroy
	end


	def self.delete!(ev)
		@event_store ||= EKEventStore.alloc.init
		error = Pointer.new('@')
		@event_store.removeEvent(ev, span:EKSpanThisEvent, commit:true, error:error)
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
		if url =~ /facebook\.com\/events\/(\d+)\/$/
			fbId = $1
			token = FBSession.activeSession.accessTokenData.accessToken
			graphPhoto = "https://graph.facebook.com/#{fbId}/picture?width=146&height=146&access_token=#{token}"
			NSLog "asking for photo: #{graphPhoto}"
			BW::HTTP.get(graphPhoto) do |response|
			  
  				if response.ok? and imagedata = response.body
					# NSLog "got imagedata: #{imagedata.inspect}"
					ev.post friend_image: imagedata
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
