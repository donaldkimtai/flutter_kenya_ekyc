/// The Modern Kenyan Identity & Document Verification Engine.
///
/// Import this single file in your app:
/// ```dart
/// import 'package:flutter_kenya_ekyc/flutter_kenya_ekyc.dart';
/// ```
library flutter_kenya_ekyc;

// ── Primary entry point (use this in Bodago Rider) ────────────────────────
export 'src/services/ekyc_service.dart';

// ── Direct UI access (if you need to push the wizard manually) ────────────
export 'src/ui/ekyc_wizard_view.dart';

// ── Result models ─────────────────────────────────────────────────────────
export 'src/models/document_types.dart';
export 'src/models/ekyc_result.dart';

// ── Extracted data models (read the documentData map via these) ───────────
export 'src/models/kenyan_id_data.dart';
export 'src/models/ntsa_logbook_data.dart';
export 'src/models/psv_badge_data.dart';
export 'src/models/driving_license_data.dart';

// ── Firebase uploader (use directly if you need custom upload logic) ──────
export 'src/services/firebase_ekyc_uploader.dart';