class Contact < Nitron::Model
end

class Event < Nitron::Model


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
