const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

const testLesson = {
  title: 'Spanish 1 to 10',
  description: 'Learn how to count numbers in spanish from 1 to 10!',
  language: 'es',
  level: 'A1',
  videoUrl: 'gs://gauntlet-project-3.firebasestorage.app/videos/1/spanishnumbers.mp4',
  topics: ['Vocabulary', 'Pronunciation'],
  duration: 27,
  createdAt: admin.firestore.Timestamp.fromDate(new Date('2025-02-04T14:45:13')),
  createdById: 'PrNgcAnrmZTu1yPdeGdRYGMO7Nr2',
  createdByName: 'Mondly',
  viewCount: 0,
  likeCount: 0,
  commentCount: 0,
  saveCount: 0,
  metadata: {
    hasSubtitles: false,
    practiceExercises: true
  }
};

db.collection('lessons').doc('test_lesson').set(testLesson)
  .then(() => {
    console.log('Test lesson created successfully');
    process.exit(0);
  })
  .catch((error) => {
    console.error('Error creating test lesson:', error);
    process.exit(1);
  }); 