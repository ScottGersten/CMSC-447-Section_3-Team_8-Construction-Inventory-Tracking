// import { initializeApp } from "firebase/app";
// import { getFirestore } from "firebase/firestore";

// // Get these values from your Firebase Console -> Project Settings
// const firebaseConfig = {
//   apiKey: "YOUR_API_KEY",
//   authDomain: "your-project.firebaseapp.com",
//   projectId: "your-project-id",
//   storageBucket: "your-project.appspot.com",
//   messagingSenderId: "your-id",
//   appId: "your-app-id"
// };

// const app = initializeApp(firebaseConfig);
// export const db = getFirestore(app);

// ----------------------------------------------------------------------------

// import { initializeApp } from "firebase/app";
// import { initializeAuth, getReactNativePersistence } from "firebase/auth";
// import { getFirestore } from "firebase/firestore";
// import AsyncStorage from "@react-native-async-storage/async-storage";

// // Replace these strings with the values from your 
// // Firebase Console -> Project Settings -> General -> Web App
// const firebaseConfig = {
//   apiKey: "YOUR_API_KEY",
//   authDomain: "YOUR_PROJECT.firebaseapp.com",
//   projectId: "YOUR_PROJECT_ID",
//   storageBucket: "YOUR_PROJECT.appspot.com",
//   messagingSenderId: "YOUR_MESSAGING_ID",
//   appId: "YOUR_APP_ID"
// };

// // 1. Initialize the Firebase App
// const app = initializeApp(firebaseConfig);

// // 2. Initialize Auth with Persistence 
// // This ensures the user stays logged in on the iPhone storage
// const auth = initializeAuth(app, {
//   persistence: getReactNativePersistence(AsyncStorage)
// });

// // 3. Initialize the Database (Firestore)
// const db = getFirestore(app);

// // 4. Export them for use in your screens (App.js, Login.js, etc.)
// export { auth, db };

// --------------------------------------------------------------------------

// Import the functions you need from the SDKs you need
import { initializeApp } from "firebase/app";
import { getAnalytics } from "firebase/analytics";
// TODO: Add SDKs for Firebase products that you want to use
// https://firebase.google.com/docs/web/setup#available-libraries

// Your web app's Firebase configuration
// For Firebase JS SDK v7.20.0 and later, measurementId is optional
const firebaseConfig = {
  apiKey: "AIzaSyB3_KlIScPU14nlu3TU0_qAdw6mmElqEGQ",
  authDomain: "cmsc447-construction-inventory.firebaseapp.com",
  projectId: "cmsc447-construction-inventory",
  storageBucket: "cmsc447-construction-inventory.firebasestorage.app",
  messagingSenderId: "505077756834",
  appId: "1:505077756834:web:7f6ee23db4c726c2c1b8fb",
  measurementId: "G-WLX8KZPY1C"
};

// Initialize Firebase
const app = initializeApp(firebaseConfig);
const analytics = getAnalytics(app);