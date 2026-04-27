# Project Report: Bij Theke Bhaat

**DEPARTMENT OF COMPUTER SCIENCE AND ENGINEERING**

**Course:** CSE 489  
**Name:** Sahil Ishan Tonmoy  
**ID:** 22301612  
**Email:** sahil.ishan.tonmoy@g.bracu.ac.bd 

**Project Title:** Bij Theke Bhaat: AI-Powered Smart Agriculture Ecosystem for Rice Farming  

---

### **Project Features:**

**1. Secure Authentication Suite:**
*   **Firebase User Registration**: Secure account creation for new farmers and buyers.
*   **Email Verification System**: Built-in security layer ensuring only verified users access the platform.
*   **Persistent Login System**: Smooth authentication experience with session management.

**2. Modern Dynamic Interface:**
*   **Dual-Theme Support**: A professional UI that supports both **Light and Dark modes** for comfortable viewing in different lighting conditions.
*   **Bilingual Localization**: Full support for English and Bengali languages across every screen.
*   **Responsive Dashboard**: A glassmorphic, interactive home screen for quick access to all modules.

**3. Core AI Engines:**
*   **AI Disease Scanner**: Computer vision analysis for rice pathogens with treatment advice.
*   **AI Soil Advisor**: Multi-parameter soil health analysis and fertilization strategies.
*   **AI Irrigation Scheduler**: Smart water requirement calculations based on weather and plant biology.

**4. Financial & Business Tools:**
*   **Farm Ledger & Expense Tracker**: Digital bookkeeping for all farming inputs (Seed, Labor, etc.).
*   **Interactive Profit/Loss Analytics**: Real-time financial health summaries.
*   **Live Market Prices**: Tracking system for local rice and fertilizer prices.
*   **P2P Marketplace**: Global listing platform for direct seed-to-rice trading.

**5. Production & Planning:**
*   **Automated Farming Calendar**: Generates a 100-day cultivation roadmap.
*   **Yield Calculator**: Digital tool to predict harvest volume (Mond/Bigha).
*   **Growth Plan Customizer**: Ability to adjust plans for different rice varieties.
*   **Hyper-Local Weather Center**: Forecasts, rain alerts, and humidity tracking.

---

### **Database Schema Diagram (Entity-Relationship)**

This defines the exact underlying backend architecture for the complete project, showing how the **USERS** core interacts with the farming modules.

```mermaid
erDiagram
    USERS ||--o{ SOIL_READINGS : "monitors (Subcollection)"
    USERS ||--o{ MARKETPLACE_LISTINGS : "publishes / browses"
    USERS ||--o{ MARKET_PRICES : "checks"
    USERS ||--o{ FARM_EXPENSES : "records (Ledger Subcollection)"
    USERS }o--|| FARMING_PLANS : "accesses"
    USERS ||--o{ NOTIFICATIONS : "receives"
    FARMING_PLANS ||--o{ PHASES : "contains (Subcollection)"
    ANONYMOUS_BUYERS ||--o{ MARKETPLACE_LISTINGS : "browses"

    USERS {
        string uid PK
        string name "Full name"
        string email "Primary contact"
        string gender "Male, Female, Other"
        string birthDate "YYYY-MM-DD"
        string role "Admin or Farmer"
        timestamp createdAt "Account creation date"
        timestamp sowingDate "Crop cycle anchor"
        string selectedPlanId FK "Link to FARMING_PLANS"
        string selectedPlanName "Chosen plan name"
    }

    SOIL_READINGS {
        string documentId PK
        string userId FK "Implicit from path"
        number ph "Soil acidity level"
        number nitrogen "N-P-K concentration"
        number moisture "Water saturation %"
        timestamp timestamp "Record time"
    }

    MARKETPLACE_LISTINGS {
        string documentId PK
        string sellerUid FK "Link to USERS"
        string sellerName "User display name"
        string cropType "e.g., BRRI Dhan 28"
        number quantity "Amount listed"
        string unit "KG, Mon, etc."
        number price "Rate per unit"
        string phone "Contact number"
        timestamp timestamp "Listing time"
        boolean isActive "Available or Sold"
    }

    MARKET_PRICES {
        string documentId PK
        string variety "e.g., BRRI Dhan 28"
        string price "e.g., ৳ 1200 / Mon"
        timestamp updatedAt "Last modified time"
    }

    FARM_EXPENSES {
        string documentId PK
        string userId FK "Implicit from path"
        string title "Expense description"
        string category "Seeds, Labor, etc"
        number amount "Cost in BDT"
        string type "revenue or expense"
        timestamp timestamp "Logged time"
    }

    FARMING_PLANS {
        string documentId PK
        string name "e.g., BRRI Dhan 28"
        string description "Short crop details"
        number totalDays "Cycle duration"
    }

    PHASES {
        string documentId PK
        string planId FK "Implicit from path"
        string title "Phase name"
        string subtitle "Phase instructions"
        number startDay "Start timeline"
        number endDay "End timeline"
    }

    NOTIFICATIONS {
        string documentId PK
        string userId FK "If targeted to user"
        string title "Alert header"
        string body "Message content"
        string type "Market, Weather, Plan"
        timestamp timestamp "Delivery time"
    }

    ANONYMOUS_BUYERS {
        note info "App Guests"
        note desc "Unauthenticated app users"
        note db "No data stored in DB"
    }
```

