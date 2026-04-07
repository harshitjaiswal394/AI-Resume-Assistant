# 🚀 JobGPT Resume AI

AI-powered resume assistant that:
- Parses resume
- Answers questions using LLM
- ChatGPT-like UI

## Setup

### Backend
cd backend
python -m venv venv
source venv/Scripts/activate
pip install -r requirements.txt

Create `.env`:
NVIDIA_API_KEY=your_key

Run:
python -m uvicorn main:app --reload

### Frontend
cd frontend
npm install
npm start
