# 🏠 Rentz – Smart Shop Rent Management

**Rentz** is a modern, efficient Flutter application designed to streamline the management of commercial shop rentals. It empowers landlords and property managers to digitize their ledger, track payments in real-time, and issue professional receipts—all from their smartphone.

## 🌟 Key Features

**1. 📊 Financial Dashboard**
*   **Instant Overview:** Get a clear snapshot of your monthly performance with real-time **Total Due**, **Total Collected**, and **Fully Paid** shop counts.
*   **Actionable Insights:** Immediately identify which shops have outstanding balances.

**2. 🏪 Comprehensive Shop Management**
*   **Digital Profiles:** Store all tenant details including Name, Contact, Address, Monthly Rent, and Advance Payment.
*   **One-Tap Calling:** Call shopkeepers directly from the app to follow up on payments.
*   **Payment History:** View a detailed 6-month ledger for each shop to track rent and balance trends.

**3. 💰 Seamless Payment Recording**
*   **Flexible Methods:** Record payments via Cash, UPI, Bank Transfer, or Cheque.
*   **Auto-Calculation:** The app automatically calculates the current balance based on previous dues and the monthly rent.
*   **Searchable History:** Quickly find past transactions by searching for Shop Name, Shopkeeper Name, or Payment ID.

**4. 🧾 Smart Digital Receipts**
*   **Instant PDF Generation:** Automatically generate professional rent receipts with a "PAID" stamp.
*   **WhatsApp Sharing:** Share receipts directly with tenants via WhatsApp or other messaging apps with a single click.

**5. 📈 Reports & Exports**
*   **Excel Export:** Download your data significantly for offline accounting.
*   **PDF Summaries:** Generate monthly reports for archival purposes.

## 🚀 Technical Highlights
*   **Framework:** [Flutter](https://flutter.dev) (Dart)
*   **State Management:** Provider
*   **Backend:** Firebase Realtime Database (REST API)
*   **Caching:** Custom local-first architecture for instant loading and offline resilience.
*   **Design:** Custom UI with modern typography, gradients, and a clean "Bento-grid" style dashboard.

## 🛠️ Installation

1.  **Clone the repository:**
    ```bash
    git clone https://github.com/rana-muhammad-awais/Shop-Rent-Management-System-App-using-Flutter.git
    cd Shop-Rent-Management-System-App-using-Flutter
    ```

2.  **Install Dependencies:**
    ```bash
    flutter pub get
    ```

3.  **Run the App:**
    ```bash
    flutter run
    ```
    *(Ensure you have an emulator running or a physical device connected)*

## 📦 Building for Release (Android)

To generate the installable APK file:

```bash
flutter build apk --release
```

The output APK will be located at `build/app/outputs/flutter-apk/app-release.apk`.

## 📸 Screenshots

*(Add screenshots of your Dashboard, Shop List, and Receipt screens here)*

---

**Tagline:** *Manage Rents. Track Dues. Go Digital with Rentz.*
