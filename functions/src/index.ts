/**
 * Import function triggers from their respective submodules:
 *
 * import {onCall} from "firebase-functions/v2/https";
 * import {onDocumentWritten} from "firebase-functions/v2/firestore";
 *
 * See a full list of supported triggers at https://firebase.google.com/docs/functions
 */

import {onCall} from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import {SpeechClient, protos} from "@google-cloud/speech";
import * as admin from "firebase-admin";
import * as path from "path";

// Initialize Firebase Admin
let adminConfig = {
  credential: admin.credential.cert(
    path.join(__dirname, "../service-account.json"),
  ),
  storageBucket: "gauntlet-project-3.appspot.com",
};

admin.initializeApp(adminConfig);

// Initialize Speech-to-Text client with the same credentials
const speechClient = new SpeechClient({
  keyFilename: path.join(__dirname, "../service-account.json"),
});

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

    logger.info(`Starting transcription for lesson ${lessonId}`);

    // Get the audio file URL from Firebase Storage
    const bucket = admin.storage().bucket();
    
    logger.info(`Looking for files in videos/${lessonId}/`);
    
    // List files in the lesson directory
    const [files] = await bucket.getFiles({
      prefix: `videos/${lessonId}/`
    });

    logger.info(`Found ${files.length} files in directory:`);
    files.forEach(file => {
      logger.info(`- ${file.name}`);
    });

    // Find the first .mp4 file
    const videoFile = files.find(file => file.name.endsWith('.mp4'));
    
    if (!videoFile) {
      throw new Error("Video file not found in lesson directory");
    }

    logger.info(`Found video file at ${videoFile.name}`);

    // Get a signed URL for the audio file
    const [url] = await videoFile.getSignedUrl({
      action: "read",
      expires: Date.now() + 3600 * 1000, // 1 hour
    });

    logger.info("Generated signed URL for video");

    // Configure the recognition request
    const recognitionRequest = {
      audio: {uri: url},
      config: {
        enableAutomaticPunctuation: true,
        model: config.model || "latest_long",
        useEnhanced: config.useEnhanced || true,
        enableWordTimeOffsets: true,
        enableAutomaticLanguageIdentification:
          config.autoDetectLanguage || true,
        multipleLanguages: config.multipleLanguages || true,
      },
    };

    logger.info("Starting Speech-to-Text operation");

    // Start the transcription
    const [operation] = await speechClient.longRunningRecognize(
      recognitionRequest
    );

    logger.info(`Speech-to-Text operation started: ${operation.name}`);

    // Store the operation details
    const operationDoc = operationsStore.doc(lessonId);
    await operationDoc.set({
      operationName: operation.name,
      status: "running",
      startTime: admin.firestore.FieldValue.serverTimestamp(),
      config: config,
      videoPath: videoFile.name,
    });

    return {
      operationName: operation.name,
      status: "running",
      videoPath: videoFile.name,
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
    const operationDoc = operationsStore.doc(lessonId);
    const snapshot = await operationDoc.get();

    if (!snapshot.exists) {
      throw new Error("Transcription operation not found");
    }

    const operationData = snapshot.data();
    if (!operationData?.operationName) {
      throw new Error("Invalid operation data");
    }

    const operation = await speechClient
      .checkLongRunningRecognizeProgress(operationData.operationName);

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

/**
 * Formats a number of seconds into a WebVTT timestamp format.
 * @param {number} seconds - The number of seconds to format
 * @return {string} The formatted timestamp in WebVTT format (HH:MM:SS.mmm)
 */
function formatTimestamp(seconds: number): string {
  const hours = Math.floor(seconds / 3600);
  const minutes = Math.floor((seconds % 3600) / 60);
  const secs = Math.floor(seconds % 60);
  const ms = Math.floor((seconds % 1) * 1000);
  return `${hours.toString().padStart(2, "0")}:${minutes.toString()
    .padStart(2, "0")}:${secs.toString().padStart(2, "0")}.${ms.toString()
    .padStart(3, "0")}`;
}

/**
 * Gets the total seconds from a Duration object.
 * @param {IDuration | null | undefined} time - Duration object to process
 * @return {number} The total seconds including nanoseconds
 */
function getSeconds(
  time: protos.google.protobuf.IDuration | null | undefined
): number {
  if (!time?.seconds) return 0;
  const seconds = typeof time.seconds === "number" ?
    time.seconds :
    Number(time.seconds);
  return seconds + (time.nanos || 0) / 1e9;
}

/**
 * Generates WebVTT content from transcription results.
 * @param {SpeechRecognitionResult[]} results - Results with timing info
 * @return {string} The generated WebVTT content
 */
function generateWebVTT(results: Array<{
  transcript: string;
  words?: protos.google.cloud.speech.v1.IWordInfo[] | null;
}>): string {
  let vttContent = "WEBVTT\n\n";
  let index = 1;

  results.forEach((result) => {
    const words = result.words || [];
    if (words.length > 0) {
      // Group words into phrases
      let currentPhrase = "";
      let startTime = getSeconds(words[0].startTime);
      let currentTime = startTime;

      words.forEach((word, i) => {
        const wordStartTime = getSeconds(word.startTime);
        currentPhrase += (word.word || "") + " ";

        // Start a new phrase if more than 3 seconds have passed
        if (wordStartTime - currentTime > 3 && currentPhrase) {
          const endTime = currentTime + 0.5; // Add small buffer
          vttContent += `${index++}\n`;
          vttContent += `${formatTimestamp(startTime)} --> ${
            formatTimestamp(endTime)}\n`;
          vttContent += `${currentPhrase.trim()}\n\n`;

          currentPhrase = "";
          startTime = wordStartTime;
        }

        currentTime = wordStartTime;

        // Add the last phrase
        if (i === words.length - 1 && currentPhrase) {
          const endTime = currentTime + 0.5;
          vttContent += `${index++}\n`;
          vttContent += `${formatTimestamp(startTime)} --> ${
            formatTimestamp(endTime)}\n`;
          vttContent += `${currentPhrase.trim()}\n\n`;
        }
      });
    } else {
      // If no word timing, use the entire transcript as one subtitle
      vttContent += `${index++}\n`;
      vttContent += "00:00:00.000 --> 99:59:59.999\n";
      vttContent += `${result.transcript}\n\n`;
    }
  });

  return vttContent;
}

export const getTranscriptionResults = onCall(async (request) => {
  try {
    const {lessonId} = request.data as {lessonId: string};

    // Get the operation details from Firestore
    const operationDoc = operationsStore.doc(lessonId);
    const snapshot = await operationDoc.get();

    if (!snapshot.exists) {
      throw new Error("Transcription operation not found");
    }

    const operationData = snapshot.data();
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

    // Generate WebVTT content
    const vttContent = generateWebVTT(results);

    // Save WebVTT file to Storage
    const bucket = admin.storage().bucket();
    const subtitlePath = `videos/${lessonId}/subtitles/auto_generated.vtt`;
    const subtitleFile = bucket.file(subtitlePath);

    await subtitleFile.save(vttContent, {
      contentType: "text/vtt",
      metadata: {
        contentLanguage: results[0].languageCode,
        transcriptionTime: new Date().toISOString(),
      },
    });

    // Get the subtitle URL
    const [subtitleUrl] = await subtitleFile.getSignedUrl({
      action: "read",
      expires: Date.now() + (365 * 24 * 60 * 60 * 1000), // 1 year
    });

    // Store the results in Firestore
    await operationDoc.update({
      status: "completed",
      completionTime: admin.firestore.FieldValue.serverTimestamp(),
      results: results,
      subtitleUrl: subtitleUrl,
      subtitlePath: subtitlePath,
    });

    return {
      results: results,
      subtitleUrl: subtitleUrl,
      subtitlePath: subtitlePath,
    };
  } catch (err) {
    const error = err as Error;
    logger.error("Error getting transcription results:", error);
    throw new Error(`Failed to get transcription results: ${error.message}`);
  }
});
