import OpenAI from 'openai';
import * as admin from 'firebase-admin';
import * as fs from 'fs';
import * as os from 'os';
import * as path from 'path';
import { defineSecret } from 'firebase-functions/params';

// Define the secret
const openaiApiKey = defineSecret('OPENAI_API_KEY');

export interface TranscriptionResult {
  transcript: string;
  detectedLanguages: Set<string>;
  status: 'completed' | 'failed';
  error?: string;
  summary?: string;
}

/**
 * Transcribes a video file stored in Firebase Storage using OpenAI's Whisper
 * @param lessonRef The Firestore document reference for the lesson
 * @param videoUrl The GCS URI or HTTPS URL of the video file to transcribe
 * @param targetLanguage If specified, translates to that language. Otherwise transcribes in original language.
 * @returns The transcription result including transcript and detected languages
 */
export async function transcribeVideoWithWhisper(
  lessonRef: admin.firestore.DocumentReference,
  videoUrl: string,
  targetLanguage?: string,
): Promise<TranscriptionResult> {
  try {
    // Initialize OpenAI client with the secret
    const openai = new OpenAI({
      apiKey: openaiApiKey.value(),
    });

    if (!videoUrl) {
      throw new Error('Video URL must be provided');
    }

    // Download the video file from Firebase Storage
    const bucket = admin.storage().bucket();
    const tempFilePath = path.join(os.tmpdir(), `${lessonRef.id}_video.mp4`);
    
    await bucket.file(videoUrl.replace('gs://' + bucket.name + '/', '')).download({
      destination: tempFilePath
    });

    // Transcribe using Whisper
    console.log('Starting Whisper transcription with video file:', tempFilePath);
    const transcription = await openai.audio.transcriptions.create({
      file: fs.createReadStream(tempFilePath),
      model: "whisper-1",
      response_format: "verbose_json",
      timestamp_granularities: ["word"],
      prompt: "Convert all numerical values to their word equivalents in the target language. For example: convert '123' to 'one hundred twenty-three', '1st' to 'first', '2nd' to 'second', '$50' to 'fifty dollars', '1,000' to 'one thousand', etc. This includes all numbers, ordinals, currency amounts, dates, and any other numerical expressions.",
      ...(targetLanguage ? { language: targetLanguage } : {}),
    });
      
    // Clean up temp file
    fs.unlinkSync(tempFilePath);

    if (!transcription || !transcription.text) {
      return {
        transcript: '',
        detectedLanguages: new Set(),
        status: 'failed',
        error: 'No transcription results received'
      };
    }

    console.log('Transcription completed successfully');
    console.log('Raw transcription response:', JSON.stringify(transcription, null, 2));

    // Convert the response to VTT format for subtitles
    const vttContent = convertWhisperToVtt(transcription);
    console.log('Generated VTT content:', vttContent);

    // Extract folder path from video URL
    const videoUrlMatch = videoUrl.match(/videos\/(\d+)\//);
    if (!videoUrlMatch) {
      throw new Error('Invalid video URL format. Expected path containing videos/[id]/');
    }
    const folderPath = videoUrlMatch[0];

    // Save VTT file with appropriate language code
    const outputLanguage = targetLanguage || transcription.language;
    const vttFileName = `${folderPath}subtitles/${outputLanguage}.vtt`;
    console.log('Saving VTT file to:', vttFileName);
    const vttFile = bucket.file(vttFileName);
    await vttFile.save(vttContent, {
      contentType: 'text/vtt',
      metadata: {
        contentLanguage: outputLanguage,
        transcriptionModel: 'whisper-1',
        transcriptionTimestamp: new Date().toISOString(),
      },
    });

    // Store transcription metadata in Firestore
    await lessonRef.update({
      transcription: {
        status: 'completed',
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        detectedLanguages: [transcription.language],
        outputLanguage: outputLanguage,
        model: 'whisper-1',
        text: transcription.text,
      }
    });

    return {
      transcript: transcription.text,
      detectedLanguages: new Set([transcription.language]),
      status: 'completed',
    };
  } catch (error) {
    console.error('Error in transcribeVideoWithWhisper:', error);
    
    // Update lesson document with error status
    try {
      await lessonRef.update({
        transcription: {
          status: 'failed',
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
          error: error instanceof Error ? error.message : 'Unknown error',
        }
      });
    } catch (updateError) {
      console.error('Error updating lesson status:', updateError);
    }

    return {
      transcript: '',
      detectedLanguages: new Set(),
      status: 'failed',
      error: error instanceof Error ? error.message : 'Unknown error'
    };
  }
}

/**
 * Converts Whisper transcription response to WebVTT format
 * @param transcription The response from Whisper API
 * @returns A string in WebVTT format with word-level timing
 */
function convertWhisperToVtt(transcription: any): string {
  let vttContent = 'WEBVTT\n\n';
  let segmentIndex = 1;

  // Group words into segments (similar to the previous implementation)
  const segments: any[] = [];
  let currentSegment: any[] = [];
  let lastEndTime = 0;

  transcription.words.forEach((word: any) => {
    const timeGap = word.start - lastEndTime > 1;
    const shouldStartNewSegment = currentSegment.length >= 10 || timeGap;

    if (shouldStartNewSegment && currentSegment.length > 0) {
      segments.push([...currentSegment]);
      currentSegment = [];
    }

    currentSegment.push(word);
    lastEndTime = word.end;
  });

  if (currentSegment.length > 0) {
    segments.push(currentSegment);
  }

  // Convert segments to VTT format
  segments.forEach(segment => {
    const start = formatTime(segment[0].start);
    const end = formatTime(segment[segment.length - 1].end || segment[segment.length - 1].start);
    const text = segment.map((word: any) => word.word).join(' ');

    vttContent += `${segmentIndex++}\n`;
    vttContent += `${start} --> ${end}\n`;
    vttContent += `${text}\n\n`;
  });

  return vttContent;
}

/**
 * Formats a timestamp into VTT format (HH:MM:SS.mmm)
 */
function formatTime(seconds: number): string {
  const hours = Math.floor(seconds / 3600);
  const minutes = Math.floor((seconds % 3600) / 60);
  const secs = Math.floor(seconds % 60);
  const ms = Math.floor((seconds % 1) * 1000);

  const hh = String(hours).padStart(2, '0');
  const mm = String(minutes).padStart(2, '0');
  const ss = String(secs).padStart(2, '0');
  const mmm = String(ms).padStart(3, '0');

  return `${hh}:${mm}:${ss}.${mmm}`;
} 