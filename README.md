# KyleGPT

**Disclaimer:** KyleGPT is *not* an actual AI chatbot. It is a satirical, full-stack messaging application designed to look and feel like a modern AI assistant. In reality, all "AI" responses are manually typed by the server administrator in real-time. 

This project serves as a fun, low-stakes exercise in full-stack development, exploring real-time web sockets, push notifications, end-to-end encryption, and complex UI/UX mimicking modern AI interfaces.

## Project Structure

The project is divided into three main components:
- `KyleGPT/`: The iOS Client application (SwiftUI).
- `src/`: The Node.js backend server.
- `web/`: (Optional) Web client interface.

### Backend Architecture (`src/`)
The backend is a Node.js Express application backed by SQLite and Firebase Authentication. It features a fully modular architecture:

- `config/`: Initialization scripts for Database, Firebase Admin, Mailer (SMTP), and Apple Push Notifications.
- `controllers/`: Request handling logic for Admin, Auth, and Chat functionalities.
- `middleware/`: Route protection enforcing Admin-only and Authenticated User checks.
- `routes/`: Express router definitions.
- `utils/`: Helper functions for push notifications and data formatting.
- `server.js`: The main Express application entry point.

### iOS Client Architecture (`KyleGPT/`)
The iOS client is built entirely in SwiftUI and structured for scalability:

- `App/`: Main application lifecycle and configuration.
- `Models/`: Data structures for Chats, Messages, and API Responses.
- `Services/`: Core networking, API requests, and APNs integration.
- `Views/`: Segregated UI layer containing primitive `Components/` (like ChatInputBar, BotMessageView) and top-level `Screens/` (LoginView, ChatRoomView, GodModeDashboard).
- `Utils/`: Extensions for generic string/image formatting and Haptic feedback.

## Setup Instructions

### Backend Setup

1. **Install Dependencies**
   ```bash
   npm install
   ```

2. **Environment Configuration**
   Copy the example environment file and populate your credentials.
   ```bash
   cp .env.example .env
   ```
   *Required variables include your `PORT`, Firebase `serviceAccountKey.json` path, APN keys, SMTP details, and an `ADMIN_EMAIL`.*

3. **Start the Server**
   For development:
   ```bash
   npm run dev
   ```
   For production (using PM2):
   ```bash
   pm2 start src/server.js --name kylegpt
   ```

### iOS Setup

1. Open `KyleGPT.xcodeproj` in Xcode.
2. Update the `AppConfig` struct in `KyleGPTApp.swift` to point to your deployed backend URL.
3. Ensure the project is signed with an Apple Developer account capable of Push Notifications.
4. Build and run on a physical device or simulator.

## Key Features

- **End-to-End Encryption (E2EE):** All messages exchanged between the client and the bot are encrypted locally on the device using Swift Crypto before transmission and stored securely in the SQLite database.
- **God Mode / Admin Dashboard:** Users matching the `ADMIN_EMAIL` can access a privileged dashboard displaying all active user chats with real-time tracking, message counts, and the ability to export chat logs.
- **Guest Mode:** Frictionless onboarding allowing users to test the application instantly with generated session tokens.
- **Push Notifications:** Deep APNs integration handles alerts when the application is backgrounded or killed.
- **Rich Media Support:** Users can securely send and receive base64 encoded images.

## Security

This repository relies on robust authentication checks and environment-specific keys. The following file types are strictly ignored by version control to prevent token leakage:
- `.env` files
- SQLite `.db` databases
- `.p8` / `.pem` Apple keys
- `serviceAccountKey.json`

Ensure your production environment correctly isolates these files.
