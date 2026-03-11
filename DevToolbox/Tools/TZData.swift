// MARK: - TZEntry

struct TZEntry: Identifiable {
    let tzID: String
    let city: String
    let country: String
    let abbr: String        // space-separated abbreviations for search
    let also: [String]      // alternate city/region names
    var id: String { tzID + "|" + city }
}

// MARK: - Curated timezone list (west → east)

extension TZEntry {
    static let curated: [TZEntry] = [
        // UTC / GMT
        TZEntry(tzID: "UTC",                            city: "UTC",              country: "Universal",              abbr: "UTC",          also: ["Universal", "GMT"]),
        TZEntry(tzID: "GMT",                            city: "GMT",              country: "Universal",              abbr: "GMT",          also: ["Greenwich"]),
        // Americas
        TZEntry(tzID: "Pacific/Honolulu",               city: "Honolulu",         country: "United States",          abbr: "HST",          also: ["Hawaii"]),
        TZEntry(tzID: "America/Anchorage",              city: "Anchorage",        country: "United States",          abbr: "AKST AKDT",    also: ["Alaska"]),
        TZEntry(tzID: "America/Los_Angeles",            city: "Los Angeles",      country: "United States",          abbr: "PST PDT",      also: ["San Francisco", "Seattle", "Portland"]),
        TZEntry(tzID: "America/Vancouver",              city: "Vancouver",        country: "Canada",                 abbr: "PST PDT",      also: ["British Columbia"]),
        TZEntry(tzID: "America/Tijuana",                city: "Tijuana",          country: "Mexico",                 abbr: "PST PDT",      also: ["Baja California"]),
        TZEntry(tzID: "America/Phoenix",                city: "Phoenix",          country: "United States",          abbr: "MST",          also: ["Arizona"]),
        TZEntry(tzID: "America/Denver",                 city: "Denver",           country: "United States",          abbr: "MST MDT",      also: ["Colorado", "Salt Lake City"]),
        TZEntry(tzID: "America/Chicago",                city: "Chicago",          country: "United States",          abbr: "CST CDT",      also: ["Dallas", "Houston"]),
        TZEntry(tzID: "America/Mexico_City",            city: "Mexico City",      country: "Mexico",                 abbr: "CST CDT",      also: ["Guadalajara", "Monterrey"]),
        TZEntry(tzID: "America/New_York",               city: "New York",         country: "United States",          abbr: "EST EDT",      also: ["Boston", "Washington", "Miami", "Atlanta"]),
        TZEntry(tzID: "America/Toronto",                city: "Toronto",          country: "Canada",                 abbr: "EST EDT",      also: ["Ottawa", "Montreal"]),
        TZEntry(tzID: "America/Bogota",                 city: "Bogotá",           country: "Colombia",               abbr: "COT",          also: ["Bogota"]),
        TZEntry(tzID: "America/Lima",                   city: "Lima",             country: "Peru",                   abbr: "PET",          also: []),
        TZEntry(tzID: "America/Caracas",                city: "Caracas",          country: "Venezuela",              abbr: "VET",          also: []),
        TZEntry(tzID: "America/Halifax",                city: "Halifax",          country: "Canada",                 abbr: "AST ADT",      also: ["Atlantic"]),
        TZEntry(tzID: "America/Santiago",               city: "Santiago",         country: "Chile",                  abbr: "CLT CLST",     also: []),
        TZEntry(tzID: "America/Sao_Paulo",              city: "São Paulo",        country: "Brazil",                 abbr: "BRT BRST",     also: ["Sao Paulo", "Rio de Janeiro"]),
        TZEntry(tzID: "America/Argentina/Buenos_Aires", city: "Buenos Aires",     country: "Argentina",              abbr: "ART",          also: []),
        TZEntry(tzID: "America/St_Johns",               city: "St. John's",       country: "Canada",                 abbr: "NST NDT",      also: ["Newfoundland"]),
        // Atlantic
        TZEntry(tzID: "Atlantic/Cape_Verde",            city: "Praia",            country: "Cape Verde",             abbr: "CVT",          also: ["Cabo Verde"]),
        TZEntry(tzID: "Atlantic/Azores",                city: "Ponta Delgada",    country: "Portugal",               abbr: "AZOT AZOST",   also: ["Azores"]),
        // Europe
        TZEntry(tzID: "Atlantic/Reykjavik",             city: "Reykjavik",        country: "Iceland",                abbr: "GMT",          also: []),
        TZEntry(tzID: "Europe/London",                  city: "London",           country: "United Kingdom",         abbr: "GMT BST",      also: ["England", "Edinburgh"]),
        TZEntry(tzID: "Europe/Lisbon",                  city: "Lisbon",           country: "Portugal",               abbr: "WET WEST",     also: []),
        TZEntry(tzID: "Europe/Dublin",                  city: "Dublin",           country: "Ireland",                abbr: "GMT IST",      also: []),
        TZEntry(tzID: "Europe/Paris",                   city: "Paris",            country: "France",                 abbr: "CET CEST",     also: []),
        TZEntry(tzID: "Europe/Berlin",                  city: "Berlin",           country: "Germany",                abbr: "CET CEST",     also: ["Hamburg", "Munich", "Frankfurt"]),
        TZEntry(tzID: "Europe/Amsterdam",               city: "Amsterdam",        country: "Netherlands",            abbr: "CET CEST",     also: []),
        TZEntry(tzID: "Europe/Brussels",                city: "Brussels",         country: "Belgium",                abbr: "CET CEST",     also: []),
        TZEntry(tzID: "Europe/Madrid",                  city: "Madrid",           country: "Spain",                  abbr: "CET CEST",     also: ["Barcelona"]),
        TZEntry(tzID: "Europe/Rome",                    city: "Rome",             country: "Italy",                  abbr: "CET CEST",     also: ["Milan"]),
        TZEntry(tzID: "Europe/Zurich",                  city: "Zürich",           country: "Switzerland",            abbr: "CET CEST",     also: ["Zurich", "Geneva"]),
        TZEntry(tzID: "Europe/Vienna",                  city: "Vienna",           country: "Austria",                abbr: "CET CEST",     also: []),
        TZEntry(tzID: "Europe/Warsaw",                  city: "Warsaw",           country: "Poland",                 abbr: "CET CEST",     also: []),
        TZEntry(tzID: "Europe/Stockholm",               city: "Stockholm",        country: "Sweden",                 abbr: "CET CEST",     also: []),
        TZEntry(tzID: "Europe/Oslo",                    city: "Oslo",             country: "Norway",                 abbr: "CET CEST",     also: []),
        TZEntry(tzID: "Europe/Copenhagen",              city: "Copenhagen",       country: "Denmark",                abbr: "CET CEST",     also: []),
        TZEntry(tzID: "Europe/Prague",                  city: "Prague",           country: "Czech Republic",         abbr: "CET CEST",     also: []),
        TZEntry(tzID: "Europe/Budapest",                city: "Budapest",         country: "Hungary",                abbr: "CET CEST",     also: []),
        TZEntry(tzID: "Europe/Athens",                  city: "Athens",           country: "Greece",                 abbr: "EET EEST",     also: []),
        TZEntry(tzID: "Europe/Helsinki",                city: "Helsinki",         country: "Finland",                abbr: "EET EEST",     also: []),
        TZEntry(tzID: "Europe/Kyiv",                    city: "Kyiv",             country: "Ukraine",                abbr: "EET EEST",     also: ["Kiev"]),
        TZEntry(tzID: "Europe/Bucharest",               city: "Bucharest",        country: "Romania",                abbr: "EET EEST",     also: []),
        TZEntry(tzID: "Europe/Riga",                    city: "Riga",             country: "Latvia",                 abbr: "EET EEST",     also: []),
        TZEntry(tzID: "Europe/Vilnius",                 city: "Vilnius",          country: "Lithuania",              abbr: "EET EEST",     also: []),
        TZEntry(tzID: "Europe/Tallinn",                 city: "Tallinn",          country: "Estonia",                abbr: "EET EEST",     also: []),
        TZEntry(tzID: "Europe/Istanbul",                city: "Istanbul",         country: "Turkey",                 abbr: "TRT",          also: ["Ankara"]),
        TZEntry(tzID: "Europe/Moscow",                  city: "Moscow",           country: "Russia",                 abbr: "MSK",          also: ["St. Petersburg"]),
        // Africa
        TZEntry(tzID: "Africa/Accra",                   city: "Accra",            country: "Ghana",                  abbr: "GMT",          also: []),
        TZEntry(tzID: "Africa/Abidjan",                 city: "Abidjan",          country: "Côte d'Ivoire",          abbr: "GMT",          also: ["Ivory Coast"]),
        TZEntry(tzID: "Africa/Lagos",                   city: "Lagos",            country: "Nigeria",                abbr: "WAT",          also: ["Abuja"]),
        TZEntry(tzID: "Africa/Casablanca",              city: "Casablanca",       country: "Morocco",                abbr: "WET",          also: []),
        TZEntry(tzID: "Africa/Cairo",                   city: "Cairo",            country: "Egypt",                  abbr: "EET",          also: []),
        TZEntry(tzID: "Africa/Johannesburg",            city: "Johannesburg",     country: "South Africa",           abbr: "SAST",         also: ["Cape Town", "Pretoria"]),
        TZEntry(tzID: "Africa/Nairobi",                 city: "Nairobi",          country: "Kenya",                  abbr: "EAT",          also: []),
        TZEntry(tzID: "Africa/Addis_Ababa",             city: "Addis Ababa",      country: "Ethiopia",               abbr: "EAT",          also: []),
        TZEntry(tzID: "Africa/Dar_es_Salaam",           city: "Dar es Salaam",    country: "Tanzania",               abbr: "EAT",          also: []),
        TZEntry(tzID: "Africa/Khartoum",                city: "Khartoum",         country: "Sudan",                  abbr: "CAT",          also: []),
        // Middle East
        TZEntry(tzID: "Asia/Jerusalem",                 city: "Jerusalem",        country: "Israel",                 abbr: "IST IDT",      also: ["Tel Aviv"]),
        TZEntry(tzID: "Asia/Beirut",                    city: "Beirut",           country: "Lebanon",                abbr: "EET EEST",     also: []),
        TZEntry(tzID: "Asia/Amman",                     city: "Amman",            country: "Jordan",                 abbr: "EET EEST",     also: []),
        TZEntry(tzID: "Asia/Baghdad",                   city: "Baghdad",          country: "Iraq",                   abbr: "AST",          also: []),
        TZEntry(tzID: "Asia/Riyadh",                    city: "Riyadh",           country: "Saudi Arabia",           abbr: "AST",          also: ["Jeddah", "Mecca"]),
        TZEntry(tzID: "Asia/Kuwait",                    city: "Kuwait City",      country: "Kuwait",                 abbr: "AST",          also: []),
        TZEntry(tzID: "Asia/Qatar",                     city: "Doha",             country: "Qatar",                  abbr: "AST",          also: []),
        TZEntry(tzID: "Asia/Tehran",                    city: "Tehran",           country: "Iran",                   abbr: "IRST IRDT",    also: []),
        TZEntry(tzID: "Asia/Dubai",                     city: "Dubai",            country: "United Arab Emirates",   abbr: "GST",          also: ["Abu Dhabi", "UAE"]),
        TZEntry(tzID: "Asia/Muscat",                    city: "Muscat",           country: "Oman",                   abbr: "GST",          also: []),
        TZEntry(tzID: "Asia/Kabul",                     city: "Kabul",            country: "Afghanistan",            abbr: "AFT",          also: []),
        // Asia
        TZEntry(tzID: "Asia/Karachi",                   city: "Karachi",          country: "Pakistan",               abbr: "PKT",          also: ["Islamabad", "Lahore"]),
        TZEntry(tzID: "Asia/Tashkent",                  city: "Tashkent",         country: "Uzbekistan",             abbr: "UZT",          also: []),
        TZEntry(tzID: "Asia/Kolkata",                   city: "Mumbai",           country: "India",                  abbr: "IST",          also: ["Delhi", "New Delhi", "Kolkata", "Bangalore", "Chennai", "Hyderabad", "Calcutta"]),
        TZEntry(tzID: "Asia/Colombo",                   city: "Colombo",          country: "Sri Lanka",              abbr: "IST",          also: []),
        TZEntry(tzID: "Asia/Kathmandu",                 city: "Kathmandu",        country: "Nepal",                  abbr: "NPT",          also: []),
        TZEntry(tzID: "Asia/Dhaka",                     city: "Dhaka",            country: "Bangladesh",             abbr: "BST",          also: []),
        TZEntry(tzID: "Asia/Yangon",                    city: "Yangon",           country: "Myanmar",                abbr: "MMT",          also: ["Rangoon", "Burma"]),
        TZEntry(tzID: "Asia/Bangkok",                   city: "Bangkok",          country: "Thailand",               abbr: "ICT",          also: ["Indochina"]),
        TZEntry(tzID: "Asia/Jakarta",                   city: "Jakarta",          country: "Indonesia",              abbr: "WIB",          also: []),
        TZEntry(tzID: "Asia/Ho_Chi_Minh",               city: "Ho Chi Minh City", country: "Vietnam",                abbr: "ICT",          also: ["Saigon", "Hanoi"]),
        TZEntry(tzID: "Asia/Kuala_Lumpur",              city: "Kuala Lumpur",     country: "Malaysia",               abbr: "MYT",          also: []),
        TZEntry(tzID: "Asia/Singapore",                 city: "Singapore",        country: "Singapore",              abbr: "SGT",          also: []),
        TZEntry(tzID: "Asia/Shanghai",                  city: "Shanghai",         country: "China",                  abbr: "CST",          also: ["Beijing", "Chongqing"]),
        TZEntry(tzID: "Asia/Hong_Kong",                 city: "Hong Kong",        country: "Hong Kong",              abbr: "HKT",          also: []),
        TZEntry(tzID: "Asia/Taipei",                    city: "Taipei",           country: "Taiwan",                 abbr: "CST",          also: []),
        TZEntry(tzID: "Asia/Manila",                    city: "Manila",           country: "Philippines",            abbr: "PST",          also: []),
        TZEntry(tzID: "Asia/Ulaanbaatar",               city: "Ulaanbaatar",      country: "Mongolia",               abbr: "ULAT",         also: ["Ulan Bator"]),
        TZEntry(tzID: "Asia/Seoul",                     city: "Seoul",            country: "South Korea",            abbr: "KST",          also: ["Busan"]),
        TZEntry(tzID: "Asia/Tokyo",                     city: "Tokyo",            country: "Japan",                  abbr: "JST",          also: ["Osaka", "Kyoto"]),
        TZEntry(tzID: "Asia/Vladivostok",               city: "Vladivostok",      country: "Russia",                 abbr: "VLAT",         also: []),
        TZEntry(tzID: "Asia/Magadan",                   city: "Magadan",          country: "Russia",                 abbr: "MAGT",         also: []),
        TZEntry(tzID: "Asia/Kamchatka",                 city: "Petropavlovsk",    country: "Russia",                 abbr: "PETT",         also: ["Kamchatka"]),
        // Oceania
        TZEntry(tzID: "Australia/Perth",                city: "Perth",            country: "Australia",              abbr: "AWST",         also: []),
        TZEntry(tzID: "Australia/Darwin",               city: "Darwin",           country: "Australia",              abbr: "ACST",         also: []),
        TZEntry(tzID: "Australia/Adelaide",             city: "Adelaide",         country: "Australia",              abbr: "ACST ACDT",    also: []),
        TZEntry(tzID: "Australia/Brisbane",             city: "Brisbane",         country: "Australia",              abbr: "AEST",         also: ["Queensland"]),
        TZEntry(tzID: "Australia/Sydney",               city: "Sydney",           country: "Australia",              abbr: "AEST AEDT",    also: ["Melbourne", "Canberra"]),
        TZEntry(tzID: "Pacific/Auckland",               city: "Auckland",         country: "New Zealand",            abbr: "NZST NZDT",    also: ["Wellington"]),
        TZEntry(tzID: "Pacific/Fiji",                   city: "Suva",             country: "Fiji",                   abbr: "FJT",          also: []),
        TZEntry(tzID: "Pacific/Guam",                   city: "Guam",             country: "Guam",                   abbr: "ChST",         also: []),
        TZEntry(tzID: "Pacific/Tongatapu",              city: "Nuku'alofa",       country: "Tonga",                  abbr: "TOT",          also: ["Nukualofa"]),
        TZEntry(tzID: "Pacific/Apia",                   city: "Apia",             country: "Samoa",                  abbr: "WST",          also: []),
    ]
}
