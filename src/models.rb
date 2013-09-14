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
