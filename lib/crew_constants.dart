// Shared constants for Crew App

class CrewConstants {
  // Trade types - Eve's full list
  static const List<String> tradeTypes = [
    'Labourer',
    'Welder',
    'Welder Helper',
    'Pipefitter',
    'Pipefitter Helper',
    'Coater',
    'Zoom Boom Operator',
    'Hoe Hand',
    'Dozer Hand',
    'Boom Hand',
    'Bending Crew',
    'Scaffolder',
    'Rigger',
    'Millwright',
    'Electrician',
    'Instrument Tech',
    'Insulator',
    'Iron Worker',
    'Crane Operator',
    'Heavy Equipment Operator',
    'Safety Watch',
    'Fire Watch',
    'Other',
  ];

  // Experience levels - no "Master" per Eve
  static const List<Map<String, String>> experienceLevels = [
    {'value': 'apprentice_1st', 'label': '1st Year Apprentice'},
    {'value': 'apprentice_2nd', 'label': '2nd Year Apprentice'},
    {'value': 'apprentice_3rd', 'label': '3rd Year Apprentice'},
    {'value': 'apprentice_4th', 'label': '4th Year Apprentice'},
    {'value': 'journeyman', 'label': 'Journeyman'},
  ];

  static String expToLabel(String exp) {
    switch (exp) {
      case 'apprentice_1st': return '1st Year';
      case 'apprentice_2nd': return '2nd Year';
      case 'apprentice_3rd': return '3rd Year';
      case 'apprentice_4th': return '4th Year';
      case 'journeyman': return 'Journeyman';
      case 'master': return 'Journeyman'; // map old master to journeyman
      default: return exp;
    }
  }

  static String labelToExp(String label) {
    switch (label) {
      case '1st Year': return 'apprentice_1st';
      case '2nd Year': return 'apprentice_2nd';
      case '3rd Year': return 'apprentice_3rd';
      case '4th Year': return 'apprentice_4th';
      case 'Journeyman': return 'journeyman';
      default: return 'All';
    }
  }

  // Filter labels for dropdowns
  static List<String> get experienceFilterLabels =>
      ['All', ...experienceLevels.map((e) => e['label']!)];

  static List<String> get tradeFilterLabels =>
      ['All', ...tradeTypes];
}
