class UpcomingController < Nitron::TableViewController
	collection { Appointment.all }
end
