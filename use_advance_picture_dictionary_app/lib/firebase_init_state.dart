/// Populated from [main] when [Firebase.initializeApp] fails; cleared on success.
/// Used for admin/debug messaging when Firestore cannot run.
String? firebaseInitializeAppError;
