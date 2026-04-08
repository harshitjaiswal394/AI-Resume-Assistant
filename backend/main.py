import logging
import os
from dotenv import load_dotenv

# Load environment variables from .env file (for local development)
load_dotenv()

# Configure logging
logging.basicConfig(level=logging.INFO, format="%(asctime)s - %(levelname)s - %(message)s")

from fastapi import FastAPI, UploadFile, File, Body
from fastapi.middleware.cors import CORSMiddleware
from parser import parse_resume
from llm import ask_llm, ask_llm_with_history


app = FastAPI()
chat_history = []

# CORS Configuration - Environment-based for flexibility
CORS_ORIGINS = os.getenv(
    "CORS_ORIGINS",
    "http://localhost:3000,http://127.0.0.1:3000,http://frontend-service.jobgpt"
).split(",")

app.add_middleware(
    CORSMiddleware,
    allow_origins=CORS_ORIGINS,
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "DELETE", "OPTIONS"],
    allow_headers=["*"],
)

resume_text = ""


@app.post("/upload-resume")
async def upload_resume(file: UploadFile = File(...)):
    global resume_text

    content = await file.read()
    resume_text = parse_resume(content)

    logging.info(f" Resume loaded: {len(resume_text)} characters")

    return {"message": "Resume uploaded successfully"}


@app.post("/ask")
def ask_question(data: dict = Body(...)):
    question = data.get("question")
    logging.info(f" Question received: {question}")
    logging.info(f" Resume exists: {bool(resume_text)}")

    if not question:
        return {"answer": "Please enter a question."}

    if not resume_text:
        return {"answer": "Please upload resume first."}

    try:
        answer = ask_llm(question, resume_text)
        logging.info(f" Answer generated: {answer[:100]}...")
        return {"answer": answer}
    except Exception as e:
        logging.error(f" Error generating answer: {str(e)}")
        return {"answer": " Unable to generate a response due to an error. Please try again later."}
        

@app.get("/health")
def health_check():
    return {
        "status": "healthy",
        "service": "backend"
    }