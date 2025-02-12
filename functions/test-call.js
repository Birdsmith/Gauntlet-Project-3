const admin = require("firebase-admin");
const serviceAccount = require("./service-account.json");

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  storageBucket: "gauntlet-project-3.firebasestorage.app"
});

async function callFunction() {
  try {
    // Get an ID token for the service account
    const token = await admin.auth().createCustomToken("service-account");
    
    // Call the function directly using the Admin SDK
    const result = await admin.functions().httpsCallable('transcribeAudio')({
      lessonId: "1",
      config: {
        model: "latest_long",
        useEnhanced: true,
        autoDetectLanguage: true,
        multipleLanguages: true
      }
    });
    
    console.log("Function result:", result);
  } catch (error) {
    console.error("Error:", error);
  }
}

callFunction(); 