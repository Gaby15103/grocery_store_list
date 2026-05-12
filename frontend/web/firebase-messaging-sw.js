importScripts("https://www.gstatic.com/firebasejs/10.7.0/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/10.7.0/firebase-messaging-compat.js");

firebase.initializeApp({
  apiKey: "AIzaSyDDEehP_JQhcBISrpw7_UnKAund5SF8h-A",
  projectId: "grocery-master-98f71",
  messagingSenderId: "795185183313",
  appId: "1:795185183313:web:2ca88543749649c2429670",
});

const messaging = firebase.messaging();