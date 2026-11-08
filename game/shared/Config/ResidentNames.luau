--!strict
--[[
	ResidentNames: name pools for residents (bible Section 11: named people). Brightwater is an
	original 1950s American small town, so the names are period ones from many backgrounds.
	Nicknames are for Rare and Legendary residents ("Rosie 'Rivets' Kowalski"). A name is
	First + Last, never repeated within a run while the pool lasts.
]]

local Check = require(script.Parent.Parent.Utilities.Check)

local Names = Check.array(Check.string(24, { min = 2, pattern = "^[%a][%a' %-%.]*$" }), 300)

return {
	Schema = Check.shape({ Names = Names }),
	Order = { "First", "Last", "Nickname" },
	Entries = {
		First = {
			Names = {
				"Abe", "Ada", "Agnes", "Al", "Alice", "Alma", "Amos", "Angelo", "Annie", "Archie", "Arlene", "Arthur",
				"Audrey", "Bea", "Benny", "Bernice", "Bert", "Betty", "Bill", "Billie", "Bobbie", "Bud", "Buster",
				"Carl", "Carmen", "Cecil", "Charlotte", "Chester", "Clara", "Clarence", "Cliff", "Connie", "Cora",
				"Dale", "Dolores", "Donna", "Dot", "Doug", "Earl", "Edith", "Eddie", "Edna", "Elena", "Eli", "Ella",
				"Elmer", "Elsie", "Ernie", "Esther", "Ethel", "Eugene", "Faye", "Frank", "Freddie", "Gene", "Georgia",
				"Gertie", "Gil", "Gloria", "Gus", "Hank", "Harold", "Harriet", "Hazel", "Helen", "Herb", "Hiro",
				"Homer", "Howard", "Ida", "Irene", "Irving", "Jack", "Jean", "Jimmy", "Joan", "Joe", "Josie", "June",
				"Kay", "Kenji", "Lena", "Leon", "Leroy", "Lillian", "Lou", "Louise", "Luis", "Mabel", "Mae", "Marge",
				"Marvin", "Maxine", "Mel", "Mickey", "Mildred", "Milt", "Minnie", "Nadine", "Nell", "Norma", "Ollie",
				"Opal", "Oscar", "Otis", "Pat", "Pearl", "Pete", "Phyllis", "Ray", "Rita", "Roscoe", "Ruby", "Rudy",
				"Ruth", "Sal", "Sam", "Shirley", "Sid", "Stan", "Stella", "Sue", "Teddy", "Thelma", "Tomas", "Velma",
				"Vera", "Vern", "Viola", "Virgil", "Wally", "Walt", "Wanda", "Wendell", "Wilma", "Winnie", "Woody",
				"Yuki", "Zelda",
			},
		},
		Last = {
			Names = {
				"Abbott", "Alvarez", "Anders", "Baker", "Banks", "Barlow", "Becker", "Bell", "Bishop", "Brennan",
				"Brooks", "Bui", "Caldwell", "Carver", "Castillo", "Chen", "Clark", "Cobb", "Coleman", "Costa",
				"Crane", "Cruz", "Delgado", "Dixon", "Doyle", "Duffy", "Dunn", "Ellis", "Engel", "Esposito", "Farrell",
				"Fischer", "Fitz", "Flores", "Foster", "Fujita", "Gallo", "Garza", "Gibbs", "Gomez", "Grady", "Graves",
				"Haas", "Hale", "Harlan", "Hayes", "Hicks", "Holloway", "Hooper", "Hughes", "Hutch", "Ibarra", "Jansen",
				"Jennings", "Kaplan", "Keller", "Kim", "Kowalski", "Kramer", "Lambert", "Lang", "Larsen", "Lee", "Lowry",
				"Lund", "Maddox", "Malone", "Marchetti", "Marsh", "Mendez", "Meyer", "Miller", "Moreau", "Morales",
				"Murphy", "Nakamura", "Nash", "Novak", "Nowak", "O'Brien", "Okafor", "Olsen", "Ortiz", "Owens", "Park",
				"Patel", "Pike", "Price", "Quinn", "Ramos", "Reyes", "Rhodes", "Riley", "Rossi", "Russo", "Sato",
				"Schmidt", "Shaw", "Silva", "Sloane", "Sorensen", "Stone", "Sullivan", "Tanaka", "Torres", "Tucker",
				"Vale", "Vargas", "Vaughn", "Walsh", "Ward", "Webb", "Whitaker", "Wilder", "Wong", "Yates", "Zielinski",
			},
		},
		Nickname = {
			Names = {
				"Ace", "Bolts", "Buttons", "Chipper", "Copper", "Doc", "Dynamite", "Fizz", "Flash", "Gadget", "Gears",
				"Hammer", "Hotshot", "Lucky", "Moxie", "Patches", "Pepper", "Rivets", "Rocket", "Sarge", "Scoop",
				"Slim", "Smokey", "Socket", "Sparky", "Sprocket", "Sunny", "Tiny", "Torch", "Tumbler", "Whistle",
			},
		},
	},
}
