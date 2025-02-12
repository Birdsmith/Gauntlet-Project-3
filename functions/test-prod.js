const { initializeApp } = require('firebase/app');
const { getFunctions, httpsCallable } = require('firebase/functions');
const { getAuth, signInWithCustomToken } = require('firebase/auth');
const admin = require('firebase-admin');
const serviceAccount = require('./service-account.json');

// Initialize Admin SDK for creating custom tokens
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const firebaseConfig = {
  apiKey: "AIzaSyCuvx7X0M31E_wVculMJtxCbWyRz8hlpTw",
  authDomain: "gauntlet-project-3.firebaseapp.com",
  projectId: "gauntlet-project-3",
  storageBucket: "gauntlet-project-3.firebasestorage.app",
  messagingSenderId: "303259840444",
  appId: "1:303259840444:web:859314f9f3837dccdb45b9"
};

// Initialize Firebase
const app = initializeApp(firebaseConfig);
const auth = getAuth(app);

async function testTranscription() {
  try {
    console.log('Authenticating...');
    
    // Create a custom token and sign in
    const customToken = await admin.auth().createCustomToken('service-account');
    const userCredential = await signInWithCustomToken(auth, customToken);
    
    console.log('Successfully authenticated');
    console.log('Calling transcribeAudio function...');
    
    // Get the functions instance
    const functions = getFunctions(app, 'us-central1');
    
    // Call the function
    const transcribeAudioFn = httpsCallable(functions, 'transcribeAudio');
    const result = await transcribeAudioFn({
      lessonId: "1",
      config: {
        model: "latest_long",
        useEnhanced: true,
        autoDetectLanguage: true,
        multipleLanguages: true
      }
    });
    
    console.log('Function result:', result);
  } catch (error) {
    console.error('Error:', error);
    if (error.details) {
      console.error('Error details:', error.details);
    }
  }
}

testTranscription(); 