LocationSystem
	.addLocation(
		LocationConfig.new("camodo")
	)
	.addLocation(
		LocationConfig.new("key_chemical")
			:addProduction(RecipeDatabase.chemical_plant_t1)
	)
