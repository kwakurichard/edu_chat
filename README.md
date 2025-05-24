# EduChat - Educational Flutter App

An interactive educational app built with Flutter that integrates with GitHub and provides a rich learning experience.

## Features

- Interactive quiz system
- GitHub integration
- Supabase backend integration
- Modern and responsive UI
- Real-time chat capabilities

## Prerequisites

- Flutter SDK (latest stable version)
- Dart SDK
- Git
- Android Studio / VS Code with Flutter extensions
- Supabase account

## Getting Started

1. Clone the repository:
```bash
git clone https://github.com/kwakurichard/edu_chat.git
cd edu_chat
```

2. Set up environment variables:
   - Copy `.env.example` to `.env`
   - Update the Supabase credentials in `.env`

3. Install dependencies:
```bash
flutter pub get
```

4. Run the app:
```bash
flutter run
```

## Project Structure

- `lib/` - Main source code
  - `models/` - Data models
  - `pages/` - UI screens
  - `providers/` - State management
  - `routes/` - Navigation
  - `services/` - API and backend services
- `supabase/` - Database configuration
- `test/` - Unit and widget tests

## Contributing

1. Fork the repository
2. Create your feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

Please read our [Contributing Guidelines](CONTRIBUTING.md) for details.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
