class Friend < MotionDataWrapper::Model; end
class Image < MotionDataWrapper::Model; end

class EKEvent

	def record
		@record ||= Event.find_by_event_identifier(eventIdentifier)
		@record
	end

	def record!
		return record if record
		@record = Event.create(:event_identifier => eventIdentifier)
	end

	def dock_item
		@dock_item ||= DockItem.matching(self)
	end


	# TO FIX

	def friend_record
		record && record.friends.anyObject
	end

	def person_uid
		r = friend_record
		r && r.ab_record_id
	end

	def person_abrecord
		@person_abrecord ||= begin
			id = person_uid
			id && id > 0 && ABAddressBookGetPersonWithRecordID(AddressBook.address_book, id)
		end
	end

	def person
		person_abrecord && AddressBook::Person.new(AddressBook.address_book, person_abrecord)
	end

	def person_name
		person && person.composite_name
	end

    def uiimage
    	if img = record && record.image
    		i = img.image
    		i && UIImage.alloc.initWithData(i)
    	end
    end



    # def friend_image; record && record.friend_image; end

    def photo_or_linked_photo(person)
    	p = person.photo
    	return p if p
    	ABPersonCopyArrayOfAllLinkedPeople(person.ab_person).each do |linked_ab_record|
    		if ABPersonHasImageData(linked_ab_record)
    			return ABPersonCopyImageData(linked_ab_record)
    		end
    	end
    	nil
    end

    def person=(person)
    	@person_abrecord = nil
    	if !person and record
    		record.setFriends(NSSet.set)
    		record.image = nil if record.image and record.image.ab_record_id
    		if self.title =~ /^@/
    			self.title = nil
    			Event.save(self)
    		end
    	else
	    	friend_record = Friend.find_by_ab_record_id(person.uid)
	    	friend_record ||= Friend.create(:ab_record_id => person.uid, :name => person.composite_name, :mtime => Time.now)
	    	record!.addFriendsObject friend_record
	    	image_record = Image.find_by_ab_record_id(person.uid)
	    	image_record ||= Image.create(:ab_record_id => person.uid, :image => photo_or_linked_photo(person), :mtime => Time.now)	    	
    		fix_image_record(image_record) if !image_record.image
	    	record.image = image_record
    		if self.title =~ /^@/ || !self.title
    			self.title = "@#{person.composite_name}"
    			Event.save(self)
    		end
    	end
    	record.save
    	person
    end

    def fix_image_record image_record
    	if image_record.ab_record_id > 0
			record = ABAddressBookGetPersonWithRecordID(AddressBook.address_book, image_record.ab_record_id)
			person = record && AddressBook::Person.new(AddressBook.address_book, record)
			image_record.image = photo_or_linked_photo(person) if person
			image_record.save
		end
    end

    def default_image
		dock_item.title != 'DEFAULT' ? dock_item.uiimage : nil
    end

    def friends
    	record && record.friends
    end

    # TODO, recheck if no linked image and it's been a day. or if there is one and it's been a week
    def check_for_image?
    	img = record && record.image
    	img = nil if img and (!img.ab_record_id || img.ab_record_id==0) and !img.facebook_event_id
    	friends = record && record.friends
    	return true if !img and (!friends or friends.count == 0)
    	return true if img and !img.image and Time.now - img.mtime > 1.minutes
    	return false
    end


	def image(&callback)
		# return default_image
		linked_image = uiimage
		return linked_image if linked_image

		if check_for_image?
			# Event.possibly_fetch_background_image(self, callback) unless record and record.friend_ab_record_id and !record.friend_image
			url = self.URL && self.URL.absoluteString
			if url =~ /facebook\.com\/events\/(\d+)\/$/
				self.record!.image = Image.create(:facebook_event_id => $1, :mtime => Time.now)
				self.record.save
				fetch_facebook_image(callback)
				return default_image

			elsif organizer and not organizer.isCurrentUser and record = organizer.ABRecordWithAddressBook(AddressBook.address_book)
				# do we already have an image of the guy?
		    	if self.record!.image = Image.find_by_ab_record_id(record.uniqueId)
		    		friend_record = Friend.find_by_ab_record_id(person.uid)
		    		friend_record && self.record!.addFriendsObject(friend_record)
			    	self.record.save
			    	return self.record.image.image || default_image
			    else
			    	self.record!.image = Image.create(:ab_record_id => record.uniqueId, :mtime => Time.now)
			    	self.record.save
			    	fetch_organizer_image(record, callback)
			    end
			end
	    end
		default_image
	end

	def fetch_organizer_image record, callback
		Dispatch::Queue.concurrent.async do 
			self.person = AddressBook::Person.new(nil, record)
			Dispatch::Queue.main.async(&callback)
		end
	end

	def fb_reconnect &callback
	    FBSession.activeSession.closeAndClearTokenInformation
	    FBSession.activeSession = nil
	    FBSession.setActiveSession(nil)
        FBSession.renewSystemCredentials(proc{ |result, error|
        	return NSLog("error renewing: #{error.inspect} #{result.inspect}") if error
        	FBSession.openActiveSessionWithReadPermissions(nil, allowLoginUI:true, 
            	completionHandler:lambda{ |session, state, error| 
            		if error
						NSLog("FB errr: #{FBErrorUtility.userMessageForError(error)}")
					else
						callback.call
					end
                }
            )
        })
	end

	def fetch_facebook_image_with_retry(objid, params = '', &callback)
		token = FBSession.activeSession.accessTokenData.accessToken
		graphPhoto = "https://graph.facebook.com/#{objid}/picture?#{params}&access_token=#{token}"
		NSLog("FETCHING: #{graphPhoto}")
		BW::HTTP.get(graphPhoto) do |response|
			if response.ok?
				Dispatch::Queue.main.async do
					NSLog "got photo at #{response.url}"
					if response.url =~ /fbstatic/
						callback.call(nil)
					else
						callback.call(response.body)
					end
				end
			else
				NSLog("error response: #{response.body}")
				fb_reconnect{ fetch_facebook_image_with_retry(objid, params, &callback) } if response.body =~ /access token/
			end
		end
	end

	# TODO, also fetch organizers / inviter / friend face
	def fetch_facebook_image(callback)
		fetch_facebook_image_with_retry(record.image.facebook_event_id, "width=146&height=146") do |body|
			# TODO: if no body, the thing doesn't have an image... 
			#   mark the record and search for a fallback for the thing?
			if body
				record.image.image = body
				record.image.save
				NSLog("image saved")
				callback && Dispatch::Queue.main.async(&callback)
			end
		end

		# conn = FBRequestConnection.alloc.init
		# conn.errorBehavior = (FBRequestConnectionErrorBehaviorReconnectSession | FBRequestConnectionErrorBehaviorAlertUser | FBRequestConnectionErrorBehaviorRetry)
		# params = { "width"=>146, "height"=> 146 }
		# req = FBRequest.requestForGraphPath("#{record.image.facebook_event_id}/picture", parameters:params, HTTPMethod: 'GET')
		# conn.addRequest(req, completionHandler: lambda{ |conn, result, error|
		# 	if error
		# 		NSLog("error response: #{error.userInfo.inspect}")
		# 	else
		# 		record.image.image = urlResponse
		# 		record.image.save
		# 		NSLog("image saved")
		# 		callback && Dispatch::Queue.main.async(&callback)
		# 	end
		# })
		# conn.start

	end



	# delegated getters
	def is_hidden?; record && record.is_hidden; end

	# delegated setters
	def hide!; post is_hidden: true; end
	def delete!; Event.delete!(self); end
	def post options; Event.post eventIdentifier, options; end



	def reset_timer
		@my_cvc.update_timer_label self, nil if @my_cvc
		pause_timer if @timer
		@time_left = nil
		@end_time = nil
	end

	def start_timer
		@time_left ||= begin
			if title =~ /^(\d+)(m|h)\b/
				num = $1
				multiplier = ($2 == 'm' ? 60 : 60*60)
				num.to_i * multiplier
			else
				10.minutes
			end
		end
		@end_time = Time.now + @time_left

		@notification = UILocalNotification.alloc.init
		@notification.fireDate = @end_time
		@notification.alertBody = 'Done'
		@notification.soundName = UILocalNotificationDefaultSoundName
		UIApplication.sharedApplication.scheduleLocalNotification @notification
		@timer = NSTimer.scheduledTimerWithTimeInterval(1.0, target: self, selector: :update_timer, userInfo: nil, repeats: true)

		endDate = @end_time
		Event.save(self)
	end

	def timer_running?
		@timer
	end

	def pause_timer
		@timer.invalidate
		@timer = nil
		UIApplication.sharedApplication.cancelLocalNotification @notification
		@notification = nil
	end

	def update_timer
		return unless @end_time
		@time_left = @end_time - Time.now
		if @time_left >= 0
			@my_cvc.update_timer_label self, @time_left.to_i
		else
			reset_timer
		end
	end

	def start_stop_timer cvc
		@my_cvc ||= cvc
		@timer ? pause_timer : start_timer

		# do I have a timer? if so pause it
		# every second that passes, find my cell and encourage it to display a thing
		# set a localnotification
	end

	# etc

	def fast_delete?
		facebook? or raw_from_dock_item? or (!self.title && !self.notes)
	end

	def facebook?
		self.URL && self.URL.host =~ /facebook/
	end

	def raw_from_dock_item?
		return true if dock_item.matcher_type == :regex && (!notes || notes.length == 0)
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
			return UIImage.imageNamed('q.png')
		end
	end

end


class Event < MotionDataWrapper::Model


	##########
	# calendar

	def self.event_store
		@event_store ||= EKEventStore.alloc.init
	end

	def self.add_event start_time, friend = nil, title = nil
		@event_store ||= EKEventStore.alloc.init
		ev = EKEvent.eventWithEventStore(@event_store)
		ev.startDate = start_time
		ev.endDate = start_time + 2.hours
		ev.title = title
		ev.setCalendar(@event_store.defaultCalendarForNewEvents)
		error = Pointer.new('@')
		@event_store.saveEvent(ev, span:EKSpanThisEvent, commit:true, error:error)
		ev.person = friend if friend
		ev
	end

	def self.save ev
		@dock_item = nil
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
			next if ev.is_hidden? and ev.is_hidden? != 0
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
end
