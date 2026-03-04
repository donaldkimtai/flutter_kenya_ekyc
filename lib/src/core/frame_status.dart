/// Enum indicating the real-time status of a camera frame.
enum FrameStatus {
  /// The camera is currently initializing.
  initializing,
  
  /// The camera is processing the frame through ML Kit.
  processing,
  
  /// There is no document found inside the camera frame.
  documentNotFound,
  
  /// The document is too far away from the camera.
  documentTooSmall,
  
  /// The document is too close to the camera.
  documentTooBig,
  
  /// The document is not perfectly centered in the UI cutout.
  documentNotInCenter,
  
  /// No human face was detected in the frame.
  noFaceFound,
  
  /// The user's eyes are closed (used for active blink detection).
  eyesClosed,
  
  /// The user's head is turned too far left (used for 3D liveness).
  headTurnedLeft,
  
  /// The user's head is turned too far right (used for 3D liveness).
  headTurnedRight,
  
  /// A spoofing attempt (e.g., printed photo or blurry screen) was detected.
  spoofingDetected,
  
  /// The document or face is perfectly aligned and verified.
  success,
}