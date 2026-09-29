# PocketSmart AI Chat

A full-stack AI chat application built with React + Vite on the frontend and FastAPI + OpenAI Responses API on the backend.

## Requirements
- Windows 10/11
- Python 3.11+
- Node.js 20+
- An OpenAI API key

## Configure the API key
Open `.env` and replace `PASTE_YOUR_OPENAI_API_KEY_HERE` with your own key.

The key is read only by FastAPI and is never put into React/browser code.

## One-time setup
Open PowerShell in this folder:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\setup.ps1
```

## Start everything
```powershell
.un.ps1
```

This launches:
- Frontend: http://localhost:5173
- Backend: http://127.0.0.1:8000
- Health: http://127.0.0.1:8000/health
- API docs: http://127.0.0.1:8000/docs

## Project structure
```text
PocketSmart-AI/
├── backend/
│   ├── app/
│   │   ├── __init__.py
│   │   ├── config.py
│   │   ├── main.py
│   │   └── schemas.py
│   └── requirements.txt
├── frontend/
│   ├── src/
│   │   ├── components/
│   │   │   ├── ChatInput.jsx
│   │   │   ├── MessageBubble.jsx
│   │   │   └── Sidebar.jsx
│   │   ├── App.jsx
│   │   ├── api.js
│   │   ├── main.jsx
│   │   └── styles.css
│   ├── index.html
│   ├── package.json
│   └── vite.config.js
├── .env
├── .env.example
├── .gitignore
├── setup.ps1
├── run.ps1
└── README.md
```

Never commit `.env` to Git.
