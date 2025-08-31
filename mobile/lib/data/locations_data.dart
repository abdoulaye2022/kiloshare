class LocationsData {
  static const List<Map<String, String>> provinces = [
    {"value": "AB", "label": "Alberta"},
    {"value": "BC", "label": "Colombie-Britannique"},
    {"value": "MB", "label": "Manitoba"},
    {"value": "NB", "label": "Nouveau-Brunswick"},
    {"value": "NL", "label": "Terre-Neuve-et-Labrador"},
    {"value": "NS", "label": "Nouvelle-Écosse"},
    {"value": "NT", "label": "Territoires du Nord-Ouest"},
    {"value": "NU", "label": "Nunavut"},
    {"value": "ON", "label": "Ontario"},
    {"value": "PE", "label": "Île-du-Prince-Édouard"},
    {"value": "QC", "label": "Québec"},
    {"value": "SK", "label": "Saskatchewan"},
    {"value": "YT", "label": "Yukon"},
  ];

  static const List<Map<String, String>> countries = [
    // Afrique de l'Ouest
    {"label": "Bénin", "value": "BJ"},
    {"label": "Burkina Faso", "value": "BF"},
    {"label": "Côte d'Ivoire", "value": "CI"},
    {"label": "Ghana", "value": "GH"},
    {"label": "Guinée", "value": "GN"},
    {"label": "Mali", "value": "ML"},
    {"label": "Niger", "value": "NE"},
    {"label": "Nigéria", "value": "NG"},
    {"label": "Sénégal", "value": "SN"},
    {"label": "Togo", "value": "TG"},

    // Afrique centrale et autres régions
    {"label": "Cameroun", "value": "CM"},
    {"label": "Tchad", "value": "TD"},

    // Afrique du Nord
    {"label": "Maroc", "value": "MA"},
    {"label": "Algérie", "value": "DZ"},
    {"label": "Tunisie", "value": "TN"},
    {"label": "Égypte", "value": "EG"},

    // Autres pays
    {"label": "France", "value": "FR"},
    {"label": "Canada", "value": "CA"},
    {"label": "États-Unis", "value": "US"},
    {"label": "Angleterre", "value": "GB"},
    {"label": "Turquie", "value": "TR"},
  ];

  static const List<Map<String, String>> cities = [
    // Afrique de l'Ouest
    {"label": "Porto-Novo", "value": "Porto-Novo", "pays": "BJ"},
    {"label": "Ouagadougou", "value": "Ouagadougou", "pays": "BF"},
    {"label": "Praia", "value": "Praia", "pays": "CV"},
    {"label": "Abidjan", "value": "Abidjan", "pays": "CI"},
    {"label": "Yamoussoukro", "value": "Yamoussoukro", "pays": "CI"},
    {"label": "Banjul", "value": "Banjul", "pays": "GM"},
    {"label": "Accra", "value": "Accra", "pays": "GH"},
    {"label": "Conakry", "value": "Conakry", "pays": "GN"},
    {"label": "Bissau", "value": "Bissau", "pays": "GW"},
    {"label": "Bamako", "value": "Bamako", "pays": "ML"},
    {"label": "Niamey", "value": "Niamey", "pays": "NE"},
    {"label": "Abuja", "value": "Abuja", "pays": "NG"},
    {"label": "Dakar", "value": "Dakar", "pays": "SN"},
    {"label": "Lomé", "value": "Lomé", "pays": "TG"},

    // Afrique centrale et autres régions
    {"label": "Gitega", "value": "Gitega", "pays": "BI"},
    {"label": "Yaoundé", "value": "Yaoundé", "pays": "CM"},
    {"label": "Bangui", "value": "Bangui", "pays": "CF"},
    {"label": "Brazzaville", "value": "Brazzaville", "pays": "CG"},
    {"label": "Djibouti", "value": "Djibouti", "pays": "DJ"},
    {"label": "Libreville", "value": "Libreville", "pays": "GA"},
    {"label": "Malabo", "value": "Malabo", "pays": "GQ"},
    {"label": "Antananarivo", "value": "Antananarivo", "pays": "MG"},
    {"label": "Kinshasa", "value": "Kinshasa", "pays": "CD"},
    {"label": "Kigali", "value": "Kigali", "pays": "RW"},
    {"label": "N'Djamena", "value": "N'Djamena", "pays": "TD"},

    // Afrique du Nord
    {"label": "Nouakchott", "value": "Nouakchott", "pays": "MR"},
    {"label": "Rabat", "value": "Rabat", "pays": "MA"},
    {"label": "Alger", "value": "Alger", "pays": "DZ"},
    {"label": "Tunis", "value": "Tunis", "pays": "TN"},
    {"label": "Tripoli", "value": "Tripoli", "pays": "LY"},
    {"label": "Le Caire", "value": "Le Caire", "pays": "EG"},

    // Canada Atlantique - Nouveau-Brunswick
    {"label": "Moncton", "value": "Moncton", "pays": "CA"},
    {"label": "Fredericton", "value": "Fredericton", "pays": "CA"},
    {"label": "Saint John", "value": "Saint John", "pays": "CA"},
    {"label": "Bathurst", "value": "Bathurst", "pays": "CA"},
    {"label": "Miramichi", "value": "Miramichi", "pays": "CA"},
    {"label": "Edmundston", "value": "Edmundston", "pays": "CA"},
    {"label": "Campbellton", "value": "Campbellton", "pays": "CA"},
    
    // Canada Atlantique - Nouvelle-Écosse
    {"label": "Halifax", "value": "Halifax", "pays": "CA"},
    {"label": "Sydney", "value": "Sydney", "pays": "CA"},
    {"label": "Truro", "value": "Truro", "pays": "CA"},
    {"label": "New Glasgow", "value": "New Glasgow", "pays": "CA"},
    {"label": "Yarmouth", "value": "Yarmouth", "pays": "CA"},
    {"label": "Kentville", "value": "Kentville", "pays": "CA"},
    
    // Canada Atlantique - Île-du-Prince-Édouard
    {"label": "Charlottetown", "value": "Charlottetown", "pays": "CA"},
    {"label": "Summerside", "value": "Summerside", "pays": "CA"},
    
    // Canada Atlantique - Terre-Neuve-et-Labrador
    {"label": "St. John's", "value": "St. John's", "pays": "CA"},
    {"label": "Corner Brook", "value": "Corner Brook", "pays": "CA"},
    {"label": "Grand Falls-Windsor", "value": "Grand Falls-Windsor", "pays": "CA"},
    
    // Autres villes canadiennes majeures
    {"label": "Montréal", "value": "Montréal", "pays": "CA"},
    {"label": "Toronto", "value": "Toronto", "pays": "CA"},
    {"label": "Ottawa", "value": "Ottawa", "pays": "CA"},
    {"label": "Québec", "value": "Québec", "pays": "CA"},
    {"label": "Vancouver", "value": "Vancouver", "pays": "CA"},
    {"label": "Calgary", "value": "Calgary", "pays": "CA"},
    {"label": "Edmonton", "value": "Edmonton", "pays": "CA"},
    {"label": "Winnipeg", "value": "Winnipeg", "pays": "CA"},
    {"label": "Laval", "value": "Laval", "pays": "CA"},
    {"label": "Gatineau", "value": "Gatineau", "pays": "CA"},
    {"label": "Sherbrooke", "value": "Sherbrooke", "pays": "CA"},
    {"label": "Trois-Rivières", "value": "Trois-Rivières", "pays": "CA"},
    {"label": "Brampton", "value": "Brampton", "pays": "CA"},
    {"label": "Mississauga", "value": "Mississauga", "pays": "CA"},

    // États-Unis
    {"label": "Washington, D.C.", "value": "Washington, D.C.", "pays": "US"},
    {"label": "New York", "value": "New York", "pays": "US"},
    {"label": "Los Angeles", "value": "Los Angeles", "pays": "US"},

    // France
    {"label": "Paris", "value": "Paris", "pays": "FR"},
    {"label": "Lyon", "value": "Lyon", "pays": "FR"},
    {"label": "Marseille", "value": "Marseille", "pays": "FR"},

    // Angleterre (Royaume-Uni)
    {"label": "Londres", "value": "Londres", "pays": "GB"},
    {"label": "Manchester", "value": "Manchester", "pays": "GB"},
    {"label": "Birmingham", "value": "Birmingham", "pays": "GB"},

    // Turquie
    {"label": "Ankara", "value": "Ankara", "pays": "TR"},
    {"label": "Istanbul", "value": "Istanbul", "pays": "TR"},
    {"label": "Izmir", "value": "Izmir", "pays": "TR"},
  ];

  /// Get cities for a specific country
  static List<Map<String, String>> getCitiesForCountry(String countryCode) {
    return cities.where((city) => city['pays'] == countryCode).toList();
  }

  /// Get all cities as simplified list for autocomplete
  static List<Map<String, dynamic>> getAllCitiesForAutocomplete() {
    return cities.map((city) => {
      'city': city['label']!,
      'country': countries.firstWhere(
        (country) => country['value'] == city['pays'],
        orElse: () => {'label': 'Inconnu'},
      )['label']!,
      'code': null, // Pas de code d'aéroport dans cette version
    }).toList();
  }

  /// Search cities by name or country for autocomplete
  static List<Map<String, dynamic>> searchCities(String query) {
    if (query.isEmpty) return [];
    
    final lowerQuery = query.toLowerCase();
    final allCities = getAllCitiesForAutocomplete();
    
    return allCities.where((city) =>
      city['city'].toString().toLowerCase().contains(lowerQuery) ||
      city['country'].toString().toLowerCase().contains(lowerQuery)
    ).take(10).toList();
  }

  /// Format member since date
  static String formatMemberSince(String? dateString) {
    if (dateString == null || dateString.isEmpty) {
      return "Date d'inscription non disponible";
    }

    final date = DateTime.tryParse(dateString);
    if (date == null) return "Date invalide";

    return "${_getMonthName(date.month)} ${date.year}";
  }

  static String _getMonthName(int month) {
    const months = [
      '', 'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
      'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'
    ];
    return months[month];
  }

  /// Default date formatting
  static String defaultFormatDate(String isoDate) {
    final date = DateTime.tryParse(isoDate);
    if (date == null) return isoDate;
    
    final day = date.day.toString().padLeft(2, '0');
    final month = (date.month).toString().padLeft(2, '0');
    final year = date.year;
    return "$year-$month-$day";
  }
}