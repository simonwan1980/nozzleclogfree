# NozzleClogFree Installation and Configuration Guide

## Prerequisites

- macOS 13.5 or later
- Xcode 14.0 or later
- CocoaPods 1.11.0 or later
- Firebase account (for analytics and push notifications)

## Installation Steps

### 1. Clone the Repository

```bash
git clone https://github.com/yourusername/NozzleClogFree.git
cd NozzleClogFree
```

### 2. Install Dependencies

```bash
cd src
pod install
```

### 3. Configure Firebase

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Create a new project or select an existing one
3. Add a new iOS app
4. Download the `GoogleService-Info.plist` file
5. Copy the downloaded file to the `NoClog` directory

### 4. Configure the Project

1. Open the `NozzleClogFree.xcworkspace` file (note: use .xcworkspace, not .xcodeproj)
2. In Xcode, select the `NozzleClogFree` target
3. Go to the "Signing & Capabilities" tab
4. Select your development team
5. Update the Bundle Identifier to your unique identifier (e.g., `com.yourcompany.NozzleClogFree`)
6. Repeat steps 2-5 for the `NozzleClogFreeHelper` target

### 5. Configure the Helper Tool

1. In the project navigator, select `SMJobBlessHelper-Info.plist`
2. Replace `YOUR_TEAM_ID` with your Apple Developer Team ID
3. Ensure the Bundle Identifier in `SMAuthorizedClients` matches your main app

### 6. Build and Run

1. In Xcode, select your development device or simulator
2. Click the "Build and Run" button (⌘R)

## Common Issues

### Code Signing Errors

If you encounter code signing errors, make sure:
- You have properly set up your development team
- All targets have unique Bundle Identifiers
- You have sufficient permissions for code signing

### Firebase Configuration Issues

If the app cannot connect to Firebase, check:
- If the `GoogleService-Info.plist` file is added to the project
- If the file is included in the target membership
- If the Bundle ID in Firebase Console matches your app's Bundle ID

## Contributing

Issues and pull requests are welcome! Please ensure your code follows the project's coding style.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
