class Friend < Nitron::Model
	def self.all
    	order("added")
 	end
end
