import { onCall, HttpsOptions } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import { transcribeVideoGCS } from './services/speech-to-text';
import { HttpsError } from "firebase-functions/v1/https";

// Initialize Firebase Admin
let adminConfig = {
  credential: admin.credential.applicationDefault(),
  storageBucket: "gauntlet-project-3.firebasestorage.app",
};

admin.initializeApp(adminConfig);

// Configure function options for long-running operations
const functionConfig: HttpsOptions = {
  timeoutSeconds: 540,        // 9 minutes (max for 2nd gen functions)
  memory: "2GiB",            // Increased memory for speech processing
  region: "us-central1",     // Specify region for optimal latency
  minInstances: 0,           // Scale to zero when not in use
  maxInstances: 10,          // Limit concurrent transcriptions
};

/**
 * Transcribes a video file stored in Firebase Storage
 */
export const transcribeVideo = onCall(functionConfig, async (request) => {
  // Verify authentication
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'User must be authenticated to transcribe videos');
  }

  const { videoId, audioUrl } = request.data;
  
  if (!videoId || typeof videoId !== 'string') {
    throw new HttpsError('invalid-argument', 'Video ID must be provided');
  }

  if (!audioUrl || typeof audioUrl !== 'string') {
    throw new HttpsError('invalid-argument', 'Audio URL must be provided');
  }

  try {
    // Update the lesson document with the audio URL if not already set
    const lessonRef = admin.firestore().collection('lessons').doc(videoId);
    await lessonRef.update({
      audioUrl: audioUrl,
      transcription: {
        status: 'processing',
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }
    });

    const result = await transcribeVideoGCS(videoId);
    return result;
  } catch (error) {
    console.error('Error in transcribeVideo function:', error);
    throw new HttpsError('internal', 'Failed to transcribe video', error);
  }
}); 