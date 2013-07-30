class UpcomingController < UICollectionViewController

	def viewDidLoad
		super
		load_events
		self.collectionView.delegate = self
		self.collectionView.dataSource = self
		self.collectionView.gestureRecognizers[2].addTarget(self, action: :longPress)
		@person_images = {}
	end

	def add_hidden_event event_id
	end

	def hidden_events
		NSUserDefaults['hidden_events'] ||= []
	end

	def longPress
		UIActionSheet.alert 'Hmm', buttons: ['Cancel', 'Link friend', 'Hide'],
		  cancel: proc { },
		  success: proc { |pressed| }
	end

	def load_events
		IOSCalendar.request_permission
		events = IOSCalendar.events(nil, Time.now - 2.hours, Time.now + 9.days) || []
		puts "#{events.length} events from cal"
		@sections = {}
		events.each do |ev|
			next if ev.allDay? or ev.availability == EKEventAvailabilityFree
			next if ev.endDate.timeIntervalSinceDate(ev.startDate) > 18.hours
			morning = ev.startDate.start_of_day
			# puts "earlier" if ev.startDate.timeIntervalSinceNow < -120*60
			# next if ev.startDate.timeIntervalSinceNow < -120*60
			section = @sections[morning] ||= []
			section << ev unless section.detect{ |existing| existing.title == ev.title }
		end
		too_early = @sections.keys.select{ |d| d.timeIntervalSinceNow < -20*60*60 }
		too_early.each{ |d| @sections.delete d }
		@section_order = @sections.keys.sort
	end

	def numberOfSectionsInCollectionView(cv)
		@section_order.length
	end

	def collectionView(cv, numberOfItemsInSection: section)
		s = @section_order[section]
		# return 0 if s.timeIntervalSinceNow < -120*60
		@sections[s].length || 0
	end

	def collectionView(cv, cellForItemAtIndexPath: path)
		s = @sections[@section_order[path.section]]
		ev = s[path.row]
		return nil unless ev
		cell = cv.dequeueReusableCellWithReuseIdentifier('Appt', forIndexPath:path)
		imageview = cell.contentView.viewWithTag(100)
		timelabel = cell.contentView.viewWithTag(101)
		personlabel = cell.contentView.viewWithTag(102)

		# cell.contentView.viewWithTag(0).image = nil
		imageview.image = nil

		# time of day
		timelabel.text = time_of_day(ev.startDate)
		
		# title 
		personlabel.text = ev.title

		return cell unless ev.organizer and !ev.organizer.isCurrentUser

		# image
		personlabel.text = ev.organizer.name.split[0]
		cached_image = @person_images[ev.organizer.URL]

		if cached_image and cached_image != 'loading' and cached_image != 'none'
			imageview.image = cached_image
		elsif !cached_image
			cached_image = @person_images[ev.organizer.URL] = 'loading'

			queue = Dispatch::Queue.concurrent
			queue.async do 
				record = ev.organizer.ABRecordWithAddressBook(AddressBook.address_book)
				if record
					person = AddressBook::Person.new(nil, record)
					# personlabel.text = person.first_name
					if image = person.photo
						imageview.image = @person_images[ev.organizer.URL] = UIImage.alloc.initWithData(image)
					else
						cached_image = @person_images[ev.organizer.URL] = 'none'
					end
				end
			end
		end

		cell
	end

	def day_of_week t
		return "TODAY" if t.today?
		return "TOMORROW" if t.same_day?(NSDate.tomorrow)
		return t.strftime "%A     (%m/%d)"
	end

	def time_of_day t
		return 'DAWN' if t.hour < 8
		return 'BFST' if t.hour < 10
		return 'MORN'  if t.hour < 12
		return 'LNCH' if t.hour < 14
		return 'AFT'   if t.hour < 16
		return 'HPY HR' if t.hour < 18
		return 'EVE'   if t.hour < 21
		return 'LATE'

		# .string_with_format("h:mma")
	end

	def collectionView(cv, didSelectItemAtIndexPath:path)
		s = @sections[@section_order[path.section]]
		ev = s[path.row]
		puts "looked up event for eventViewController"
		return false unless ev
		puts "pushing eventViewController"
		eventViewController = EKEventViewController.alloc.init
		eventViewController.event = ev
		eventViewController.allowsEditing = true
		self.navigationController.pushViewController(eventViewController, animated: true)
	end

	def collectionView(cv, viewForSupplementaryElementOfKind:kind, atIndexPath:path)
		return unless kind == UICollectionElementKindSectionHeader
		view = cv.dequeueReusableSupplementaryViewOfKind(kind, withReuseIdentifier:'Section', forIndexPath:path)
		section_date = @section_order[path.section]
		view.subviews[0].text = day_of_week(section_date)
		view
	end
end
