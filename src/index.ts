import {onCall} from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import {SpeechClient} from "@google-cloud/speech";
import * as admin from "firebase-admin";

// Initialize Firebase Admin
admin.initializeApp();

// Initialize Speech-to-Text client
const speechClient = new SpeechClient();

// Store for tracking ongoing operations
const operationsStore = admin.firestore().collection("transcription_operations");

interface TranscriptionConfig {
  model?: string;
  useEnhanced?: boolean;
  autoDetectLanguage?: boolean;
  multipleLanguages?: boolean;
}

// Define metadata interface for better type safety
interface SpeechOperationMetadata {
  progressPercent?: number;
  startTime?: string;
  lastUpdateTime?: string;
}

export const transcribeAudio = onCall(async (request) => {
  try {
    const {lessonId, config} = request.data as {
      lessonId: string;
      config: TranscriptionConfig;
    };
    
    // Get the audio file URL from Firebase Storage
    const bucket = admin.storage().bucket();
    const file = bucket.file(`lessons/${lessonId}/audio.mp4`);
    const [exists] = await file.exists();
    
    if (!exists) {
      throw new Error("Audio file not found");
    }

    // Get a signed URL for the audio file
    const [url] = await file.getSignedUrl({
      action: "read",
      expires: Date.now() + 3600 * 1000, // 1 hour
    });

    // Configure the recognition request
    const recognitionRequest = {
      audio: {uri: url},
      config: {
        enableAutomaticPunctuation: true,
        model: config.model || "latest_long",
        useEnhanced: config.useEnhanced || true,
        enableAutomaticLanguageIdentification:
          config.autoDetectLanguage || true,
        multipleLanguages: config.multipleLanguages || true,
      },
    };

    // Start the transcription
    const [operation] = await speechClient.longRunningRecognize(
      recognitionRequest
    );
    
    // Store the operation details
    await operationsStore.doc(lessonId).set({
      operationName: operation.name,
      status: "running",
      startTime: admin.firestore.FieldValue.serverTimestamp(),
      config: config,
    });

    return {
      operationName: operation.name,
      status: "running",
    };
  } catch (err) {
    const error = err as Error;
    logger.error("Error starting transcription:", error);
    throw new Error(`Failed to start transcription: ${error.message}`);
  }
});

export const getTranscriptionStatus = onCall(async (request) => {
  try {
    const {lessonId} = request.data as {lessonId: string};
    
    // Get the operation details from Firestore
    const operationDoc = await operationsStore.doc(lessonId).get();
    
    if (!operationDoc.exists) {
      throw new Error("Transcription operation not found");
    }

    const operationData = operationDoc.data();
    if (!operationData?.operationName) {
      throw new Error("Invalid operation data");
    }

    const operation = await speechClient.checkLongRunningRecognizeProgress(
      operationData.operationName
    );

    const metadata = operation.metadata as SpeechOperationMetadata;
    return {
      status: operation.done ? "completed" : "running",
      progress: metadata?.progressPercent ?? 0,
    };
  } catch (err) {
    const error = err as Error;
    logger.error("Error checking transcription status:", error);
    throw new Error(`Failed to check transcription status: ${error.message}`);
  }
});

export const getTranscriptionResults = onCall(async (request) => {
  try {
    const {lessonId} = request.data as {lessonId: string};
    
    // Get the operation details from Firestore
    const operationDoc = await operationsStore.doc(lessonId).get();
    
    if (!operationDoc.exists) {
      throw new Error("Transcription operation not found");
    }

    const operationData = operationDoc.data();
    if (!operationData?.operationName) {
      throw new Error("Invalid operation data");
    }

    const operation = await speechClient.checkLongRunningRecognizeProgress(
      operationData.operationName
    );

    if (!operation.done) {
      throw new Error("Transcription is still in progress");
    }

    const [response] = await operation.promise();

    // Process and format the results
    const results = response.results
      ?.map((result) => {
        const alternative = result.alternatives?.[0];
        if (!alternative) return null;
        return {
          transcript: alternative.transcript || "",
          confidence: alternative.confidence || 0,
          words: alternative.words || [],
          languageCode: result.languageCode || "unknown",
        };
      })
      .filter(
        (result): result is NonNullable<typeof result> => result !== null
      );

    if (!results || results.length === 0) {
      throw new Error("No transcription results available");
    }

    // Store the results in Firestore
    await operationsStore.doc(lessonId).update({
      status: "completed",
      completionTime: admin.firestore.FieldValue.serverTimestamp(),
      results: results,
    });

    return {
      results: results,
    };
  } catch (err) {
    const error = err as Error;
    logger.error("Error getting transcription results:", error);
    throw new Error(`Failed to get transcription results: ${error.message}`);
  }
}); 