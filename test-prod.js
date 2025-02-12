const admin = require('firebase-admin');
const { initializeApp } = require('firebase/app');
const { getFunctions, httpsCallable } = require('firebase/functions');
const { getAuth, signInWithCustomToken } = require('firebase/auth');

const serviceAccount = require('./functions/service-account.json');

// Initialize Firebase Admin
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  storageBucket: "gauntlet-project-3.firebasestorage.app"
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
const functions = getFunctions(app, 'us-central1');

async function testTranscribeAudio() {
  try {
    // Create a custom token for authentication
    console.log('Creating custom token...');
    const customToken = await admin.auth().createCustomToken('test-user');
    
    console.log('Signing in with custom token...');
    await signInWithCustomToken(auth, customToken);
    
    // Wait for auth state to be ready
    console.log('Waiting for auth state...');
    await new Promise((resolve) => {
      const unsubscribe = auth.onAuthStateChanged((user) => {
        if (user) {
          unsubscribe();
          resolve();
        }
      });
    });
    
    console.log('Authenticated successfully');
    console.log('Calling transcribeAudio function...');
    
    const transcribeAudioFn = httpsCallable(functions, 'transcribeAudio');
    const result = await transcribeAudioFn({
      lessonId: "1",
      config: {
        model: "latest-long",
        useEnhanced: true,
        autoDetectLanguage: true,
        multipleLanguages: true
      }
    });
    
    console.log('Result:', result.data);
  } catch (error) {
    console.error('Error:', error.message);
    if (error.details) {
      console.error('Error details:', error.details);
    }
  }
}

testTranscribeAudio(); 