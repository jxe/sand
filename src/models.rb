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
		eve: 18...21,
		night: 21...24
	}

	LONGER = {
		predawn: 'predawn',
		dawn: 'dawn',
		bfst: 'breakfast',
		morn: 'morning',
		lunch: 'lunch',
		aft: 'afternoon',
		hpy_hr: 'happy hour',
		eve: 'evening',
		night: 'night'
	}

	HOUR_RANGES_REV = {
		0 => :predawn,
		1 => :predawn,
		2 => :predawn,
		3 => :predawn,
		4 => :predawn,
		5 => :dawn,
		6 => :dawn,
		7 => :dawn,
		8 => :bfst,
		9 => :bfst,
		10 => :morn,
		11 => :morn,
		12 => :lunch,
		13 => :lunch,
		14 => :aft,
		15 => :aft,
		16 => :hpy_hr,
		17 => :hpy_hr,
		18 => :eve,
		19 => :eve,
		20 => :eve,
		21 => :night,
		22 => :night,
		23 => :night
	}

	def day_of_week_label
		return "TODAY" if today?
		return "TOMORROW" if same_day?(NSDate.tomorrow)
		return strftime("%A").upcase
	end

	def time_of_day_label
		HOUR_RANGES_REV[hour]
	end

	def longer_time_of_day_label
		LONGER[HOUR_RANGES_REV[hour]]
	end
end
