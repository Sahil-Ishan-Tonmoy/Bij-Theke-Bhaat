# Bij Theke Bhaat: Complete Project Technical Walkthrough

This document serves as a comprehensive developer guide and technical walkthrough for the **Bij Theke Bhaat** application. It breaks down the codebase structure, how state is managed, how external APIs are integrated, and how specific features are implemented.

---

## 1. High-Level Architecture & Codebase Structure
The application is built using a **Flutter + Firebase** stack, but it heavily relies on external REST APIs for environmental context and AI analysis.

The `lib/` directory is cleanly separated into modular folders:
*   **`screens/`**: Contains the UI layers for every page. Each file here usually corresponds to a single Route in the app.
*   **`services/`**: The backbone of the app. This contains logic that is strictly non-UI.
    *   `app_settings.dart` manages the global state.
    *   `app_colors.dart` acts as a design system token registry.
    *   `auth_gate.dart` acts as the security router.
*   **`widgets/`**: Contains highly reusable components like `AppMenuButton` (the global navigation) and `ThemeAware` (a wrapper that forces screen rebuilds when themes change).

**State Management Logic:** 
The codebase avoids heavy bloatware (like Redux or Riverpod) and uses native Flutter paradigms:
*   **Global State (Theme/Language):** Handled by a Singleton (`AppSettings.instance`) extending `ChangeNotifier`. Widgets wrap themselves in `AnimatedBuilder` or custom listeners to react instantly to changes.
*   **Local UI State:** Handled by standard `StatefulWidget` and `setState()`.
*   **Database State:** Handled entirely by Firebase's native `StreamBuilder` (for live, real-time syncs like the Marketplace or Ledger) and `FutureBuilder` (for one-time fetches).

---

## 2. API Integrations & Handling
While Firebase handles user accounts and database storage (NoSQL), the app makes direct HTTP requests (using the `http` Dart package) to three major external APIs. 

### A. Location & Reverse Geocoding (BigDataCloud API)
*   **Where it's used:** `weather_screen.dart`, `calendar_screen.dart`
*   **How it works:** The app uses the `geolocator` package to get raw GPS coordinates (Latitude & Longitude) from the device. Because raw numbers are useless to a farmer, it sends an HTTP GET request to `api.bigdatacloud.net`.
*   **Result:** The API returns human-readable city and region names (e.g., "Dhaka", "Rajshahi") which are then displayed on the Dashboard and Calendar.

### B. Environmental Context (Open-Meteo API)
*   **Where it's used:** `home_screen.dart`, `weather_screen.dart`, `calendar_screen.dart`
*   **How it works:** To provide farming context, the app makes HTTP GET requests to `api.open-meteo.com` passing the user's coordinates.
*   **Result:** It fetches hyper-local, real-time data including `temperature_2m`, `precipitation_sum`, and `weather_code`. This is used to display the weather widget on the home screen and warn users about upcoming rain in the Calendar.

### C. Artificial Intelligence (Google Gemini API)
*   **Where it's used:** `disease_scanner_screen.dart`, `soil_health_screen.dart`, `irrigation_scheduler_screen.dart`
*   **How it works:** The app integrates the **Google Gemini Generative AI** via direct REST POST requests (`https://generativelanguage.googleapis.com/v1beta/models/...`).
*   **Features Powered by AI:**
    1.  **Disease Scanner:** Users take a photo of a sick plant. The app converts the image to `base64` and sends it to the Gemini Vision model. Gemini analyzes the photo and returns a JSON response containing the disease name and treatment steps.
    2.  **Soil Treatment:** The user logs their soil N-P-K and pH values. The app sends these numbers as a text prompt to Gemini, which returns custom fertilizer recommendations tailored to that exact soil chemistry.
    3.  **Smart Irrigation:** The app sends the crop's current phase (e.g., "Transplanting"), days elapsed, and local weather data to Gemini to get an intelligent, AI-driven watering schedule.

---

## 3. Core Features Breakdown (`lib/screens/`)

### A. The Hub & Identity
*   **`register_screen.dart` & `login_screen.dart`**: Standard Firebase Auth. Registration creates the user document.
*   **`home_screen.dart`**: The central dashboard. It queries multiple data streams (Weather API, Next Irrigation from DB) to aggregate a quick-view summary for the farmer.

### B. The Farming Engine (Database Driven)
*   **`calendar_screen.dart`**: Users select a `FARMING_PLAN` and set a `sowingDate`. These anchor the entire timeline.
*   **`irrigation_scheduler_screen.dart`**: Reads the `sowingDate` to calculate days elapsed. It maps this against the global `PHASES` database to know exactly what the crop needs today.

### C. Financial Management (The Ledger)
*   **`expense_tracker_screen.dart`**: The UI for the Farm Ledger. Uses a realtime `StreamBuilder` on the `FARM_EXPENSES` subcollection.
*   **`profit_loss_screen.dart`**: Aggregates the entire Ledger, separating entries by `type` (`revenue` vs `expense`), summing them up to calculate the net ROI.

### D. Commerce & Community
*   **`marketplace_screen.dart`**: A public feed of `MARKETPLACE_LISTINGS` using live Streams.
*   **`add_listing_screen.dart`**: Form for injecting new items into the public market.
*   **`market_price_screen.dart`**: A read-only global commodity price tracker.

### E. Administration Tools (RBAC)
The app uses Role-Based Access Control. If a user's `role` field in Firebase is set to `Admin`, they can access:
*   **`edit_farming_plan_screen.dart`** & **`plan_phases_screen.dart`**: Define the global crop templates and their specific growth phases (Start Day to End Day).
*   **`edit_market_price_screen.dart`**: Update global commodity prices.
