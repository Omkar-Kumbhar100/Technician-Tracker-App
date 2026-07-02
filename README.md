# 📍 Technician Tracker

A real-time **Flutter** application that enables business owners to monitor technicians, assign customer visits, and track their live locations using **Firebase** and **OpenStreetMap**.

This project was developed as an **individual project** to simplify field service management by allowing technicians to share their live location while owners can monitor their movements and assign tasks efficiently.

---

## 🚀 Features

- 🔐 Secure Owner Login using Firebase Authentication
- 📍 Real-time Technician Location Tracking
- 🗺️ Live Map using OpenStreetMap
- 👨‍🔧 Technician Dashboard
- 👨‍💼 Owner Dashboard
- 📌 Assign Customer Visits to Technicians
- 📍 View Technician Location History
- 🔍 Search Technicians
- ☁️ Cloud Firestore Database
- 📱 Cross-platform Flutter Application

---

## 🛠️ Tech Stack

- Flutter
- Dart
- Firebase Authentication
- Cloud Firestore
- Geolocator
- Flutter Map (OpenStreetMap)
- HTTP API

---

## 📂 Project Structure

```
lib/
│── main.dart
│── firebase_options.dart
│── login_page.dart
│── owner_dashboard.dart
│── technician_home.dart
│── technician_assignments.dart
```

---

## ⚙️ How It Works

### Technician Module

- Technician logs into the application.
- Shares live GPS location.
- Location updates are stored in Firebase Firestore.
- Receives customer assignments from the owner.

### Owner Module

- Owner logs into the dashboard.
- Monitors technicians in real time.
- Views technician locations on an interactive map.
- Assigns customer visits.
- Tracks technician location history.

---



## Future Improvements

- Push Notifications
- Route Optimization
- Dashboard Analytics
- Customer Visit Reports
- Dark Mode
- Offline Support

---


## License

This project is developed for educational and learning purposes.