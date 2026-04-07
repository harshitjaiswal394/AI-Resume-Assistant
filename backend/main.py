from fastapi import FastAPI, UploadFile, File, Body
from fastapi.middleware.cors import CORSMiddleware
from parser import parse_resume
from llm import ask_llm
from fastapi import Body


app = FastAPI()

# ✅ CORS (important)
app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "http://localhost:3000",
        "http://127.0.0.1:3000"
    ],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

resume_text = ""


@app.post("/upload-resume")
async def upload_resume(file: UploadFile = File(...)):
    global resume_text

    content = await file.read()
    resume_text = parse_resume(content)

    print("✅ Resume loaded:", len(resume_text))

    return {"message": "Resume uploaded successfully"}


@app.post("/ask")
def ask_question(data: dict = Body(...)):
    question = data.get("question")

    print("👉 Question:", question)
    print("👉 Resume exists:", bool(resume_text))

    if not question:
        return {"answer": "Please enter a question."}

    if not resume_text:
        return {"answer": "Please upload resume first."}

    answer = ask_llm(question, resume_text)

    if answer:
        print("👉 Answer:", str(answer)[:100])
    else:
        print("⚠️ No answer returned")

    return {"answer": answer or "⚠️ No response from AI"}