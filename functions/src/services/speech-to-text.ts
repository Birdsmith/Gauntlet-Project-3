import * as speech from '@google-cloud/speech';
import * as admin from 'firebase-admin';
import * as FirebaseFirestore from 'firebase-admin/firestore';

export interface TranscriptionResult {
  transcript: string;
  detectedLanguages: Set<string>;
  status: 'completed' | 'failed';
  error?: string;
}

/**
 * Transcribes audio from a video file stored in Firebase Storage
 * @param videoId The ID of the video/lesson
 * @param possibleLangs Array of possible language codes to detect
 * @returns The transcription result including transcript and detected languages
 */
export async function transcribeVideoGCS(
  videoId: string,
  possibleLangs: string[] = ['en-US', 'es-ES', 'fr-FR']
): Promise<TranscriptionResult> {
  try {
    // Initialize Speech-to-Text client
    const speechClient = new speech.SpeechClient();

    // Get the lesson document to get the audio URL and language
    const lessonDoc: FirebaseFirestore.DocumentSnapshot = await admin.firestore()
      .collection('lessons')
      .doc(videoId)
      .get();

    if (!lessonDoc.exists) {
      return {
        transcript: '',
        detectedLanguages: new Set(),
        status: 'failed',
        error: 'Lesson not found'
      };
    }

    const lessonData: FirebaseFirestore.DocumentData | undefined = lessonDoc.data();
    const audioUrl: string | undefined = lessonData?.rawAudioUrl || lessonData?.audioUrl;
    const language: string | undefined = lessonData?.language;

    // Format the language code if needed (e.g., 'en' -> 'en-US')
    let primaryLanguage = language;
    if (primaryLanguage && primaryLanguage.length === 2) {
      switch (primaryLanguage.toLowerCase()) {
        case 'en': primaryLanguage = 'en-US'; break;
        case 'es': primaryLanguage = 'es-ES'; break;
        case 'fr': primaryLanguage = 'fr-FR'; break;
        case 'de': primaryLanguage = 'de-DE'; break;
        case 'ja': primaryLanguage = 'ja-JP'; break;
        default: primaryLanguage = `${primaryLanguage}-${primaryLanguage.toUpperCase()}`;
      }
    }

    if (!primaryLanguage) {
      return {
        transcript: '',
        detectedLanguages: new Set(),
        status: 'failed',
        error: 'No language specified in lesson'
      };
    }

    if (!audioUrl || typeof audioUrl !== 'string') {
      return {
        transcript: '',
        detectedLanguages: new Set(),
        status: 'failed',
        error: 'Invalid audio URL'
      };
    }

    // Verify the GCS URI format
    if (!audioUrl.startsWith('gs://')) {
      return {
        transcript: '',
        detectedLanguages: new Set(),
        status: 'failed',
        error: 'Invalid GCS URI format. Must start with gs://'
      };
    }

    console.log('Starting transcription for audio:', audioUrl);
    console.log('Language:', primaryLanguage);

    // Configure the request for FLAC audio
    const request = {
      audio: {
        uri: audioUrl,
      },
      config: {
        languageCode: primaryLanguage,
        enableWordTimeOffsets: true,
        enableAutomaticPunctuation: true,
        model: 'latest_long',  // Always use latest_long for best quality
        useEnhanced: true,
        maxAlternatives: 1,
        encoding: speech.protos.google.cloud.speech.v1.RecognitionConfig.AudioEncoding.FLAC,
        sampleRateHertz: 48000,
        audioChannelCount: 2,
      },
    };

    // Start long-running recognition operation
    console.log('Initiating longRunningRecognize operation with config:', JSON.stringify(request.config, null, 2));
    const [operation] = await speechClient.longRunningRecognize(request);
    
    console.log('Waiting for operation to complete...');
    const [response] = await operation.promise();

    if (!response || !response.results || response.results.length === 0) {
      return {
        transcript: '',
        detectedLanguages: new Set<string>(),
        status: 'failed',
        error: 'No transcription results received'
      };
    }

    // Extract transcript and detected languages
    const transcript = response.results
      .map((result) => 
        result.alternatives && result.alternatives[0] ? result.alternatives[0].transcript || '' : '')
      .join(' ');

    // Get detected languages from results
    const detectedLanguages = new Set<string>(
      response.results
        .map((result) => result.languageCode || '')
        .filter(lang => lang !== '')
    );

    // Convert the response to VTT format for subtitles
    const vttContent = convertTranscriptionToVtt(response);

    // Store the VTT file in Firebase Storage in the same folder as the video
    const bucket = admin.storage().bucket();
    const videoPath: string = lessonData?.rawVideoUrl || lessonData?.videoUrl;
    if (!videoPath) {
      throw new Error('No video path found in lesson data');
    }

    // Extract folder path from audio URL
    const audioUrlMatch: RegExpMatchArray | null = audioUrl.match(/videos\/(\d+)\//);
    if (!audioUrlMatch) {
      throw new Error('Invalid audio URL format. Expected path containing videos/[id]/');
    }
    const folderPath: string = audioUrlMatch[0];
    const extractedVideoId: string = audioUrlMatch[1];

    // Save VTT file
    const vttFileName = `${folderPath}subtitles/${primaryLanguage}.vtt`;
    console.log('Saving VTT file to:', vttFileName);
    const vttFile = bucket.file(vttFileName);
    await vttFile.save(vttContent, {
      contentType: 'text/vtt',
      metadata: {
        contentLanguage: primaryLanguage,
        transcriptionModel: 'latest_long',
        transcriptionTimestamp: new Date().toISOString(),
      },
    });

    // Store transcription metadata in Firestore
    await admin.firestore().collection('lessons').doc(extractedVideoId).update({
      transcription: {
        status: 'completed',
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        detectedLanguages: Array.from(detectedLanguages),
        model: 'latest_long',
        enhanced: true,
      }
    });

    return {
      transcript,
      detectedLanguages,
      status: 'completed'
    };
  } catch (error) {
    console.error('Error in transcribeVideoGCS:', error);
    
    // Update lesson document with error status
    try {
      await admin.firestore().collection('lessons').doc(videoId).update({
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
 * Formats a timestamp into VTT format (HH:MM:SS.mmm)
 */
function formatTime(timestamp: speech.protos.google.protobuf.ITimestamp | null): string {
  if (!timestamp) {
    return '00:00:00.000';
  }

  const seconds = Number(timestamp.seconds || 0);
  const nanos = Number(timestamp.nanos || 0);

  const totalMs = seconds * 1000 + nanos / 1_000_000;
  
  const hours = Math.floor(totalMs / 3_600_000);
  const minutes = Math.floor((totalMs % 3_600_000) / 60_000);
  const secs = Math.floor((totalMs % 60_000) / 1_000);
  const ms = Math.floor(totalMs % 1_000);

  const hh = String(hours).padStart(2, '0');
  const mm = String(minutes).padStart(2, '0');
  const ss = String(secs).padStart(2, '0');
  const mmm = String(ms).padStart(3, '0');

  return `${hh}:${mm}:${ss}.${mmm}`;
}

/**
 * Converts a transcription response to WebVTT format
 * @param rawResponse The raw response from the Speech-to-Text API
 * @returns A string in WebVTT format with word-level timing
 */
export function convertTranscriptionToVtt(
  rawResponse: speech.protos.google.cloud.speech.v1.ILongRunningRecognizeResponse
): string {
  let vttContent = 'WEBVTT\n\n';
  let captionIndex = 1;

  if (!rawResponse?.results?.length) {
    return vttContent;
  }

  for (const result of rawResponse.results) {
    const alt = result.alternatives?.[0];
    if (!alt?.words || alt.words.length === 0) continue;

    let currentSegment: typeof alt.words = [];
    let lastEndTime = alt.words[0].endTime || null;

    for (const word of alt.words) {
      const timeGap = word.startTime && lastEndTime &&
        Number(word.startTime.seconds || 0) - Number(lastEndTime.seconds || 0) > 1;
      const isPunctuation = /[.!?]$/.test(word.word || '');
      
      if (currentSegment.length >= 10 || timeGap || isPunctuation) {
        if (currentSegment.length > 0) {
          const firstWord = currentSegment[0];
          const lastWord = currentSegment[currentSegment.length - 1];
          
          const start = formatTime(firstWord.startTime || null);
          const end = formatTime(lastWord.endTime || null);
          
          const text = currentSegment.map(w => w.word).join(' ');
          
          vttContent += `${captionIndex}\n`;
          vttContent += `${start} --> ${end}\n`;
          vttContent += `${text}\n\n`;
          
          captionIndex++;
        }
        currentSegment = [];
      }
      
      currentSegment.push(word);
      lastEndTime = word.endTime || null;
    }
    
    if (currentSegment.length > 0) {
      const firstWord = currentSegment[0];
      const lastWord = currentSegment[currentSegment.length - 1];
      
      const start = formatTime(firstWord.startTime || null);
      const end = formatTime(lastWord.endTime || null);
      
      const text = currentSegment.map(w => w.word).join(' ');
      
      vttContent += `${captionIndex}\n`;
      vttContent += `${start} --> ${end}\n`;
      vttContent += `${text}\n\n`;
      
      captionIndex++;
    }
  }

  return vttContent;
}
  