*Figure 1: High-level relational structure of the completed Bij Theke Bhaat database.*

---

---

---



---

### **App Wireframe Flow:**

```mermaid
graph TD
    A[Welcome Screen] -->|Auth| B[Login / Register]
    B -->|Verified| C[Smart Dashboard]
    
    subgraph "AI Engines"
    C --> D[AI Disease Scanner]
    C --> E[Smart Soil Hub]
    C --> F[Irrigation Scheduler]
    end
    
    subgraph "Commercial Hub"
    C --> G[P2P Marketplace]
    G --> H[Add New Listing]
    C --> I[Farm Ledger]
    I --> J[Profit/Loss Analytics]
    end
    
    subgraph "Management"
    C --> K[Farming Calendar]
    C --> L[Weather Forecast]
    C --> M[User Profile & Settings]
    end
```

---

### **Online Resources used:**

**a) Reference:**
*   **W3schools.com**: Used for mastering advanced CSS Flexbox and Grid layouts to create the app’s modern glassmorphic UI.
*   **Youtube**: 
    *   **Tutorial 1**: [Flutter & Firebase Masterclass](https://www.youtube.com/watch?v=D4nhaszNW4o) - For Authentication and Firestore integration.
    *   **Tutorial 2**: [Introduction to Gemini API for Flutter](https://www.youtube.com/watch?v=hB9iI7O7X1E) - Official Google link for implementing AI.
*   **Open-Meteo Documentation**: For hyper-local weather API integration [open-meteo.com](https://open-meteo.com/).
*   **Flutter.dev**: Official documentation for widget lifecycle and state management.

**b) Stackoverflow or github links:**
*   **StackOverflow**: [How to handle Android 13+ Notification Permissions](https://stackoverflow.com/questions/72310162/how-do-i-request-push-notification-permissions-for-android-13) - Key resource for notification permissions.
*   **GitHub**: [flutter_dotenv repository](https://github.com/java-james/flutter_dotenv) - Used for implementing the secure .env system.
*   **GitHub**: [google_generative_ai repository](https://github.com/google/generative-ai-dart) - Reference for the multi-model AI rotation logic.

---

### **Future Enhancements:**

The following enhancements can be added to the current system which will significantly improve its utility and performance:

1.  **Advanced Understanding of System (IoT Integration):**
    Integrating physical **IoT sensors** (ESP32/Arduino) directly in the rice fields to allow the system to have a real-time "understanding" of field conditions (moisture, temperature, nitrogen levels) without manual entry.

2.  **Enhanced Login System (Biometric & Social Auth):**
    Expanding the security layer to include **Biometric Authentication** (Fingerprint/FaceID) and **OAuth 2.0** (Sign-in with Google or Facebook) to reduce friction during user onboarding.

3.  **Advanced Reporting System (AI Insights & PDF Export):**
    Adding **Automated PDF Generation** for seasonal farm ledgers and implementing **Predictive Analytics** to forecast future crop yields and potential financial risks based on historical trends.
