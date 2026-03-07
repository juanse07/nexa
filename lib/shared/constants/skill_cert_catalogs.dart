import 'package:flutter/material.dart';

/// Shared skill and certification catalogs used across the app:
/// - Staff detail screen (tagging skills/certs to a staff member)
/// - Role requirements picker (tagging requirements to an event role)

const skillCategories = <String, (IconData, List<String>)>{
  'Hospitality': (Icons.local_bar, ['Bartending', 'Mixology', 'Wine Service', 'Beer Knowledge', 'Barista', 'Table Service', 'Fine Dining', 'Banquet Service', 'Buffet Setup', 'Host/Hostess']),
  'Kitchen': (Icons.restaurant, ['Line Cook', 'Prep Cook', 'Pastry', 'Grill', 'Sauté', 'Food Plating', 'Catering', 'Kitchen Management', 'Baking', 'Food Styling']),
  'Events': (Icons.celebration, ['DJ', 'Sound & Lighting', 'Photography', 'Videography', 'Event Setup', 'Stage Management', 'Floral Arrangement', 'Decoration', 'MC/Emcee', 'Coat Check']),
  'Childcare': (Icons.child_care, ['Infant Care', 'Toddler Care', 'Child Development', 'Tutoring', 'Activity Planning', 'Special Needs Care', 'Newborn Care', 'Homework Help']),
  'Construction': (Icons.construction, ['Carpentry', 'Plumbing', 'Electrical', 'Painting', 'Drywall', 'Concrete', 'Welding', 'HVAC', 'Roofing', 'Demolition']),
  'Healthcare': (Icons.medical_services, ['Patient Care', 'Vital Signs', 'Wound Care', 'Medication Admin', 'Phlebotomy', 'Physical Therapy', 'Elder Care', 'Home Health']),
  'General': (Icons.work, ['Customer Service', 'Cash Handling', 'POS Systems', 'Inventory', 'Cleaning', 'Driving', 'Security', 'Warehouse', 'Forklift', 'Data Entry']),
};

const certCategories = <String, (IconData, List<String>)>{
  'Food & Beverage': (Icons.restaurant_menu, ['TIPS', 'ServSafe Food Handler', 'ServSafe Manager', 'Alcohol Server (ABC)', "Food Handler's Card", 'Allergen Awareness']),
  'Safety': (Icons.health_and_safety, ['CPR / First Aid', 'AED Certified', 'OSHA 10-Hour', 'OSHA 30-Hour', 'Fire Safety', 'Bloodborne Pathogens']),
  'Childcare': (Icons.child_care, ['Child CPR', 'Mandated Reporter', 'Pediatric First Aid', 'Child Development Associate (CDA)', 'Background Check (cleared)']),
  'Construction': (Icons.construction, ['Forklift Operator', 'Scaffolding Safety', 'Confined Space', 'Fall Protection', 'Rigging & Signaling']),
  'Healthcare': (Icons.medical_services, ['CNA', 'BLS (Basic Life Support)', 'ACLS', 'Phlebotomy', 'Home Health Aide (HHA)', 'Medical Assistant']),
  'Driving': (Icons.directions_car, ['Commercial Driver (CDL)', 'Passenger Endorsement', 'Chauffeur License', 'Clean Driving Record']),
};
