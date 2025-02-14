import { onCall, HttpsOptions } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import { transcribeVideoWithWhisper } from './services/whisper-transcription';
import { HttpsError } from "firebase-functions/v1/https";
import * as dotenv from 'dotenv';
import { defineSecret } from 'firebase-functions/params';
import OpenAI from 'openai';

// Load environment variables
dotenv.config();

// Define the secret
const openaiApiKey = defineSecret('OPENAI_API_KEY');

// Initialize Firebase Admin
let adminConfig = {
  credential: admin.credential.applicationDefault(),
  storageBucket: process.env.FIREBASE_STORAGE_BUCKET || "gauntlet-project-3.firebasestorage.app",
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
 * Transcribes a video file stored in Firebase Storage using OpenAI Whisper
 */
export const transcribeVideo = onCall({ 
  ...functionConfig,
  secrets: [openaiApiKey]
}, async (request) => {
  // Verify authentication
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'User must be authenticated to transcribe videos');
  }

  const { lessonPath, targetLanguage } = request.data;
  
  if (!lessonPath) {
    throw new HttpsError('invalid-argument', 'Lesson document path must be provided');
  }

  try {
    // Get the lesson document using the provided path
    const lessonRef = admin.firestore().doc(lessonPath);
    const lessonDoc = await lessonRef.get();
    
    if (!lessonDoc.exists) {
      // Extract lesson ID from path
      const pathParts = lessonPath.split('/');
      const lessonId = pathParts[pathParts.length - 1];
      
      // Create the lesson document with default values
      await lessonRef.set({
        id: lessonId,
        videoUrl: `gs://${process.env.FIREBASE_STORAGE_BUCKET}/videos/${lessonId}/video.mp4`,
        transcription: {
          status: 'pending',
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        }
      }, { merge: true });
    }

    // Get the latest document data
    const latestDoc = await lessonRef.get();
    const lessonData = latestDoc.data();
    
    if (!lessonData?.videoUrl) {
      throw new HttpsError('failed-precondition', 'Video URL not found in lesson');
    }

    // Update status to processing
    await lessonRef.set({
      transcription: {
        status: 'processing',
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        targetLanguage: targetLanguage,
      }
    }, { merge: true });
    
    const result = await transcribeVideoWithWhisper(
      lessonRef,
      lessonData.videoUrl,
      targetLanguage
    );

    return result;
  } catch (error) {
    console.error('Error in transcribeVideo function:', error);
    throw new HttpsError('internal', 'Failed to transcribe video', error);
  }
});

export const generateLessonSummary = onCall({ 
  ...functionConfig,  // Use the same config as transcribeVideo
  secrets: [openaiApiKey]
}, async (request) => {
  // Verify authentication
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'User must be authenticated to generate summaries');
  }

  const { lessonPath, language } = request.data;
  console.log(`Generating summary for lesson ${lessonPath} in language ${language}`);

  if (!lessonPath || !language) {
    throw new HttpsError('invalid-argument', 'Missing required parameters: lessonPath and language');
  }

  try {
    // Initialize OpenAI client
    const openai = new OpenAI({
      apiKey: openaiApiKey.value(),
    });

    // Get the lesson document
    const lessonDoc = await admin.firestore().doc(lessonPath).get();
    if (!lessonDoc.exists) {
      throw new HttpsError('not-found', 'Lesson not found');
    }

    const lessonData = lessonDoc.data();
    console.log('Lesson data:', JSON.stringify(lessonData, null, 2));

    if (!lessonData?.transcription) {
      console.log('No transcription field found in lesson data');
      throw new HttpsError('failed-precondition', 'Transcription not completed for this lesson');
    }

    if (lessonData.transcription.status !== 'completed') {
      console.log('Transcription status is not completed:', lessonData.transcription.status);
      throw new HttpsError('failed-precondition', 'Transcription not completed for this lesson');
    }

    // Check if transcription is in the requested language
    console.log('Checking language match - Requested:', language, 'Current:', lessonData.transcription.outputLanguage);
    if (lessonData.transcription.outputLanguage !== language) {
      throw new HttpsError('failed-precondition', `Transcription is not available in ${language}. Current transcription is in ${lessonData.transcription.outputLanguage}`);
    }

    // Get transcript from the transcription field
    const transcript = lessonData.transcription.text;  // Changed from transcript to text
    if (!transcript) {
      console.log('No text field found in transcription data:', lessonData.transcription);
      throw new HttpsError('failed-precondition', 'No transcript available for this lesson');
    }

    console.log('Found transcript, generating summary using OpenAI');
    // Generate summary using GPT
    const response = await openai.chat.completions.create({
      model: "gpt-3.5-turbo",
      messages: [
        {
          role: "system",
          content: `You are a concise summarizer. Create a brief 1-2 sentence summary in ${language} that captures the main points of the transcript. Focus on the key topics and learning objectives.`
        },
        {
          role: "user",
          content: transcript
        }
      ],
      max_tokens: 100,
      temperature: 0.5,
    });

    const summary = response.choices[0]?.message?.content?.trim();
    if (!summary) {
      throw new HttpsError('internal', 'Failed to generate summary');
    }

    console.log('Successfully generated summary:', summary);
    
    // Update the lesson document with the summary
    await admin.firestore().doc(lessonPath).update({
      [`summaries.${language}`]: summary,
      lastUpdated: admin.firestore.FieldValue.serverTimestamp()
    });

    return { summary };
  } catch (error) {
    console.error('Error generating summary:', error);
    throw new HttpsError('internal', 'Failed to generate summary', error);
  }
}); 