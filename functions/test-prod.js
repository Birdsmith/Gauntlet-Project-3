const admin = require("firebase-admin");
const { getFunctions, httpsCallable } = require("firebase-admin/functions");
const serviceAccount = require("./service-account.json");

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: "gauntlet-project-3"
});

async function testTranscription() {
  try {
    const functions = getFunctions();
    const transcribeAudio = httpsCallable(functions, 'transcribeAudio');
    
    console.log('Calling transcribeAudio function...');
    const result = await transcribeAudio({
      lessonId: "1",
      config: {
        model: "latest_long",
        useEnhanced: true,
        autoDetectLanguage: true,
        multipleLanguages: true
      }
    });
    
    console.log('Function result:', result.data);
  } catch (error) {
    console.error('Error:', error);
  }
}

testTranscription(); 