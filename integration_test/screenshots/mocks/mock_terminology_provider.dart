/// A test-friendly TerminologyProvider that works without SharedPreferences.
library;

import 'package:nexa/services/terminology_provider.dart';

/// Extends the real TerminologyProvider but pre-sets the terminology
/// without hitting SharedPreferences async path.
class MockTerminologyProvider extends TerminologyProvider {
  MockTerminologyProvider({String terminology = 'Events'}) {
    // Force-set via the public setter (which is async but we don't await)
    setTerminology(terminology);
  }
}
