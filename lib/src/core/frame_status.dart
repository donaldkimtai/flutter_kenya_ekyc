/// Enum indicating the real-time status of a camera frame during eKYC.
enum FrameStatus {
  /// The camera or ML models are currently initializing.
  initializing,

  /// The camera is actively processing the current frame.
  processing,

  /// No document found inside the camera frame.
  documentNotFound,

  /// The document is too far away from the camera.
  documentTooSmall,

  /// The document is too close to the camera.
  documentTooBig,

  /// The document is not perfectly centered in the UI cutout.
  documentNotInCenter,

  /// No human face was detected in the frame.
  noFaceFound,

  /// The user's eyes are closed (blink liveness step in progress).
  eyesClosed,

  /// The user's head is turned too far left (3D liveness step).
  headTurnedLeft,

  /// The user's head is turned too far right (3D liveness step).
  headTurnedRight,

  /// A spoofing attempt (printed photo, screen replay) was detected.
  spoofingDetected,

  /// The user ran out of time during liveness — routed to manual review.
  timeout,

  /// The document or face is fully verified. Terminal success state.
  success,
}