/// All Kenyan document types supported by the eKYC engine.
enum KenyanDocumentType {
  /// Front side of a Kenyan National Identity Card.
  nationalIdFront,

  /// Back side of a Kenyan National Identity Card.
  nationalIdBack,

  /// An NTSA Vehicle Logbook.
  ntsaLogbook,

  /// A Kenyan Driving Licence.
  drivingLicense,

  /// A PSV (Public Service Vehicle) Badge.
  psvBadge,
}