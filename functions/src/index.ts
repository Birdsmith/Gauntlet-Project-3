import { onCall, HttpsOptions } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import { transcribeVideoWithWhisper } from './services/whisper-transcription';
import { HttpsError } from "firebase-functions/v2/https";
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
    console.log('Lesson data:', lessonData);

    if (!lessonData?.transcription || lessonData.transcription.status !== 'completed') {
      throw new HttpsError('failed-precondition', 'Transcription not completed for this lesson');
    }

    // Check if transcription is in the requested language
    if (lessonData.transcription.outputLanguage !== language) {
      throw new HttpsError('failed-precondition', `Transcription is not available in ${language}. Current transcription is in ${lessonData.transcription.outputLanguage}`);
    }

    // Get transcript from the transcription field
    const transcript = lessonData.transcription.text;  // Changed from transcript to text
    if (!transcript) {
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

export const generateQuiz = onCall({ 
  ...functionConfig,
  secrets: [openaiApiKey]
}, async (request) => {
  // Verify authentication
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'User must be authenticated to generate quizzes');
  }

  try {
    const { text } = request.data;
    if (!text) {
      throw new HttpsError('invalid-argument', 'Text is required');
    }

    console.log('Received VTT content length:', text.length);
    console.log('Sample of VTT content:', text.substring(0, 200));

    const openai = new OpenAI({
      apiKey: openaiApiKey.value(),
    });

    // First, extract the text content from the VTT
    console.log('Extracting text from VTT...');
    const extractResponse = await openai.chat.completions.create({
      model: "gpt-3.5-turbo",
      messages: [
        {
          role: "system",
          content: "You are a subtitle text extractor. Extract only the text content from the WebVTT format, ignoring timestamps and metadata. Combine the text into a single paragraph."
        },
        {
          role: "user",
          content: text
        }
      ],
      temperature: 0.3,
    });

    const extractedText = extractResponse.choices[0]?.message?.content?.trim();
    if (!extractedText) {
      throw new HttpsError('internal', 'Failed to extract text from VTT');
    }

    console.log('Extracted text:', extractedText);

    // Now generate the quiz using the extracted text
    console.log('Generating quiz...');
    const quizResponse = await openai.chat.completions.create({
      model: "gpt-3.5-turbo",
      messages: [
        {
          role: "system",
          content: `Given the following text from a video, identify an important keyword or concept and create a multiple choice question about its definition. The question should test understanding of the concept.

Text: ${extractedText}

Generate a response in the following JSON format:
{
  "keyword": "the identified keyword",
  "question": "What is the definition of [keyword]?",
  "correctAnswer": "the correct definition",
  "incorrectAnswers": ["wrong answer 1", "wrong answer 2", "wrong answer 3"]
}

Make sure the incorrect answers are plausible but clearly wrong. The answers should be concise.`
        }
      ],
      temperature: 0.7,
    });

    console.log('Received quiz response from OpenAI');
    const content = quizResponse.choices[0]?.message?.content;
    if (!content) {
      throw new HttpsError('internal', 'OpenAI returned empty response');
    }

    console.log('OpenAI response:', content);
    
    try {
      const quizData = JSON.parse(content);
      
      // Validate the quiz data structure
      if (!quizData.keyword || !quizData.question || !quizData.correctAnswer || !Array.isArray(quizData.incorrectAnswers)) {
        console.error('Invalid quiz data structure:', quizData);
        throw new HttpsError('internal', 'Generated quiz data is missing required fields');
      }
      
      return quizData;
    } catch (parseError) {
      console.error('Failed to parse OpenAI response as JSON:', parseError);
      console.error('Raw content:', content);
      throw new HttpsError('internal', 'Failed to parse quiz data as JSON');
    }
  } catch (error) {
    console.error('Error generating quiz:', error);
    if (error instanceof HttpsError) {
      throw error;
    }
    throw new HttpsError('internal', 'Failed to generate quiz: ' + error.message);
  }
}); 