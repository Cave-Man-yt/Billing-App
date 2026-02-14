# Wholesale Billing App

A professional Flutter application designed for wholesale billing and invoice management. This application provides a streamlined interface for managing customers, generating bills, and maintaining transaction history.

## Features

- **Billing & Invoicing**
  - Create professional invoices with custom items.
  - Automatic calculation of subtotals, package charges, and grand totals.
  - PDF generation and printing support (A4 and A5 formats).
  - "Estimate" generation mode.

- **Customer Management**
  - Add, edit, and delete customers.
  - Track customer balances and payment history.
  - Search customers by name or city.
  - Real-time balance updates.

- **Transaction History**
  - View past bills and transactions.
  - Edit existing bills (with automatic balance adjustments).
  - Reprint or share old invoices.

- **Settings**
  - Configure shop details (Name, Address, Phone, Email) for invoice headers.
  - Set default print paper size (A4/A5).

## Tech Stack

- **Framework**: Flutter (Dart)
- **State Management**: Provider
- **Local Database**: SQLite (via `sqflite`)
- **PDF Generation**: `pdf` and `printing` packages

## Project Structure

The project follows a standard Flutter feature-layer architecture:

```
lib/
├── models/         # Data models (Bill, Customer, BillItem)
├── providers/      # State management logic (ChangeNotifiers)
├── screens/        # UI Screens (Home, Billing, Customers, History, Settings)
├── services/       # External services (Database, PDF generation)
├── utils/          # Helper classes and constants (AppTheme)
├── widgets/        # Reusable UI components
└── main.dart       # Entry point and app configuration
```

## Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (version 3.0.0 or higher)
- Android Studio / VS Code with Flutter extensions

### Installation

1.  **Clone the repository**:
    ```bash
    git clone https://github.com/yourusername/billing-app.git
    cd billing-app
    ```

2.  **Install dependencies**:
    ```bash
    flutter pub get
    ```

3.  **Run the application**:
    ```bash
    flutter run
    ```
    *Note: For best experience on desktop, run with `flutter run -d linux` or `windows`.*

## Key Implementation Details

- **Database**: The app uses `DatabaseService` singleton to handle all SQLite operations. It creates tables for `customers`, `bills`, and `bill_items` on first run.
- **State**: `MultiProvider` is used at the root level to inject `CustomerProvider`, `BillProvider`, etc., making state accessible throughout the app.
- **Responsive Design**: The UI is optimized for tablet/desktop usage (landscape orientation preference).

## Troubleshooting

- **Database Issues**: If you encounter database schema errors after an update, try clearing the app data or uninstalling/reinstalling to reset the SQLite database.
- **Printing**: Ensure a compatible printer service/driver is installed on the host device for direct printing.

## Contributing

1.  Fork the project
2.  Create your feature branch (`git checkout -b feature/AmazingFeature`)
3.  Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4.  Push to the branch (`git push origin feature/AmazingFeature`)
5.  Open a Pull Request
