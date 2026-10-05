/// Global flag set at app startup.
/// true  = Firebase initialized successfully — live Firestore/Auth enabled.
/// false = Firebase unavailable — all services fall back to in-memory mock data.
bool kFirebaseReady = false;
