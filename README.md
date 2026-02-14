# 🤖 GovGen: Premium Local LLM Interface

[![Vast Privacy](https://img.shields.io/badge/Privacy-100%25%20Local-success?style=for-the-badge&logo=shield)](#)
[![Flutter](https://img.shields.io/badge/Flutter-v3.24+-02569B?style=for-the-badge&logo=flutter)](#)
[![Ollama](https://img.shields.io/badge/Ollama-Interface-000000?style=for-the-badge&logo=ollama)](#)

**GovGen** is a state-of-the-art, privacy-prioritized local interface for LLMs, specifically designed for researchers and professionals. It bridges the gap between powerful local models (via Ollama) and a premium, feature-rich user experience.

---

## 🧠 Supported Models

GovGen is currently tuned to support high-performance local models, including:

- **Specialized**: `goekdenizguelmez/JOSIE`, `wissembijaui/qween-coder`
- **Thinking & Reasoning**: `lfm2.5-thinking`, `qwen2.5-coder:14b`
- **Vision & Multimodal**: `qwen3-vl`, `glm-4.7-flash`
- **General Purpose**: `qwen3:8b`, `qwen2.5:0.5b`

---

## ✨ Features

- **👁️ Multimodal Support**: Analyze images, charts, and documents natively using Vision-enabled models.
- **💾 Local Persistence**: Powered by **Drift (SQLite)**. Your chat history, sessions, and settings stay on your device—refreshes and restarts won't wipe your data.
- **📱 LAN & Mobile Support**: Access your local LLM from any device on your network. The interface automatically detects your host IP for seamless mobile connectivity.
- **🎨 Premium UI**: A modern, dark-mode-first design with smooth transitions, responsive sidebars, and intuitive model-tuning bottom sheets.
- **🚀 Cross-Platform**: Optimized for **Web**, **MacOS**, and **Windows**.

---

## 🛠️ Quick Start

### 1. Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (Stable)
- [Ollama](https://ollama.com/) (Running locally)

### 2. Configure Ollama (Crucial for Web/Mobile)
To allow GovGen to connect from your browser or mobile device, Ollama must be started with CORS and host binding enabled:

```powershell
# Windows PowerShell
$env:OLLAMA_ORIGINS="*"
$env:OLLAMA_HOST="0.0.0.0"
ollama serve
```

### 3. Run the App
```bash
# Get dependencies
flutter pub get

# Build for Web
flutter build web

# Serve locally
npx -y serve build/web
```
*Access via browser: `http://localhost:3000` or your LAN IP.*

---

## 🏗️ Technical Architecture

- **Frontend**: [Flutter](https://flutter.dev) for a high-performance, single-codebase UI.
- **Database**: [Drift](https://drift.simonbinder.eu/) (SQLite) with `drift_flutter` for stable persistence across Web (OPFS/IndexedDB) and Desktop.
- **Backend API**: [Ollama API](https://github.com/ollama/ollama) for local inference.
- **State Management**: [Provider](https://pub.dev/packages/provider) for reactive UI updates.

---

## 📝 License
This project is open-source and available under the MIT License.

---
*Built with ❤️ for the local AI community.*
