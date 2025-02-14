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
      prompt: `Convert ALL numbers to words in ${targetLanguage || 'the detected language'}. 
              For example in Spanish:
              - "1" → "uno"
              - "2" → "dos"
              - "11" → "once"
              - "21" → "veintiuno"
              In English:
              - "1" → "one"
              - "2" → "two"
              - "11" → "eleven"
              - "21" → "twenty-one"
              In Japanese:
              - "1" → "一"
              - "2" → "二"
              - "11" → "十一"
              - "21" → "二十一"
              And so on and so forth for all languages.
              Convert EVERY single number to words, even when it appears alone or in sequences.
              Never leave any numerical digits in the output.
              Use the number system and conventions appropriate for ${targetLanguage || 'the detected language'}.`,
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

    // Convert numbers to words in the target language
    const outputLanguage = targetLanguage || transcription.language;
    let processedTranscription = { ...transcription };

    // First convert numbers in the full text
    processedTranscription.text = await convertNumbersToWords(transcription.text, outputLanguage, openai);

    // Then process each word individually
    if (processedTranscription.words) {
      const batchSize = 20; // Process 20 words at a time
      const batches = [];
      
      for (let i = 0; i < processedTranscription.words.length; i += batchSize) {
        batches.push(processedTranscription.words.slice(i, i + batchSize));
      }
      
      const processedBatches = await Promise.all(
        batches.map(async batch => {
          const processedWords = await Promise.all(
            batch.map(async word => ({
              ...word,
              word: await convertNumbersToWords(word.word, outputLanguage, openai)
            }))
          );
          return processedWords;
        })
      );
      
      processedTranscription.words = processedBatches.flat();
    }

    console.log('Transcription completed successfully');
    console.log('Raw transcription response:', JSON.stringify(processedTranscription, null, 2));

    // Convert the response to VTT format for subtitles
    let vttContent = await convertWhisperToVtt(processedTranscription);
    console.log('Generated VTT content:', vttContent);

    // Process the VTT content for the target language
    if (outputLanguage) {
      try {
        // Split VTT content into header and segments
        const parts = vttContent.split('\n\n');
        const header = parts[0];
        const segments = parts.slice(1);
        
        // Process each segment's text while preserving timing and format
        const processedSegments = await Promise.all(segments.map(async segment => {
          const lines = segment.split('\n');
          if (lines.length < 3) return segment; // Skip invalid segments
          
          const index = lines[0];
          const timing = lines[1];
          const text = lines.slice(2).join('\n');
          
          // Convert numbers in the text regardless of whether they exist
          const convertedText = await convertNumbersToWords(text, outputLanguage, openai);
          return `${index}\n${timing}\n${convertedText}`;
        }));
        
        // Reassemble the VTT file
        vttContent = [header, ...processedSegments].join('\n\n') + '\n';
      } catch (error) {
        console.error('Error processing VTT segments:', error);
      }
    }

    // Extract folder path from video URL
    const videoUrlMatch = videoUrl.match(/videos\/(\d+)\//);
    if (!videoUrlMatch) {
      throw new Error('Invalid video URL format. Expected path containing videos/[id]/');
    }
    const folderPath = videoUrlMatch[0];

    // Save VTT file with appropriate language code
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
        text: processedTranscription.text,
      }
    });

    return {
      transcript: processedTranscription.text,
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
async function convertWhisperToVtt(transcription: any): Promise<string> {
  let vttContent = 'WEBVTT\n\n';
  let segmentIndex = 1;

  // Get segments from Whisper's response
  const segments = transcription.segments || [];
  
  // Process each segment
  const processedSegments = await Promise.all(segments.map(async (segment: any) => {
    const start = formatTime(segment.start);
    const end = formatTime(segment.end);
    const text = segment.text.trim();
    
    // Return the segment in VTT format
    return `${segmentIndex++}\n${start} --> ${end}\n${text}\n`;
  }));

  // Combine all segments with double newlines
  return vttContent + processedSegments.join('\n');
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

/**
 * Converts numbers to words in the specified language
 * @param text The text containing numbers to convert
 * @param targetLanguage The language to convert numbers to
 * @returns The text with numbers converted to words in the target language
 */
async function convertNumbersToWords(text: string, targetLanguage: string, openai: OpenAI): Promise<string> {
  try {
    // First check if the text contains any numbers
    if (!/\d/.test(text)) {
      return text;  // Return early if no numbers found
    }

    // Clean the text before processing
    const cleanedText = text.trim();
    if (!cleanedText) {
      return text;  // Return original if empty after cleaning
    }

    const response = await openai.chat.completions.create({
      model: "gpt-3.5-turbo",
      messages: [
        {
          role: "system",
          content: `You are a number conversion specialist for the ${targetLanguage} language.
                    Your ONLY task is to convert numbers to their word form in ${targetLanguage}.
                    Examples for different languages:
                    Spanish:
                    - "1" → "uno"
                    - "2" → "dos"
                    - "11" → "once"
                    - "21" → "veintiuno"
                    English:
                    - "1" → "one"
                    - "2" → "two"
                    - "11" → "eleven"
                    - "21" → "twenty-one"
                    Japanese:
                    - "1" → "一"
                    - "2" → "二"
                    - "11" → "十一"
                    - "21" → "二十一"
                    
                    And so on and so forth for all languages you are given.
                    Rules:
                    1. Convert ALL numbers to words
                    2. Process numbers in sequences (e.g., "1 2 3" → "uno dos tres")
                    3. Never leave any numerical digits in the output
                    4. Keep all non-numeric text exactly as is
                    5. Maintain original spacing and formatting
                    6. Use the number system and conventions specific to ${targetLanguage}
                    
                    Return ONLY the converted text, no explanations.`
        },
        {
          role: "user",
          content: cleanedText
        }
      ],
      temperature: 0.1,
      max_tokens: 500
    });

    const convertedText = response.choices[0]?.message?.content?.trim();
    if (!convertedText) {
      console.warn('No converted text received from OpenAI');
      return text;
    }

    // Verify no numbers remain in the converted text
    if (/\d/.test(convertedText)) {
      console.warn('Numbers still present in converted text, attempting second pass');
      return await convertNumbersToWords(convertedText, targetLanguage, openai);
    }

    console.log('Number conversion:', { original: text, converted: convertedText, language: targetLanguage });
    return convertedText;
  } catch (error) {
    console.error('Error converting numbers to words:', error);
    return text;
  }
}