​PakWheels Pro - Full Stack Flutter Application 🚗
​A comprehensive PakWheels clone built using Flutter and Firebase, designed as a University Final Year Project.
​🌟 Key Features
​User Authentication: Secure Login and Signup using Firebase Auth.
​Car Listings: Post ads for cars with details like price, city, and images.
​Real-time Chat: Connect buyers and sellers instantly using Firestore streams.
​Admin Panel: A secure manager area (protected by PIN) to manage orders and listings.
​Car Comparison: Compare different cars based on engine, horsepower, and fuel type.
​Sold Out Logic: Integrated greyscale effect and "Sold Out" badge for sold items.
​🛠 Tech Stack
​Frontend: Flutter (Dart).
​Backend: Firebase Cloud Firestore (NoSQL Database).
​Storage: Firebase Storage (for image hosting).
​Icons: Material Design & Cupertino Icons.
​📂 Database Structure (NoSQL)
​This project follows a Collection-Document hierarchy in Firestore:
​users: Stores profile details.
​cars: Stores active and sold car advertisements.
​chats: Manages real-time messaging between users.
​orders: Handles store management for parts and services.
​🚀 How to Run
​Clone this repository.
​Run flutter pub get to install dependencies.
​Ensure you have a valid google-services.json in the android/app directory.
​Use flutter run to launch the app on your emulator or device.
